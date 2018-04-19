#!/bin/bash
GIT_PROXY="https://github.com/z3APA3A/3proxy.git"
WORK_PATH="/usr/local/etc/3proxy"
TMP_PATH="/opt"
INIT_3PROXY="/etc/init.d/3proxy"
CFG="${WORK_PATH}/3proxy.cfg"

check_os(){
    if [[ -e /etc/debian_version ]]; then
        apt-get update \
        && apt-get -y upgrade \
        && apt-get install -y gcc git g++ make
    else
        yum install -y git gcc g++ make
    fi
}

build_3proxy(){
    check_os
    git clone ${GIT_PROXY} ${TMP_PATH}
    cd ${TMP_PATH}
    mkdir -p ${WORK_PATH}/{bin,logs,stat}
    make -f Makefile.Linux
    cp ${TMP_PATH}/src/3proxy ${WORK_PATH}/bin
    cp ${TMP_PATH}/scripts/rc.d/proxy.sh /etc/init.d/3proxy
    chmod +x /etc/init.d/3proxy
    update-rc.d 3proxy defaults
    cat << EOF > ${CFG}
daemon
pidfile /usr/local/etc/3proxy/3proxy.pid
nscache 65536
nserver 8.8.8.8
nserver 8.8.4.4
pidfile /usr/local/etc/3proxy/3proxy.pid
config /usr/local/etc/3proxy/3proxy.cfg
monitor /usr/local/etc/3proxy/3proxy.cfg
log /usr/local/etc/3proxy/logs/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
archiver gz /usr/bin/gzip %F
rotate 30
auth strong
users LOGIN:CL:PASSWORD
allow * * * 80-88,8080-8088 HTTP
allow * * * 443,8443 HTTPS
auth strong
flush
#proxy -p1234 -i -e
EOF
    echo "Do not forget to change the login and password!!!! -- users LOGIN:CL:PASSWORD"
}
change_password_login(){
    if [[ -n $(grep users ${CFG}) ]]; then
        read -p "Enter login: " L
        read -p "Enter password for user ${L}: " P
        sed -i 's/^users LOGIN:CL:PASSWORD$/users '${L}':CL:'${P}'/g' ${CFG}
        echo "Change password"
    else
        echo "Section \"users\" not found in file ${CFG}, please add."
    fi
}
add_ip(){
    FIND_INT=$(ip link show |egrep "^.* (ens|eth)"| cut -d: -f 2 | cut -d' ' -f 2)
    FIND_IP=$(ip addr show ${FIND_INT} |egrep  "^.*inet .* ${FIND_INT}$" | cut -d' ' -f 6 | cut -d/ -f 1)
    read -p "Please, new enter ip or chose ${FIND_IP}: " IP
    for i in $IP; do
        if [[ ${FIND_IP} = ${IP} ]]; then
            if [[ -n $(grep "socks -p1080 -i${i} -e${i}" ${CFG}) ]]; then
                echo "IP add in ${CFG}, skiped"
            else
                echo "Added ip ${i} in ${CFG}"
                echo "socks -p1080 -i${i} -e${i}" >> ${CFG}
            fi
        elif [[ ${FIND_IP} != ${IP} ]]; then
            if [[ -e /etc/network/interfaces ]]; then
                if [[ -n $(grep ${i} /etc/network/interfaces) ]]; then
                    echo "IP already add in file"
                else
                    echo "UP ip ${i}"
                    ip addr add ${i} dev ${FIND_INT}
                    echo "iface ${FIND_INT} inet static" >> /etc/network/interfaces
                    echo "        address ${i}/32" >> /etc/network/interfaces
                fi
            else
                echo "This is centos"
            fi
            if [[ -n $(grep "socks -p1080 -i${i} -e${i}" ${CFG}) ]]; then
                echo "IP already UP, skiped"
            else
                echo "Added ip ${i} in ${CFG}"
                echo "socks -p1080 -i${i} -e${i}" >> ${CFG}
            fi
        fi
    done
    ${INIT_3PROXY} stop && ${INIT_3PROXY} start
}
case $1 in
    build_3proxy) build_3proxy
    ;;
    change_password_login) change_password_login
    ;;
    add_ip) add_ip
    ;;
    *)
    echo Usage: $0 "{build_3proxy|change_password_login|add_ip}"
    exit 1
esac
exit 0

