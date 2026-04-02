#!/bin/bash

zypper refresh
zypper update -y

# Install Docker
zypper install -y docker
systemctl enable docker
systemctl start docker

# Install Kubernetes tools
zypper install -y kubelet kubeadm kubectl
systemctl enable kubelet
systemctl start kubelet

swapoff -a

echo "Setup complete" > /root/setup.log