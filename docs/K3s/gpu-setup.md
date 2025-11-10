# GPU Setup on K3s

## Overview

k3s-worker3 is configured with NVIDIA GPU support for running GPU-accelerated workloads.

## Hardware

- **Node**: k3s-worker3 (10.10.0.5)
- **GPU**: NVIDIA GeForce MX130 (2GB VRAM)
- **Driver**: 535.274.02
- **CUDA**: 12.2

## Configuration

### NVIDIA Device Plugin

Deployed via FluxCD in `infrastructure/nvidia-device-plugin/base/`:

- **DaemonSet**: Runs on nodes with `nvidia.com/gpu=true` label
- **Version**: v0.16.2
- **Mode**: Privileged with host /dev and library access

### RuntimeClass

GPU workloads require the `nvidia` RuntimeClass to access GPU hardware:

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: nvidia
handler: nvidia
```

## Using GPU in Workloads

### Required Configuration

All GPU workloads must include:

1. **GPU Resource Request**:
   ```yaml
   resources:
     limits:
       nvidia.com/gpu: 1
   ```

2. **NVIDIA RuntimeClass**:
   ```yaml
   runtimeClassName: nvidia
   ```

3. **Node Selector** (optional but recommended):
   ```yaml
   nodeSelector:
     nvidia.com/gpu: "true"
   ```

### Example Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  runtimeClassName: nvidia
  restartPolicy: Never
  containers:
  - name: cuda-app
    image: nvcr.io/nvidia/cuda:12.3.2-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    nvidia.com/gpu: "true"
```

### Example Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gpu-workload
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gpu-app
  template:
    metadata:
      labels:
        app: gpu-app
    spec:
      runtimeClassName: nvidia
      containers:
      - name: app
        image: your-gpu-image:latest
        resources:
          limits:
            nvidia.com/gpu: 1
      nodeSelector:
        nvidia.com/gpu: "true"
```

## Verification

Check GPU availability:

```bash
# Check node GPU capacity
kubectl get node k3s-worker3 -o json | jq '.status.capacity."nvidia.com/gpu"'

# Check device plugin status
kubectl get pods -n kube-system -l name=nvidia-device-plugin-ds

# Test GPU access
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  runtimeClassName: nvidia
  restartPolicy: Never
  containers:
  - name: cuda-test
    image: nvcr.io/nvidia/cuda:12.3.2-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  nodeSelector:
    nvidia.com/gpu: "true"
EOF

# View test results
kubectl logs gpu-test
```

## Troubleshooting

### Device Plugin Not Detecting GPU

Check device plugin logs:
```bash
kubectl logs -n kube-system -l name=nvidia-device-plugin-ds
```

Verify GPU on host:
```bash
ssh k3s-worker3 nvidia-smi
```

### Container Cannot Access GPU

Ensure pod specifies:
- `runtimeClassName: nvidia`
- `resources.limits.nvidia.com/gpu: 1`

Check RuntimeClass exists:
```bash
kubectl get runtimeclass nvidia
```

### Pod Stuck in ContainerCreating

Check events:
```bash
kubectl describe pod <pod-name>
```

Common issues:
- Missing RuntimeClass specification
- NVIDIA runtime not configured on node
- Device plugin not running

## Supported CUDA Versions

The NVIDIA driver 535.274.02 supports CUDA up to version 12.2.

Compatible base images:
- `nvcr.io/nvidia/cuda:12.2.*`
- `nvcr.io/nvidia/cuda:12.1.*`
- `nvcr.io/nvidia/cuda:12.0.*`
- `nvcr.io/nvidia/cuda:11.*`

## Limitations

- **Single GPU**: Only 1 GPU available per workload
- **No MIG**: Multi-Instance GPU not supported on GeForce MX130
- **Memory**: 2GB VRAM limit
- **Compute Capability**: 5.0 (Maxwell architecture)

## References

- [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/)
- [K3s Runtime Classes](https://docs.k3s.io/advanced#configuring-containerd)
