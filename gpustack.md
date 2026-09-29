# GPUStack

Install GPUStack:
```bash
helm upgrade -i gpustack \
  oci://registry-1.docker.io/gpustack/gpustack-chart \
  --namespace gpustack-system \
  --create-namespace \
  --set higress-core.gateway.replicas=1
```

