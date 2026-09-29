# GPUStack

Install GPUStack:
```bash
helm upgrade -i gpustack \
  oci://registry-1.docker.io/gpustack/gpustack-chart \
  --namespace gpustack-system \
  --create-namespace \
  --set higress-core.gateway.replicas=1 \
  --set worker.enabled=true
```


---

Cleanup

```bash
helm un gpustack -n gpustack-system
```

```bash
kubectl delete apiservice \
  v1.gpustack.ai \
  v1.worker.gpustack.ai \
  v1beta1.visibility.kueue.x-k8s.io \
  v1beta2.visibility.kueue.x-k8s.io
```


```bash
kubectl delete ns gpustack-system
```

