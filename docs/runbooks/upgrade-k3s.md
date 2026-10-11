# Upgrade k3s

## Swap the binary, never re-run the install script

The install script rewrites the systemd unit from whatever flags it is given. k3s-worker3 keeps
`--node-ip`, `--flannel-iface`, `--node-name` and its GPU label only as unit flags, so a re-run
without them would register the node with its Wi-Fi address. On the other two nodes nothing
would be lost: k3s-master's unit flags are k3s's defaults plus a SAN its `config.yaml` repeats,
and k3s-worker1 keeps everything in `config.yaml`. Replace `/usr/local/bin/k3s` and restart the
service instead. `/etc/rancher/k3s/config.yaml`, which carries the Okta OIDC flags of the API
server, is not touched either way.

## Before

- Go one minor version at a time: the server first, then the agents.
- Check that Flux supports the target Kubernetes version (`flux check --pre`). The coupling
  runs both ways: a Flux upgrade can need a newer Kubernetes too.
- Back up the server state with k3s stopped, then start it again:

  ```bash
  sudo systemctl stop k3s
  sudo cp -a /var/lib/rancher/k3s/server /root/k3s-backup-pre-<version>
  sudo systemctl start k3s
  ```

## Per node

The order is k3s-master, then k3s-worker3, then k3s-worker1. The Pi is arm64, the others are
amd64.

```bash
V='v1.XX.Y+k3s1'                     # the target version
BIN=k3s                              # k3s-arm64 on k3s-worker1
URL="https://github.com/k3s-io/k3s/releases/download/${V/+/%2B}"

curl -fsSLo /tmp/$BIN "$URL/$BIN"
curl -fsSL "$URL/sha256sum-$([ "$BIN" = k3s ] && echo amd64 || echo arm64).txt" \
  | grep " $BIN\$" | sed "s| $BIN\$| /tmp/$BIN|" | sha256sum -c -

sudo cp /usr/local/bin/k3s "/root/k3s-$(k3s --version | awk 'NR==1{print $3}').bin"
sudo install -m 0755 /tmp/$BIN /usr/local/bin/k3s
sudo systemctl restart k3s           # k3s-agent on the workers
```

Then check:

```bash
kubectl get nodes -o wide            # VERSION column
flux check
```

## Rollback

```bash
sudo install -m 0755 /root/k3s-<old-version>.bin /usr/local/bin/k3s
sudo systemctl restart k3s           # k3s-agent on the workers
```

If the server already ran the new version, its datastore may have been migrated. Restore
`/var/lib/rancher/k3s/server` from the backup (with k3s stopped) before starting the old binary.
