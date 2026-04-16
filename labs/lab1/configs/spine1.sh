#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.1.0/32 dev loopback0

# P2p links to leafs
ip address add 10.2.1.0/31 dev eth1
ip address add 10.2.1.2/31 dev eth2
ip address add 10.2.1.4/31 dev eth3
