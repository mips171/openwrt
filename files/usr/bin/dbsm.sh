#!/bin/sh
chmod +x /tmp/stateman_arm
cp /tmp/stateman_arm /usr/bin/stateman_arm
/tmp/stateman_arm
logread | grep STATE
