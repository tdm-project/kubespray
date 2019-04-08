#!/bin/bash

# Collect name of network interfaces
all_interfaces=$(ifconfig -a | sed 's/[: \t].*//;/^\(lo\|\)$/d')
# Collect name of network interfaces
active_interfaces=($(ifconfig | sed 's/[: \t].*//;/^\(lo\|\)$/d'))
# Set the primary as the first active interface
primary_interface="${active_interfaces[0]}"
echo "Primary interface: $primary_interface"
# Detect secondary interface
for i in $all_interfaces; do
    if [[ "$i" != "$primary_interface"  ]]; then
        echo "Secondary interface: $i"
        secondary_interface="$i"
        break
    fi
done

# Check if network interfaces have been detected
if [[ -z "$primary_interface" || -z "$secondary_interface" ]]; then
    echo "Couldn't retrieve network interfaces" >&2
    echo "Primary interface: $primary_interface; Public gateway: $secondary_interface" >&2
    exit 1
fi

# detect Linux Distribution
distro_name=$(cat /etc/*-release | grep ^NAME= | tr -d 'NAME=' | tr -d '"')
# Ubuntu Distribution
if [[ ${distro_name,,} = "ubuntu" ]]; then
    # Add external interface
    echo -e "auto $secondary_interface\niface $secondary_interface inet dhcp" > /etc/network/interfaces.d/ext-net.cfg
    systemctl restart networking
    # Detect gateways
    private_net_gateway=$(tac "/var/lib/dhcp/dhclient.$primary_interface.leases" | grep -m1 'option routers' | awk '{print $3}' | sed -e 's/;//')
    public_net_gateway=$(tac "/var/lib/dhcp/dhclient.$secondary_interface.leases" | grep -m1 'option routers' | awk '{print $3}' | sed -e 's/;//')
    echo -e "Privare Net Gateway: $private_net_gateway"
    echo -e "Public Net Gateway: $public_net_gateway"
    # Chec if gateway has been detected
    if [[ -z "$private_net_gateway" || -z "$public_net_gateway" ]]; then 
        echo "Couldn't retrieve gateway routers" >&2
        echo "Private gateway: $private_net_gateway; Public gateway: $public_net_gateway" >&2
        exit 1
    fi
    # Update routes
    #route add default gw $public_net_gateway $secondary_interface
    #route del default gw $private_net_gateway $primary_interface
elif [[ ${distro_name,,} =~ "centos" ]]; then 
    # use eth0 configuration file as template for the eth1 interface
    cp /etc/sysconfig/network-scripts/ifcfg-eth{0,1}
    # detect mac address
    mac_accress=$(cat /sys/class/net/eth1/address)
    # edit eth1 configuration file
    sed -i "s/HWADDR=.*/HWADDR=${mac_accress}/;s/eth0/eth1/" /etc/sysconfig/network-scripts/ifcfg-eth1
    # set default gateway
    echo "GATEWAYDEV=eth0" >> /etc/sysconfig/network
fi

# restart network to apply changes
systemctl restart network

# Primary interface info
network_1_addr=$(ip -o -4 a | awk "/\<$primary_interface\>/{print \$4}") 
network_1_ip=$(cut -d'/' -f1 <<<"$network_1_addr")
network_1_cl=$(cut -d'/' -f2 <<<"$network_1_addr")

echo -e "Primary interface info:"
echo -e "- address: $network_1_addr"
echo -e "- class: $network_1_cl"
echo -e "- ip: $network_1_ip"

# Set advertise address of Kubernetes Master
API_ADVERTISE_ADDRESSES="$network_1_ip"
