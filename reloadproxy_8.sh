#!/bin/sh
WORKDIR="/home/proxy-installer"
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
main_interface=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
num_ipv6=$1

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Remove all existing IPv6 addresses from boot_ifconfig.sh
sed -i '/inet6/d' $WORKDIR/boot_ifconfig.sh

# Remove all existing IPv6 addresses from the main network interface
ip -6 addr flush dev "$main_interface"

# Generate new IPv6 addresses
gen_data() {
    for i in $(seq 1 $num_ipv6); do
        #echo "$(gen64 $(curl -6 -s icanhazip.com | cut -f1-4 -d':'))"
        echo "yag/anhbiencong/$IP4/$port/$(gen64 $(curl -6 -s icanhazip.com | cut -f1-4 -d':'))"
    done
}
gen_data > $WORKDIR/data.txt

# Add the new IPv6 addresses to the interface
gen_ifconfig() {
    cat <<EOF
$(awk -F "/" '{print "ifconfig '$main_interface' inet6 add " $5 "/64"}' ${WORKDIR}/data.txt)
EOF
}
gen_iptables() {
    cat <<EOF
    $(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDIR}/data.txt) 
EOF
}
gen_ifconfig > $WORKDIR/boot_ifconfig.sh
gen_iptables >$WORKDIR/boot_iptables.sh
