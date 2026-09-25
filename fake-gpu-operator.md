# fake-gpu-operator

https://github.com/run-ai/fake-gpu-operator

Add labels to nodes:
```bash
kubectl label node 10.10.153.255 run.ai/simulated-gpu-node-pool=default
kubectl label node 10.10.169.182 run.ai/simulated-gpu-node-pool=default
kubectl label node 10.10.204.94 run.ai/simulated-gpu-node-pool=default
```

Deploy `fake-gpu-operator`:
```bash
helm upgrade -i fake-gpu-operator \
  oci://ghcr.io/run-ai/fake-gpu-operator/fake-gpu-operator \
  --namespace gpu-operator \
  --create-namespace
```

---

### Clean-up

Delete `fake-gpu-operator`:
```bash
helm un fake-gpu-operator -n gpu-operator
```

Remove labels from nodes:
```bash
kubectl label node 10.10.153.255 run.ai/simulated-gpu-node-pool-
kubectl label node 10.10.169.182 run.ai/simulated-gpu-node-pool-
kubectl label node 10.10.204.94 run.ai/simulated-gpu-node-pool-
```
