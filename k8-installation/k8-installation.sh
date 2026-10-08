#!/bin/bash

set -e

echo "=== Updating package list ==="
sudo apt-get update

echo "=== Installing dependencies ==="
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common gnupg2

echo "=== Adding Docker's GPG key and repository ==="
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "=== Installing containerd ==="
sudo apt-get update
sudo apt-get install -y containerd

echo "=== Configuring containerd ==="
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

echo "=== Restarting and enabling containerd ==="
sudo systemctl restart containerd
sudo systemctl enable containerd

echo "=== Adding Kubernetes repository ==="
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "=== Installing Kubernetes components ==="
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "=== Setting default CRI socket ==="
crictl config --set runtime-endpoint=unix:///run/containerd/containerd.sock

echo "=== Setting up sysctl parameters ==="
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo sysctl --system


echo "=== Enabling and starting kubelet ==="
echo "=== Disabling swap ==="
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo systemctl enable kubelet
sudo systemctl start kubelet

echo "=== Kubernetes installation script completed successfully ==="

