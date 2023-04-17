#!/bin/bash

# Function to generate a random string
random_string() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

# Get the name of the main network interface
main_interface=$(ip route get 8.8.8.8 | awk '{printf $5}')

# Function to remove all existing IPv6 addresses from the main network interface
remove_existing_ipv6_addresses() {
  ip -6 addr flush dev "$main_interface"
}

# Function to add new IPv6 addresses to the main network interface
add_new_ipv6_addresses() {
  # Get the current IPv6 prefix
  IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

  # Generate new IPv6 addresses for the proxies
  for i in $(seq 1 "$1"); do
    ipv6_addr=$(gen64 "$IP6")
    ip -6 addr add "$ipv6_addr"/64 dev "$main_interface" || true
    echo "Added new IPv6 address: $ipv6_addr"
  done
}

# Array of hexadecimal characters for generating IPv6 addresses
array=(0 1 2 3 4 5 6 7 8 9 a b c d e f)

# Function to generate a random IPv6 address
gen64() {
  ipv6_addr="$1"
  for i in {1..4}; do
    ipv6_addr="$ipv6_addr:${array[RANDOM % 16]}${array[RANDOM % 16]}${array[RANDOM % 16]}${array[RANDOM % 16]}"
  done
  echo "$ipv6_addr"
}

# Remove all existing IPv6 addresses
remove_existing_ipv6_addresses

# Add new IPv6 addresses for the proxies
add_new_ipv6_addresses "$1"

# Remove existing IPv6 addresses from boot_ifconfig.sh
sed -i '/inet6/d' /home/proxy-installer/boot_ifconfig.sh

# Add new IPv6 addresses to boot_ifconfig.sh
ipv6_list=$(ip -6 addr show dev "$main_interface" | grep -Po '(?<=inet6 )[^\s]+')
while read ipv6; do
  echo "ifconfig $main_interface inet6 add $ipv6/64" >> /home/proxy-installer/boot_ifconfig.sh
  echo "Added $ipv6 to boot_ifconfig.sh"
done <<< "$ipv6_list"
