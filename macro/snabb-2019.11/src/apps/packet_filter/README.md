# PcapFilter App (apps.packet_filter.pcap_filter)

The `PcapFilter` app receives packets on the `input` port and transmits
conforming packets to the `output` port. In order to conform, a packet
must match the *[pcap-filter](http://www.tcpdump.org/manpages/pcap-filter.7.html)
expression* of the `PcapFilter` instance and/or belong to a *sanctioned
connection*. For a connection to be sanctioned it must be tracked in a
*state table* by a `PcapFilter` app using the same state table. All
`PcapFilter` apps share a global namespace of *state table identifiers*.
Multiple `PcapFilter` apps—e.g. for inbound and outbound traffic—can
refer to the same connection by sharing a state table identifer.

    DIAGRAM: PcapFilter
               +------------+
               |            |
    input ---->* PcapFilter *----> output
               |            |
               +------------+

## Configuration

The `PcapFilter` app accepts a table as its configuration argument. The
following keys are available:

— Key **filter**

*Required*. A string containing a [pcap-filter](http://www.tcpdump.org/manpages/pcap-filter.7.html)
expression.

— Key **state_table**

*Optional*. A string naming a state table. If set, packets passing any
*rule* will be tracked in the specified state table and any packet that
belongs to a tracked connection in the specified state table will be let
pass.

## Special Counters

— Key **sessions_established**

Total number of sessions established.
