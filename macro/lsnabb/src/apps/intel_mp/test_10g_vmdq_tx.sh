#!/usr/bin/env bash
#
# Test packet transmit for VMDq mode

./testvmdqtx.snabb $SNABB_PCI_INTEL0 $SNABB_PCI_INTEL1 "50:46:5d:74:1d:f9" source.pcap
