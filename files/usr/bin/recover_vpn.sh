#!/bin/sh
logger -t INFO "recovering VPN"
ubus call network.interface.nhwg0 remove
ifup nhwg0

FILE=/tmp/state/mgmt_retry_count

if [ -f "$FILE" ]; then
    COUNT=$(cat $FILE)
else
    COUNT=1
fi

if [ "$COUNT" -gt 4 ]; then
    # recover Cloud
    rm /tmp/openwisp/checksum
    rm /etc/openwisp/checksum
    /etc/init.d/openwisp_config restart
    echo 0 > $FILE
    exit
fi

COUNT=$((COUNT+1))
echo $COUNT > $FILE