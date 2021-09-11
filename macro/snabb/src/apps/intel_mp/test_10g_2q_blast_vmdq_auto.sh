#!/usr/bin/env bash
#
# Test VMDq with automatic pool selection

SNABB_SEND_BLAST=true ./testsend.snabb $SNABB_PCI_INTEL1 0 source2.pcap &
BLAST=$!

SNABB_RECV_SPINUP=2 SNABB_RECV_DURATION=5 ./testvmdqrecv.snabb $SNABB_PCI_INTEL0 "90:72:82:78:c9:7a" nil nil 0 > results.0 &
PID1=$!
SNABB_RECV_SPINUP=2 SNABB_RECV_DURATION=5 ./testvmdqrecv.snabb $SNABB_PCI_INTEL0 "12:34:56:78:9a:bc" nil nil 1 > results.1

wait $PID1
kill -9 $BLAST

# both queues should see packets
[[ `cat results.* | grep "^RXDGPC" | awk '{print $2}'` -gt 10000 ]] &&\
[[ `cat results.0 | grep -m 1 fpb | awk '{print $9}'` -gt 0 ]] &&\
[[ `cat results.1 | grep -m 1 fpb | awk '{print $9}'` -gt 0 ]]

exit $?
