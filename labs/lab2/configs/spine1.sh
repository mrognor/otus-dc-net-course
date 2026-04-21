#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.1.0/32 dev loopback0

# P2p links to leafs
ip address add 10.2.1.0/31 dev eth1
ip address add 10.2.1.2/31 dev eth2
ip address add 10.2.1.4/31 dev eth3

# Frr conf
cat << EOF > /etc/frr/frr.conf
interface loopback0
 ip ospf area 0.0.0.0
interface eth1
 ip ospf area 0.0.0.0
interface eth2
 ip ospf area 0.0.0.0
interface eth3
 ip ospf area 0.0.0.0
router ospf 1
 router-id 10.0.1.0
end
EOF
