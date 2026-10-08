# Kubernetes monitoring

This directory installs a small, persistent `kube-prometheus-stack` suitable
for the solo-talos cluster. It includes Prometheus, Grafana, Alertmanager,
kube-state-metrics, node-exporter, dashboards, and the standard alert rules.

## Prerequisites

- Cilium is healthy and the old Flannel and kube-proxy DaemonSets are removed.
- Longhorn is healthy because Prometheus, Alertmanager, and Grafana use it for
  persistent storage.

## Install or upgrade

The chart version is pinned so that upgrades remain explicit and repeatable:
run this command from the repository root.

```bash
kubectl apply -f manifests/monitoring/namespace.yaml

helm upgrade --install monitoring \
  oci://ghcr.io/prometheus-community/charts/kube-prometheus-stack \
  --version 89.2.0 \
  --namespace monitoring \
  --create-namespace \
  --values manifests/monitoring/values.yaml \
  --wait \
  --timeout 10m
```

Check the deployment and persistent volumes:

```bash
kubectl -n monitoring get pods
kubectl -n monitoring get pvc
```

## Access Grafana through Tailscale

Expose Grafana through a dedicated Tailscale proxy. The dedicated proxy avoids
the Tailscale Services `PrimaryRoutes` issue affecting ProxyGroup ingresses.

```bash
kubectl apply -f manifests/monitoring/grafana-ingress.yaml
kubectl wait -n monitoring \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}' \
  ingress/grafana \
  --timeout=180s
```

Open <https://grafana.taild7c8e5.ts.net> and sign in as `admin`. Retrieve the
generated password without storing it in this repository:

```bash
kubectl -n monitoring get secret monitoring-grafana \
  --output jsonpath='{.data.admin-password}' | base64 --decode
echo
```

For local troubleshooting, Grafana is also available with a port-forward:

```bash
kubectl -n monitoring port-forward service/monitoring-grafana 3000:80
```

## Initial scope

The first deployment deliberately disables kube-proxy metrics because Cilium
replaces kube-proxy. Talos etcd, controller-manager, and scheduler metrics are
also disabled initially because exposing and scraping them requires dedicated
Talos endpoint and TLS configuration.

Prometheus discovers `ServiceMonitor`, `PodMonitor`, `PrometheusRule`, and
`Probe` resources in every namespace. Cilium and Longhorn monitoring can
therefore be added later without changing the Prometheus selectors.
