#!/usr/bin/env bash
SNABB_SEND_BLAST=true ./testsend.snabb $SNABB_PCI_INTEL1G1 0 source.pcap &
BLAST=$!

SNABB_RECV_SPINUP=2 SNABB_RECV_DURATION=5 ./testrecv.snabb $SNABB_PCI_INTEL1G0 0 > results.0 &

sleep 1
export SNABB_RECV_DURATION=1
for i in {1..7}; do ./testrecv.snabb $SNABB_PCI_INTEL1G0 1; done > results.1
sleep 1
kill -9 $BLAST
test `cat results.* | grep "^RPTHC" | awk '{print $2}'` -gt 10000
exit $?
