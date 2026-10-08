# Install longhorn

```bash
helm install longhorn longhorn/longhorn \
--namespace longhorn-system \
-f values.yaml \
--version 1.13.0 
```
