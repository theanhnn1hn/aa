#!/bin/bash

# Function to generate a random string
random_string() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

# Array of hexadecimal characters for generating IPv6 addresses
hex_chars=(0 1 2 3 4 5 6 7 8 9 a b c d e f)

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
  # Generate new IPv6 addresses for the proxies
  for i in $(seq 1 "$1"); do
    ipv6_addr=$(printf "%04x:%04x:%04x:%04x" "${hex_chars[RANDOM % 16]}" "${hex_chars[RANDOM % 16]}" "${hex_chars[RANDOM % 16]}" "${hex_chars[RANDOM % 16]}")
    ip -6 addr add "$ipv6_addr/64" dev "$main_interface"
  done
}

# Remove all existing IPv6 addresses
remove_existing_ipv6_addresses

# Add new IPv6 addresses for the proxies
add_new_ipv6_addresses "$1"
