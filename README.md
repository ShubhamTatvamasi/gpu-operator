# gpu-operator

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

---

```
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-pod
spec:
  containers:
    - name: ai-workload
      image: quay.io/jupyter/tensorflow-notebook:cuda-latest
      resources:
        limits:
          nvidia.com/gpu: 1
      command:
        - sleep
        - infinity
EOF
```

Check nvidia status:
```bash
kubectl exec -it gpu-pod -- nvidia-smi
```
