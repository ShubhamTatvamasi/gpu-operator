# fake-gpu-operator

https://github.com/run-ai/fake-gpu-operator

Label nodes:
```bash
kubectl label node 10.10.153.255 run.ai/simulated-gpu-node-pool=default
kubectl label node 10.10.169.182 run.ai/simulated-gpu-node-pool=default
kubectl label node 10.10.204.94 run.ai/simulated-gpu-node-pool=default
```

Deploy `fake-gpu-operator`:
```bash
helm upgrade -i fake-gpu-operator \
  oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator \
  --namespace fake-gpu-operator \
  --create-namespace
```

Deploy a Test Workload:
```yaml
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
  - name: gpu-container
    image: registry.k8s.io/cuda-vector-add:v0.1
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
```
