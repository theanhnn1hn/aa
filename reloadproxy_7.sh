#!/usr/bin/env bash
# centos 7.5

GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

eecho() {
    echo -e "${GREEN}$1${NC}"
}

eecho "Getting IPv4 ..."
IP4=$(curl -4 -s icanhazip.com -m 10)

eecho "Getting IPv6 ..."
IP6=$(curl -6 -s icanhazip.com -m 10)
if [[ $IP6 != *:* ]]; then
  IP6=
fi

eecho "IPv4 = ${IP4}. IPv6 = ${IP6}"

if [ ! -n "$IP4" ]; then
  eecho "IPv4 Nout Found. Exit"
  exit
fi

while [[ $IP6 != *:* ]] || [ ! -n "$IP6" ]; do
    eecho "IPv6 Nout Found, Please check environment. Exit"
    exit
done

echo "Enter the number of proxies you want to create:"
read 

STARTING_PORT=23000
PROXYCOUNT=$1

STATIC="no"
INCTAIL="no"
INCTAILSTEPS=1
IP6PREFIXLEN=64
IP6PREFIX=$(echo $IP6 | cut -f1-4 -d':')
eecho "IPv6 PrefixLen: $IP6PREFIXLEN --> Prefix: $IP6PREFIX"
ETHNAME=$(ip -o -4 route show to default | awk '{print $5}')
PROXYUSER="yag"
PROXYPASS="anhbiencong"

gen_data() {
    array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
    ip64() {
		echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
	}
    for idx in $(seq 1 $PROXYCOUNT); do
        port=$(($STARTING_PORT + $idx - 1))
        echo "$PROXYUSER/$PROXYPASS/$IP4/$port/$IP6PREFIX:$(ip64):$(ip64):$(ip64):$(ip64)"
    done
}

gen_iptables() {
    cat <<EOF
$(awk -F "/" '{print "iptables -I INPUT -p tcp --dport " $4 "  -m state --state NEW -j ACCEPT"}' ${WORKDATA}) 
EOF
}

gen_ifconfig() {
    cat <<EOF
$(awk -v ETHNAME="$ETHNAME" -v IP6PREFIXLEN="$IP6PREFIXLEN" -F "/" '{print "ifconfig " ETHNAME " inet6 add " $5 "/" IP6PREFIXLEN}' ${WORKDATA})
EOF
}

gen_static() {
    NETWORK_FILE="/etc/sysconfig/network-scripts/ifcfg-$ETHNAME"
    cat <<EOF
    sed -i '/^IPV6ADDR_SECONDARIES/d' $NETWORK_FILE && echo 'IPV6ADDR_SECONDARIES="$(awk -v IP6PREFIXLEN="$IP6PREFIXLEN" -F "/" '{print $5 "/" IP6PREFIXLEN}' ${WORKDATA} | sed -z 's/\n/ /g')"' >> $NETWORK_FILE
EOF
}

gen_proxy_file() {
    cat <<EOF
$(awk -F "/" '{print $3 ":" $4 ":" $1 ":" $2 }' ${WORKDATA})
EOF
}
remove_old_proxies() {
    # Xóa dòng cấu hình proxy cũ trong 3proxy.cfg
    sed -i '/auth strong/,/flush/d' /usr/local/3proxy/conf/3proxy.cfg

    # Xóa dòng cấu hình iptables cũ
    while read -r line; do
        if [[ ! -z "$line" ]]; then
            iptables -D INPUT -p tcp --dport "$(echo "$line" | awk -F/ '{print $4}')" -m state --state NEW -j ACCEPT
        fi
    done < "$WORKDATA"

    # Xóa dòng cấu hình ifconfig cũ
    while read -r line; do
        if [[ ! -z "$line" ]]; then
            ip addr del "$(echo "$line" | awk -F/ '{print $5}')"/"$IP6PREFIXLEN" dev "$ETHNAME"
        fi
    done < "$WORKDATA"
}

install_3proxy() {
    eecho "Installing 3proxy ..."
    git clone https://github.com/MohistAttack/3proxy
    cd 3proxy
    ln -s Makefile.Linux Makefile
    make
    make install
    cd ..
}


gen_3proxy() {
    cat <<EOF
nscache 65536
nserver 8.8.8.8
nserver 8.8.4.4

config /conf/3proxy.cfg
monitor /conf/3proxy.cfg

counter /count/3proxy.3cf

include /conf/counters
include /conf/bandlimiters

users $(awk -F "/" '{print $1 ":CL:" $2}' ${WORKDATA} | sort -u | sed -z 's/\n/ /g')

flush

$(awk -F "/" '{print "auth strong\n" \
"allow " $1 "\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e"$5"\n" \
"flush\n"}' ${WORKDATA})
EOF
}

####################
eecho "Installing apps ... (yum)"
yum -y install gcc net-tools bsdtar zip git make iptables-services

####################
eecho "Disabling firewalld and enabling iptables"
systemctl stop firewalld
systemctl disable firewalld
yum -y install iptables-services
systemctl enable iptables
systemctl start iptables

####################
eecho "Installing git"
yum -y install git

###################
install_3proxy


# ###################
WORKDIR="/usr/local/3proxy/installer"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR
eecho "Working folder = $WORKDIR"
# Xóa cấu hình proxy cũ và cài đặt proxy mới
remove_old_proxies
gen_data >$WORKDATA
gen_3proxy >>/usr/local/3proxy/conf/3proxy.cfg # Sử dụng >> để ghi thêm vào file cấu hình

gen_data >$WORKDATA
gen_3proxy >/usr/local/3proxy/conf/3proxy.cfg
gen_iptables >$WORKDIR/boot_iptables.sh
gen_ifconfig >$WORKDIR/boot_ifconfig.sh
gen_static >$WORKDIR/boot_static.sh

BOOTRCFILE="$WORKDIR/boot_rc.sh"

REGISTER_LOGIC="systemctl restart network.service && bash ${WORKDIR}/boot_ifconfig.sh"
if [[ $STATIC == "yes" ]]; then
    REGISTER_LOGIC="bash ${WORKDIR}/boot_static.sh && systemctl restart network.service"
fi

cat >$BOOTRCFILE <<EOF
bash ${WORKDIR}/boot_iptables.sh
${REGISTER_LOGIC}
systemctl restart 3proxy

# systemctl stop firewalld
# systemctl disable firewalld
# systemctl disable firewalld.service
EOF
chmod +x ${WORKDIR}/boot_*.sh


grep -qxF '* soft nofile 1024000' /etc/security/limits.conf || cat >>/etc/security/limits.conf <<EOF 

* soft nofile 1024000
* hard nofile 1024000
EOF

grep -qxF "bash $BOOTRCFILE" /etc/rc.local || cat >>/etc/rc.local <<EOF 
bash $BOOTRCFILE
EOF
chmod +x /etc/rc.local
bash /etc/rc.local

PROXYFILE=proxy.txt
gen_proxy_file >$PROXYFILE
eecho "Done with $PROXYFILE"

UPLOAD_RESULT=$(curl -sf --form "file=@$PROXYFILE" https://cloud.ytbpre.com/upload_proxy.php)
URL=$(echo "${UPLOAD_RESULT}" | awk '{print $1}')
RESPONSE=$(echo "${UPLOAD_RESULT}" | awk '{$1=""; print $0}')

eecho "Proxy is ready! Format IP:PORT:LOGIN:PASS"
eecho "Upload result:"
echo "${RESPONSE}"
eecho "Upload result URL:"
echo "${URL}"
eecho "Password: ${PROXYPASS}"
