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
  existing_ipv6_addresses=$(ip -6 addr show dev "$main_interface" | grep 'inet6' | awk '{print $2}')
  for addr in $existing_ipv6_addresses; do
    ip -6 addr del "${addr%/*}" dev "$main_interface"
  done
}

# Function to add new IPv6 addresses to the main network interface
add_new_ipv6_addresses() {
  # Get the current IPv6 prefix
  IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

  # Generate new IPv6 addresses for the proxies
  for i in $(seq 1 "$1"); do
    ipv6_addr=$(gen64 "$IP6")
    if ! ip -6 addr add "$ipv6_addr/64" dev "$main_interface"; then
      echo "Failed to assign IPv6 address $ipv6_addr"
    fi
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

# Activate the main network interface
ip link set "$main_interface" up

# Add new IPv6 addresses for the proxies
add_new_ipv6_addresses "$1"
