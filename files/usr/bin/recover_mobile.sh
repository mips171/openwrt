#!/bin/sh

sh /usr/bin/run_stateman.sh

mmcli -m any -e
ifup mobile
