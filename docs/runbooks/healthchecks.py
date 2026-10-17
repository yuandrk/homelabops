#!/usr/bin/env python3
"""Create or update the homelab's checks on healthchecks.io and keep their ping URLs in 1Password.

The checks are Alertmanager's watchdog, one per alert area, and one per restic unit on
k3s-master (docs/monitoring.md#alerts). Run it where `op` is signed in, with a
read-write API key of the healthchecks.io project (Project Settings > API Access). Neither the key
nor the ping URLs are printed. Re-running updates the checks in place, matched by slug, and
rewrites the fields of the vault item.
"""
import getpass
import json
import subprocess
import sys
import urllib.error
import urllib.request

API = "https://healthchecks.io/api/v3/checks/"
VAULT, ITEM = "homelab", "healthchecks"
HOUR, YEAR = 3600, 365 * 86400

# Alertmanager posts every change of an alert group, and the body decides the state. An area
# with no alert for a long time is fine, hence the longest period and grace the API allows.
ALERTS = {
    "timeout": YEAR,
    "grace": YEAR,
    "filter_http_body": True,
    "failure_kw": '"status":"firing"',
    "success_kw": '"status":"resolved"',
}
# The restic checks follow the OnCalendar of each unit's timer.
CHECKS = {
    "watchdog": ("Alertmanager's Watchdog, sent every two minutes", {"timeout": 5 * 60, "grace": 10 * 60}),
    "alerts-nodes": ("Prometheus alerts with area=nodes", ALERTS),
    "alerts-cluster": ("Prometheus alerts with area=cluster", ALERTS),
    "alerts-tunnel": ("Prometheus alerts with area=tunnel", ALERTS),
    "restic-local": ("restic-backup.service on k3s-master", {"schedule": "*-*-* 05:30:00", "grace": 3 * HOUR}),
    "restic-b2": ("restic-b2-backup.service on k3s-master", {"schedule": "*-*-* 06:15:00", "grace": 3 * HOUR}),
    "restic-check": ("restic-check.service on k3s-master", {"schedule": "Sun *-*-* 07:00:00", "grace": 6 * HOUR}),
    "restic-b2-check": ("restic-b2-check.service on k3s-master", {"schedule": "Sun *-*-01..07 08:00:00", "grace": 6 * HOUR}),
}


def upsert(key, slug, desc, fields):
    body = {"name": slug, "slug": slug, "desc": desc, "tz": "UTC", "channels": "*", "unique": ["slug"], **fields}
    request = urllib.request.Request(
        API,
        data=json.dumps(body).encode(),
        method="POST",
        headers={"X-Api-Key": key, "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.status, json.load(response)["ping_url"]


def main():
    key = getpass.getpass("healthchecks.io API key (read-write): ").strip()
    urls = {}
    for slug, (desc, fields) in CHECKS.items():
        try:
            status, urls[slug] = upsert(key, slug, desc, fields)
        except urllib.error.HTTPError as error:
            sys.exit(f"{slug}: HTTP {error.code} {error.read().decode(errors='replace')[:300]}")
        print(f"{slug}: {'created' if status == 201 else 'updated'}")

    # op prints the item, values included, so its output is discarded
    exists = subprocess.run(["op", "item", "get", ITEM, "--vault", VAULT], capture_output=True).returncode == 0
    if exists:
        command = ["op", "item", "edit", ITEM, "--vault", VAULT]
    else:
        command = ["op", "item", "create", "--vault", VAULT, "--category", "API Credential", "--title", ITEM]
    fields = [f"{slug}[password]={url}" for slug, url in urls.items()]
    subprocess.run(command + fields, check=True, stdout=subprocess.DEVNULL)
    print(f"ping URLs {'updated in' if exists else 'stored in the new'} 1Password item {VAULT}/{ITEM}")


if __name__ == "__main__":
    main()
