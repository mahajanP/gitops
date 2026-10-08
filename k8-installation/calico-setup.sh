#!/usr/bin/env bash

set -euo pipefail

POD_NETWORK_CIDR="10.244.0.0/16"
# v3.30.7 avoids the isCIDR() CRD validation used by newer manifests,
# which is unsupported by this cluster's API server.
CALICO_VERSION="v3.30.7"
CALICO_MANIFEST="https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"
KUBECONFIG_DIR="${HOME}/.kube"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/config"

if ! command -v kubeadm >/dev/null 2>&1 || ! command -v kubectl >/dev/null 2>&1; then
  echo "Error: kubeadm and kubectl must be installed before running this script." >&2
  exit 1
fi

KUBEADM_PATH="$(command -v kubeadm)"
KUBECTL_PATH="$(command -v kubectl)"

if [ ! -x "${KUBEADM_PATH}" ] || [ ! -x "${KUBECTL_PATH}" ]; then
  echo "Error: kubeadm or kubectl is not executable. Check your PATH and reinstall the Kubernetes package." >&2
  exit 1
fi

# Some broken installs put a downloaded HTML page at /usr/local/bin/kubeadm.
# That is not a valid kubeadm binary and will trigger a shell syntax error.
if file "${KUBEADM_PATH}" | grep -qi "HTML document\|text/html"; then
  echo "Error: ${KUBEADM_PATH} is not a valid kubeadm binary. It looks like an HTML page was saved there instead of the actual binary." >&2
  echo "Fix: sudo rm -f /usr/local/bin/kubeadm && sudo apt-get install --reinstall kubeadm" >&2
  exit 1
fi

if [ ! -f /etc/kubernetes/admin.conf ]; then
  echo "Initializing the Kubernetes control plane..."
  sudo kubeadm init --pod-network-cidr="${POD_NETWORK_CIDR}"
else
  echo "Kubernetes control plane is already initialized."
fi

echo "Configuring kubectl for ${USER}..."
mkdir -p "${KUBECONFIG_DIR}"
sudo cp /etc/kubernetes/admin.conf "${KUBECONFIG_FILE}"
sudo chown "$(id -u):$(id -g)" "${KUBECONFIG_FILE}"

echo "Applying Calico ${CALICO_VERSION}..."
kubectl apply -f "${CALICO_MANIFEST}"

echo "Waiting for the control-plane node to become ready..."
kubectl wait --for=condition=Ready node --all --timeout=180s || true

echo "Cluster nodes:"
kubectl get nodes
echo "Calico pods:"
kubectl get pods -n kube-system -l k8s-app=calico-node
