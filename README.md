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
  -o custom-columns='NODE:.metadata.name,GPU:.metadata.labels.nvidia\.com/gpu\.product,COUNT:.metadata.labels.nvidia\.com/gpu\.count,DRIVER:.metadata.labels.nvidia\.com/cuda\.driver-version\.full,CUDA:.metadata.labels.nvidia\.com/cuda\.runtime-version\.full,MIG:.metadata.labels.nvidia\.com/mig\.capable'
```

```
kubectl apply -f - << EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  containers:
  - name: gpu-test
    image: nvidia/cuda:13.0.0-base-ubuntu24.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
EOF
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

---

Check status of your GPU Nodes:

```bash
kubectl get clusterpolicy cluster-policy
```

```bash
kubectl describe clusterpolicy cluster-policy
```
