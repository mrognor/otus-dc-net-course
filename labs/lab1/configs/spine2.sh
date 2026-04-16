#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.2.0/32 dev loopback0

# P2p links to leafs
ip address add 10.2.2.0/31 dev eth1
ip address add 10.2.2.2/31 dev eth2
ip address add 10.2.2.4/31 dev eth3
