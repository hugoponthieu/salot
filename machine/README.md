# Get the machine id 

For the control plane:

```bash
curl -X POST \
  --data-binary @customizations/cp.yaml \
  https://factory.talos.dev/schematics | jq
```

For the worker:

```bash
curl -X POST \
  --data-binary @customizations/worker.yaml \
  https://factory.talos.dev/schematics | jq
```
