#!/bin/bash

# Loopbacks
ip link add dev loopback0 type dummy
ip address add 10.0.0.1/32 dev loopback0

ip link add dev loopback1 type dummy
ip address add 10.1.0.1/32 dev loopback1

# P2p links to spines
ip address add 10.2.1.1/31 dev eth1
ip address add 10.2.2.1/31 dev eth2
