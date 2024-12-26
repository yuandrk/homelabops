# Ansible Configuration for Passwordless Sudo

This setup allows you to configure passwordless sudo for a specific user across multiple Ubuntu hosts. It uses Ansible to:

1. Ensure the target user is in the `sudo` group.

2. Add a custom sudoers file granting passwordless sudo.

3. Install the user’s SSH public key for key-based authentication.

> **Important** : Do **not**  commit `inventory.ini` or private SSH keys (`id_rsa`) to a public repository. They contain sensitive information.

---

## Directory Structure

```graphql
.
├── directory_structure.md        # (empty or used for noting folder structure)
├── inventory.ini                 # Specifies your target hosts and SSH connection details
├── playbooks
│   └── passwordless_sudo.yml     # Ansible playbook to set up passwordless sudo
└── ssh_keys
    ├── id_rsa                    # Private SSH key (Do NOT share or commit)
    └── id_rsa.pub (optional)     # Public SSH key (used in passwordless_sudo.yml if desired)
```

- **`inventory.ini`**
Lists your hosts under the `[ubuntu_nodes]` group, specifying the Ansible SSH user and private key path. **Keep this file private** , as it may contain host IPs and user details.

- **`playbooks/passwordless_sudo.yml`**
The main Ansible playbook that:
  - Creates or updates the specified user.

  - Grants passwordless sudo by creating a file in `/etc/sudoers.d/`.

  - Installs the user’s SSH key for key-based logins.

- **`ssh_keys/id_rsa`**
Your private SSH key for connecting to the remote hosts. **This file must remain private**  and should never be committed to any public repository.

---

## Prerequisites

1. **Ansible Installed** : Make sure you have Ansible installed on your control machine.

```bash
ansible --version
```

2. **SSH Key Pair** : You should have a working key pair (`id_rsa`, `id_rsa.pub`). By default, Ansible is configured here to look at `ssh_keys/id_rsa.pub` for the public key (and the matching private key for connecting to your remote hosts).

3. **Valid Inventory** : Your `inventory.ini` should be configured with the correct IP addresses, SSH user, and paths to private keys.

---

## How to Run

1. **Navigate**  to the directory containing your `inventory.ini` and `playbooks/` folder.

2. **Run**  the Ansible playbook:

```bash
ansible-playbook -i inventory.ini playbooks/passwordless_sudo.yml
```

- By default, the playbook uses:
  - `user_to_configure: "yuandrk"` (or another user if you update the variable).

  - `public_key_file: "../ssh_keys/id_rsa.pub"` (relative path to the public key).

3. **Verify**  the play results. If successful, you should see something similar to:

```markdown
PLAY [Configure passwordless sudo for a user] ****************************************
...
PLAY RECAP ***************************************************************************
ubuntu-node1  : ok=3 changed=1 ...
ubuntu-node2  : ok=3 changed=1 ...
ubuntu-node3  : ok=3 changed=1 ...
```

---

## Testing

To confirm passwordless sudo is working:

1. **SSH**  into a target host as the configured user:

```bash
ssh -i /path/to/ssh_keys/id_rsa yuandrk@<HOST_IP>
```

2. **Run a sudo command**  (e.g., `sudo whoami`) and ensure no password is requested.

---

## Security Best Practices

- **Keep `inventory.ini` Private** : Host details, IP addresses, and user credentials can be sensitive.

- **Never Commit Private Keys** : The file `ssh_keys/id_rsa` must remain private.

- **Use `.gitignore`** : Add lines to `.gitignore` to exclude `inventory.ini`, `ssh_keys/id_rsa`, and any other secret files:

```bash
inventory.ini
ssh_keys/id_rsa
```

- **Separate Public and Private Keys** : Only the public key (`id_rsa.pub`) should be shared if absolutely necessary. The private key (`id_rsa`) stays local.

---

## Troubleshooting

1. **Permission Denied (Publickey)** :

- Ensure the correct private key is specified in `inventory.ini`.

- Confirm the user’s public key is actually installed on the remote host.

- Double-check file permissions (e.g., `chmod 600` on the private key).

2. **Sudo Still Asking for Password** :

- Verify the `/etc/sudoers.d/<username>` file has `NOPASSWD:ALL`.

- Check that the Ansible tasks completed without error.

3. **File Not Found (Public Key)** :

- Make sure the `public_key_file` path in the playbook is correct and the file name matches.

- Relative paths (`../ssh_keys/id_rsa.pub`) are relative to the playbook’s directory.
