#!/usr/bin/env bash

# user needs to be root
if [ $(id -u) -ne 0 ];  then
  echo "Please run as root"
  exit
fi

echo "#########################################################"
echo "# Ensuring that docker and docker compose are available #"
echo "#########################################################"
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release smartmontools apparmor gcc
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

# # install NVIDIA container toolkit https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installation
echo "#########################################################"
echo "# Installing NVIDIA CUDA Drivers                        #"
echo "#########################################################"
sudo add-apt-repository -y ppa:graphics-drivers
sudo apt update
sudo apt install -y nvidia-driver-590

# # install NVIDIA container toolkit https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installation
echo "#########################################################"
echo "# Installing NVIDIA Container Toolkit                   #"
echo "#########################################################"
# AR
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo "#########################################################"
echo "# Configuring Docker to use Nvidia driver               #"
echo "#########################################################"
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

echo "#########################################################"
echo "# DONE                                                  #"
echo "#########################################################"