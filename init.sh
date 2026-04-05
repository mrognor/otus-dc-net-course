#!/bin/bash
service ssh start
service frr start &
sleep 1
echo All ready!