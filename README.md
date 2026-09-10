# gpu-operator

https://artifacthub.io/packages/helm/gpu-operator/gpu-operator

Add the `gpu-operator` repo:
```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
```

Deploy `gpu-operator`:
```bash
helm upgrade -i gpu-operator nvidia/gpu-operator
  --namespace gpu-operator \
  --create-namespace
```

