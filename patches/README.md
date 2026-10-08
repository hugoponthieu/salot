# Patches

## Generate the Talos configuration

Run the commands from this `patches` directory. Generate both the worker and
control-plane configurations with all reusable patches:

```bash
talosctl gen config wall https://192.168.121.221:6443 \
  --kubernetes-version 1.37.0 \
  --talos-version 1.14.0 \
  --with-secrets ../secrets.yaml \
  --config-patch @all/disable-flannel.yaml \
  --config-patch @all/rotate-server-certs.yaml \
  --config-patch-worker @worker/install-image.yaml \
  --config-patch-worker @worker/longhorn.yaml \
  --config-patch-control-plane @cp/install-image.yaml \
  --config-patch-control-plane @cp/disable-kube-proxy.yaml \
  --config-patch-control-plane @cp/node-ip.yaml \
  --config-patch-control-plane @cp/api-server-address.yaml \
  --config-patch-control-plane @cp/tailscale-secret.yaml \
  --output-types worker,controlplane \
  --force
```

The control-plane-specific patches keep the correct installer image, disable
`kube-proxy`, configure the Tailscale extension, and force both the kubelet and
the Kubernetes API server to advertise the LAN address.

## Validate the generated configuration

```bash
talosctl validate --config controlplane.yaml --mode metal
talosctl validate --config worker.yaml --mode metal
```

## Apply the configuration

Apply the control-plane configuration:

```bash
talosctl apply-config --talosconfig=../talosconfig --nodes 192.168.121.221 --file controlplane.yaml
```

Apply the worker configuration only when a worker patch has changed:

```bash
talosctl apply-config --talosconfig=../talosconfig --nodes 192.168.121.85,192.168.121.173 --file worker.yaml
```

