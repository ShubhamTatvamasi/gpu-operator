# nvidia-smi

Deploy a pod requesting 1 GPU and keep it running so you can exec into it and run `nvidia-smi`:
```
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
  namespace: default
spec:
  containers:
  - name: gpu-test
    image: nvidia/cuda:13.4.1-base-ubuntu26.04
    command: ["sleep", "infinity"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
```

```
kubectl -n default exec -it gpu-test -- nvidia-smi
```

Clean up when done:
```
kubectl -n default delete pod gpu-test
```
