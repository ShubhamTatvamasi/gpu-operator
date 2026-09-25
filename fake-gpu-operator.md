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
for n in $(kubectl get nodes -o name); do
  labels=$(kubectl get $n -o json | jq -r '
    .metadata.labels | keys[]
    | select(startswith("nvidia.com/") or startswith("run.ai/"))
    | . + "-"')
  [ -z "$labels" ] && continue
  echo "$n: $(echo $labels)"
  kubectl label $n $(echo $labels)
done
```

Remove capacity and allocatable status:
```bash
for n in $(kubectl get nodes -o name); do
  patch=$(kubectl get $n -o json | jq -c '
    [.status.capacity, .status.allocatable]
    | map(keys[]) | unique | map(select(startswith("nvidia.com/")))
    | map({(.): null}) | add // {}
    | {status: {capacity: ., allocatable: .}}')
  echo "$n $patch"
  kubectl patch $n --subresource=status --type=merge -p "$patch"
done

```
