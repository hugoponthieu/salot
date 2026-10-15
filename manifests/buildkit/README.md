# BuildKit

BuildKit runs rootless with a persistent Longhorn cache. Its unauthenticated
TCP service is restricted by a NetworkPolicy to clients in the
`home-dev-container` namespace.

Install it with:

```bash
kubectl apply -f buildkit/namespace.yaml
kubectl apply -f buildkit/config.yaml
kubectl apply -f buildkit/deployment.yaml
kubectl rollout status -n buildkit deployment/buildkitd --timeout=180s
```

The `buildctl` client must be installed in the development container. From
that container, build and push to the internal zot Service with:

```bash
buildctl \
  --addr tcp://buildkitd.buildkit.svc.cluster.local:1234 \
  build \
  --frontend dockerfile.v0 \
  --local context=. \
  --local dockerfile=. \
  --output \
    type=image,name=zot.zot.svc.cluster.local:5000/home-dev-container:0.0.3,push=true
```

The internal zot endpoint uses plain HTTP. It is explicitly configured in
`buildkitd.toml` and must not be exposed outside the cluster.
