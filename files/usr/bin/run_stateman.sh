#!/bin/sh

# This file is run by Watchcat
if [ ! -f /tmp/stateman_arm ]
then
    cp /usr/bin/stateman_arm /tmp/stateman_arm
fi

if [ ! -x /tmp/stateman_arm ]
then
    chmod +x /tmp/stateman_arm
fi

/tmp/stateman_arm
