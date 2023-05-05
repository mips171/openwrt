#!/bin/sh

uci set openwisp.http.url='https://mgmt.networkhoist.com'
uci set openwisp.http.interval='120'
uci set openwisp.http.management_interval='10'
uci set openwisp.http.registration_interval='30'
uci set openwisp.http.verify_ssl='1'
uci set openwisp.http.shared_secret='QRoBWH4oSX7mwzpcRhgK2qD2IzZjmgoI'
uci commit openwisp

uci set network.mobile=interface
uci set network.mobile.device='/sys/devices/platform/soc/8af8800.usb3/8a00000.dwc3/xhci-hcd.0.auto/usb2/2-1'
uci set network.mobile.proto='modemmanager'
uci set network.mobile.signalrate='10'
uci set network.mobile.metric='10'

# rm WAN interface, unneeded
uci delete network.wan
uci delete network.wan6

uci commit network

uci add_list firewall.@zone[0].network='wlan0'
uci add_list firewall.@zone[0].network='wlan1'
uci add_list firewall.@zone[0].network='wifi_wlan0'
uci add_list firewall.@zone[0].network='wifi_wlan1'
uci add_list firewall.@zone[1].network='mobile'
uci set firewall.@defaults[0].forward='ACCEPT'
uci set firewall.defaults.flow_offloading='1'
uci commit firewall

# Give stateman run perms
chmod +x /usr/bin/stateman_arm

/etc/init.d/watchcat enable
/etc/init.d/watchcat start

/etc/init.d/cron enable
/etc/init.d/cron start

echo "irqbalance --oneshot" >> /etc/rc.local
irqbalance --oneshot
