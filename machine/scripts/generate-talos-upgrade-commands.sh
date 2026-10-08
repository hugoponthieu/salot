#!/usr/bin/env bash
set -euo pipefail

# Valeurs a adapter.
TALOS_VERSION="v1.14.0"
CONTROL_PLANE_IPS=("100.80.2.109")
WORKER_IPS=("192.168.121.173" "192.168.121.85")
TALOSCONFIG="./talosconfig"

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly FACTORY_URL="https://factory.talos.dev/schematics"

for command in curl jq; do
  command -v "${command}" >/dev/null || {
    echo "Commande requise absente: ${command}" >&2
    exit 1
  }
done

if (( ${#CONTROL_PLANE_IPS[@]} == 0 || ${#WORKER_IPS[@]} == 0 )); then
  echo "Les listes CONTROL_PLANE_IPS et WORKER_IPS ne doivent pas etre vides." >&2
  exit 1
fi

schematic_id() {
  local customization_file="$1"

  curl --fail --silent --show-error \
    --request POST \
    --data-binary "@${customization_file}" \
    "${FACTORY_URL}" \
    | jq --exit-status --raw-output '.id'
}

join_by_comma() {
  local IFS=,
  echo "$*"
}

readonly CONTROL_PLANE_ID="$(schematic_id "${ROOT_DIR}/customizations/cp.yaml")"
readonly WORKER_ID="$(schematic_id "${ROOT_DIR}/customizations/worker.yaml")"
readonly CONTROL_PLANE_NODES="$(join_by_comma "${CONTROL_PLANE_IPS[@]}")"
readonly WORKER_NODES="$(join_by_comma "${WORKER_IPS[@]}")"

printf 'Commande control plane:\n\n'
printf 'talosctl upgrade \\\n'
printf '  --image factory.talos.dev/metal-installer/%s:%s \\\n' "${CONTROL_PLANE_ID}" "${TALOS_VERSION}"
printf '  --nodes %s \\\n' "${CONTROL_PLANE_NODES}"
printf '  --progress plain \\\n'
printf '  --preserve \\\n'
printf '  --talosconfig=%s\n' "${TALOSCONFIG}"

printf '\nCommande workers:\n\n'
printf 'talosctl upgrade \\\n'
printf '  --image factory.talos.dev/metal-installer/%s:%s \\\n' "${WORKER_ID}" "${TALOS_VERSION}"
printf '  --nodes %s \\\n' "${WORKER_NODES}"
printf '  --progress plain \\\n'
printf '  --preserve \\\n'
printf '  --talosconfig=%s\n' "${TALOSCONFIG}"
