# Install gpu-operator with Helm

```bash
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update

helm upgrade -i gpu-operator nvidia/gpu-operator \
  --version v26.7.2 \
  --namespace gpu-operator \
  --create-namespace \
  -f gpu-operator-values.yaml
```
