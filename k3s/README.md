# Manual Installation of k3s on Ubuntu

## Step 1: SSH into Your Master Node

SSH into your master node using SSH:

```bash
ssh <your-username>@<your-master-node-ip>
```

## Step 2: Install k3s

Install k3s with remote access and get the kubeconfig file:

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san <your-public-ip-or-dns>" sh -
```

Replace `<your-public-ip-or-dns>` with your own domain or public IP address.

## Step 3: Configure kubeconfig

Create the `.kube` directory and configure the kubeconfig file:

```bash
mkdir ~/.kube
sudo k3s kubectl config view --raw | tee ~/.kube/config
chmod 600 ~/.kube/config
```

## Step 4: Save kubeconfig to Terraform Folder

Copy the kubeconfig file to the Terraform folder and update the server address:

1. Copy the kubeconfig file:

    ```bash
    cp ~/.kube/config <path-to-terraform-folder>/kubeconfig
    ```

2. Edit the `kubeconfig` file and change the server address from `https://127.0.0.1:6443` to your local network IP address.

3. Save the updated `kubeconfig` file in the `terraform/kube/kubeconfig` path
