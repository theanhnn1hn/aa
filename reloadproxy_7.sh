#!/bin/bash
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

# Remove all existing IPv6 addresses from boot_iptables.sh
truncate -s 0 $WORKDIR/boot_iptables.sh

# Remove all existing IPv6 addresses from the main network interface
#ip -6 addr flush dev "$main_interface"

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')
echo -e "Internal ip = ${IP4}. Exteranl sub for ip6 = ${IP6}"
FIRST_PORT=23000
LAST_PORT=$(($FIRST_PORT + $num_ipv6 - 1))

# Generate new IPv6 addresses
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        #echo "$(gen64 $(curl -6 -s icanhazip.com | cut -f1-4 -d':'))"
        echo "yag/anhbiencong/$IP4/$port/$(gen64 $IP6)"
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
gen_iptables > $WORKDIR/boot_iptables.sh
systemctl restart NetworkManager.service
if ! grep -q "bash ${WORKDIR}/boot_iptables.sh" /etc/rc.local; then
    cat >>/etc/rc.local <<EOF
ifup ${main_interface}
bash ${WORKDIR}/boot_iptables.sh
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 65535
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg &
EOF
fi

bash /etc/rc.local
systemctl restart 3proxy.service
