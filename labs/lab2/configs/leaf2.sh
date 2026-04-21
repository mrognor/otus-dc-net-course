#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.0.2/32 dev loopback0

# P2p links to spines
ip address add 10.2.1.3/31 dev eth1
ip address add 10.2.2.3/31 dev eth2

# Frr conf
cat << EOF > /etc/frr/frr.conf
interface loopback0
 ip ospf area 0.0.0.0
interface eth1
 ip ospf area 0.0.0.0
interface eth2
 ip ospf area 0.0.0.0
router ospf 1
 router-id 10.0.0.2
end
EOF
