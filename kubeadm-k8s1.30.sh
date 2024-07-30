R!/bin/bash

set -e

# https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

# Update system and install required packages
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl

# Add Kubernetes repository and key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Update package list and install Kubernetes packages
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl containerd
sudo apt-mark hold kubelet kubeadm kubectl

# activate specific modules
# overlay — The overlay module provides overlay filesystem support:wq
hich Kubernetes uses for its pod network abstraction
# br_netfilter — This module enables bridge netfilter support in the Linux kernel, which is required for Kubernetes networking and policy.
sudo modprobe br_netfilter
sudo modprobe overlay

# enable packet forwarding, enable packets crossing a bridge are sent to iptables for processing
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.bridge.bridge-nf-call-iptables=1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# return to user
# In v1.22 and later, if the user does not set the cgroupDriver field under KubeletConfiguration, kubeadm defaults it to systemd.
# by default containerd set SystemdCgroup = false, so you need to activate SystemdCgroup = true, put it in /etc/containerd/config.toml
# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/
# https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cgroup-drivers
sudo mkdir -p /etc/containerd/
cat <<EOF | sudo tee /etc/containerd/config.toml
version = 2
[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
          [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
            SystemdCgroup = true
EOF

sudo systemctl restart containerd

# Get the master node's IP address
MASTER_IP=$(hostname -I | awk '{print $1}')

# Initialize Kubernetes cluster
sudo kubeadm init \
  --apiserver-advertise-address="$MASTER_IP" \
  --pod-network-cidr 10.244.0.0/16 \

# Set up default kubeconfig for kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Install CNI plugin (Flannel)
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Print command to join worker nodes to the cluster
JOIN_COMMAND=$(kubeadm token create --print-join-command --ttl=0)
echo "Run this command on worker nodes to join the cluster:"
sudo $JOIN_COMMAND

# Optionally, taint the master node so it can also run workloads
read -p "Do you want to allow the master node to run workloads? (y/n) " ALLOW_WORKLOADS
if [ "$ALLOW_WORKLOADS" == "y" ]; then
  kubectl taint nodes --all node-role.kubernetes.io/master-
fi
