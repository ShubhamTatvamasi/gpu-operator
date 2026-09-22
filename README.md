# gpu-operator

https://catalog.ngc.nvidia.com

https://artifacthub.io/packages/helm/gpu-operator/gpu-operator

Add the `nvidia` repo:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
```

Deploy `gpu-operator`:
```bash
helm upgrade -i gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator \
  --create-namespace
```

Check the values:
```bash
helm get values gpu-operator -n gpu-operator
```

---

List GPU Nodes:
```bash
kubectl get nodes -l nvidia.com/gpu.present=true
```

Get details of GPUs:
```bash
kubectl get nodes -l nvidia.com/gpu.present=true \
  -o custom-columns='NODE:.metadata.name,GPU:.metadata.labels.nvidia\.com/gpu\.product,GPUS:.status.allocatable.nvidia\.com/gpu,MEM/GPU-MB:.metadata.labels.nvidia\.com/gpu\.memory,COMPUTE-MAJOR:.metadata.labels.nvidia\.com/gpu\.compute\.major,COMPUTE-MINOR:.metadata.labels.nvidia\.com/gpu\.compute\.minor,DRIVER:.metadata.labels.nvidia\.com/cuda\.driver-version\.full,CUDA:.metadata.labels.nvidia\.com/cuda\.runtime-version\.full,MIG:.metadata.labels.nvidia\.com/mig\.capable,MPS:.metadata.labels.nvidia\.com/mps\.capable,SHARING:.metadata.labels.nvidia\.com/gpu\.sharing-strategy,MODE:.metadata.labels.nvidia\.com/gpu\.mode'
```

---

See [nvidia-smi.md](nvidia-smi.md) for test pods that run `nvidia-smi`.

---

Check status of your GPU Nodes:

```bash
kubectl get clusterpolicy cluster-policy
```

```bash
kubectl describe clusterpolicy cluster-policy
```
