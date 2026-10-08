# Install tailscale operator

Add repos:

```bash
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update
```

Create the oauth secret inside the namespace:

```bash
kubectl create secret generic operator-oauth --from-env-file=tailscale-operator/.env.secret --dry-run=client -o yaml > secret.yaml
```

The .env file should contain:
```.env
client_id=
client_secret=
```

Install operator:
```bash 
helm upgrade \
  --version 1.102.4 \
  --install \
  tailscale-operator \
  tailscale/tailscale-operator \
  --namespace=tailscale \
  --create-namespace \
  -f values.yaml \
  --wait \
  --timeout 10m
```

Apply the proxy manifest:
```bash
kubectl apply -f proxies.yaml
```

## Expose the nginx test workload

The nginx test Ingress intentionally uses a dedicated Tailscale proxy instead
of the `ingress-proxies` ProxyGroup. This avoids the Tailscale Services TailVIP
routing issue where the service is advertised but has no `PrimaryRoutes`.

```bash
kubectl apply -n trash-apps -f tailscale-test.yaml
kubectl wait -n trash-apps \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/nginx-ha-ingress \
  --timeout=180s
kubectl get ingress -n trash-apps nginx-ha-ingress
```

Once the Ingress has an address, connect using:

```bash
curl -v https://nginx-ha.taild7c8e5.ts.net/
```
