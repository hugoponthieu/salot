# zot

Install the OCI registry from the official OCI Helm chart:

```bash
helm upgrade --install zot \
  oci://ghcr.io/project-zot/helm-charts/zot \
  --version 0.1.122 \
  --namespace zot \
  --create-namespace \
  --values zot/values.yaml \
  --wait \
  --timeout 10m

kubectl apply --namespace zot --filename zot/ingress.yaml
kubectl wait --namespace zot \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/zot \
  --timeout=180s
```

Display all values supported by this exact chart version:

```bash
helm show values \
  oci://ghcr.io/project-zot/helm-charts/zot \
  --version 0.1.122
```

Inside the cluster, zot is available without authentication at:

```text
zot.zot.svc.cluster.local:5000
```

The Tailscale Ingress exposes the registry over HTTPS to the tailnet at:

```text
https://zot.taild7c8e5.ts.net
```

Test access from a tailnet client:

```bash
curl https://zot.taild7c8e5.ts.net/v2/
```

For a temporary local test:

```bash
kubectl port-forward -n zot service/zot 5000:5000
curl http://127.0.0.1:5000/v2/
```

The Ingress is private to the tailnet, but zot itself does not yet require
credentials. Use Tailscale grants to restrict access, or enable zot
authentication before allowing untrusted tailnet members to reach it.
