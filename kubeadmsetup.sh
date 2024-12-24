#!/bin/bash

# Change permissions for /etc/hosts (consider whether this is necessary)
sudo chmod 777 /etc/hosts

# Update package lists
sudo apt update

# Prompt for the new hostname
echo "Enter the new hostname:"
read new_hostname

# Set the new hostname
sudo hostnamectl set-hostname "$new_hostname"

# Prompt the user for three IP addresses and hostnames
echo "Enter the MASTER NODE PRIVATE IP and hostname (format: IP HOSTNAME):"
read input1
echo "Enter the NODE 1 PRIVATE IP and hostname (format: IP HOSTNAME):"
read input2
echo "Enter the NODE 2 PRIVATE IP and hostname (format: IP HOSTNAME):"
read input3

# Redirect the user input to /etc/hosts
{
    echo "$input1"
    echo "$input2"
    echo "$input3"
} | sudo tee -a /etc/hosts > /dev/null

echo "Entries added to /etc/hosts."

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load necessary kernel modules
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Configure sysctl parameters for Kubernetes
sudo tee /etc/sysctl.d/kubernetes.conf <<EOT
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOT

# Apply sysctl settings
sudo sysctl --system

# Install necessary packages
sudo apt install -y curl gnupg software-properties-common apt-transport-https ca-certificates

# Set up Docker repository
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/docker.gpg
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

# Update package lists again
sudo apt update
sudo apt install -y containerd.io

# Configure containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# Final update and installation
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
