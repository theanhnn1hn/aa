#!/bin/bash
sudo yum check-update
curl -fsSL https://get.docker.com/ | sh
sudo systemctl start docker
sudo systemctl status docker
sudo systemctl enable docker

git clone https://github.com/elejke/docker-socks5.git
cd docker-socks5
sudo docker build -t socks5 .
sudo docker run -d -p $((1024 + RANDOM % 65535)):1080 socks5

hostname -I | awk '{print $1}'
sudo docker ps 
