# nvidia-smi

Deploy a pod requesting 1 GPU and keep it running so you can exec into it and
run `nvidia-smi` interactively (repeated checks, `nvidia-smi -l`, etc.):

```
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  containers:
  - name: gpu-test
    image: nvidia/cuda:13.3.1-base-ubuntu26.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
```

```
kubectl exec -it gpu-test -- nvidia-smi
```

Clean up when done:
```
kubectl delete pod gpu-test
```
