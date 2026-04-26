function enable_daemon() {
    sed -i "s/^$1=no/$1=yes/" /etc/frr/daemons
}

enable_daemon bfdd
enable_daemon ospfd
enable_daemon ospf6d
echo "ospfd_instances=1" >> /etc/frr/daemons
