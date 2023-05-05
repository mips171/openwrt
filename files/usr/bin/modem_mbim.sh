#!/bin/sh
MODEL="$(cat /proc/device-tree/model)"
T1="T1"
X15G="5G"

echo "Setting modem in MBIM mode..."
if [[ "$MODEL" == *"$T1"* ]]; then
	mmcli -m any --command="AT!ENTERCND=\"A710\""
    mmcli -m any --command="AT!USBCOMP=1,1,100D"
    mmcli -m any --command="AT!RESET"
else
    i=0
    while [ "$i" -lt 8 ]
    do
        printf "AT+QCFG=\"usbnet\",2\r" > /dev/ttyUSB2
        printf "AT+QPOWD=1\r" > /dev/ttyUSB2
        sleep 1
        i=$((i+1))
    done
fi

if [[ "$MODEL" == *"$X15G"* ]]; then
    echo "noop"
else
    /etc/init.d/modemmanager restart
fi

echo "done"