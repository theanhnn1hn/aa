#!/bin/bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt update
sudo apt install -y docker-ce

git clone https://github.com/elejke/docker-socks5.git
cd docker-socks5
sudo docker build -t socks5 .
sudo docker run -d -p $((1024 + RANDOM % 65535)):1080 socks5
sudo docker ps
