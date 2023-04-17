#!/bin/bash

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk '{printf $5}')

gen64() {
  ip64() {
    echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
  }
  echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Remove all existing IPv6 addresses from boot_ifconfig.sh
sed -i '/inet6/d' /home/proxy-installer/boot_ifconfig.sh

# Remove all existing IPv6 addresses from the main network interface
ip -6 addr flush dev "$main_interface"

# Add new IPv6 addresses to boot_ifconfig.sh
for i in $(seq 1 "$1"); do
  ipv6_addr=$(gen64 "$(curl -6 -s icanhazip.com | cut -f1-4 -d':')")
  echo "ifconfig $main_interface inet6 add $ipv6_addr/64" >> /home/proxy-installer/boot_ifconfig.sh
  echo "Added new IPv6 address: $ipv6_addr"
done
