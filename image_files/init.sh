#!/bin/ash

if [ -f "/daemons.sh" ]
then
    /daemons.sh
fi

supervisord -c /etc/supervisord.conf
