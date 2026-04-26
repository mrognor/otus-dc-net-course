#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.0.3/32 dev loopback0

# P2p links to spines
ip address add 10.2.1.5/31 dev eth1
ip address add 10.2.2.5/31 dev eth2

# Frr conf
cat << EOF > /etc/frr/frr.conf
interface loopback0
 no ip ospf passive
 ip ospf bfd
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 ABCDEFGHIJK
 ip ospf area 0.0.0.0
interface eth1
 no ip ospf passive
 ip ospf bfd
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 ABCDEFGHIJK
 ip ospf area 0.0.0.0
interface eth2
 no ip ospf passive
 ip ospf bfd
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 ABCDEFGHIJK
 ip ospf area 0.0.0.0
router ospf 1
 passive-interface default
 router-id 10.0.0.3
bfd
 peer 10.0.0.3
  no shutdown
end
EOF
