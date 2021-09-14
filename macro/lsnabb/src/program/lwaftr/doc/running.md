#  Running

## Finding out the PCI addresses of your NICs

Snabb lwAFTR is designed to run on **Intel 82599 10-Gigabit** NICs. Find the
address of NICs on your system with `lspci`:

```bash
$ lspci | grep 82599
01:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
01:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
02:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
02:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
03:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
03:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
81:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
81:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
82:00.0 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
82:00.1 Ethernet controller: Intel Corporation 82599ES 10-Gigabit SFI/SFP+
```

Many tools accept the short form of the PCI addresses (ie, '01:00.0'), but some
require them to match the filenames in `/sys/bus/pci/devices/`, such as
`/sys/bus/pci/devices/0000:04:00.1`: in such cases, you must write `0000:01:00.0`,
with the appropriate prefix (`0000:`, in this example).

Note: Compile Snabb (see [build.md](build.md)) before attempting
the following.

## PCI addresses and the configuration file

The PCI addresses of the NICs are specified in the configuration file (for more
information see [configuration.md](configuration.md)). You can either specify
them in the configuration file or if there is only a single instance specified
you can specify them with `--v4` and `--v6` flags. These will perform a
in-memory migration of the configuration, however leaving your configuration
on-disk intact. If only one of the flags is specified then other option is
left as is.

## Running a load generator and the lwaftr (2 lwaftr NICs)

To run a load generator and an `lwaftr`, you will need four
interfaces. The following example assumes that `01:00.0` is cabled to
`01:00.1`, and that `02:00.0` is cabled to `02:00.1`. Change the
concrete PCI devices specified to match the current system; See [Section
1](Section 1. Finding out the PCI addresses of your NICs). Once you've
found your PCI devices please refer to
[Section 2](PCI addresses and the configuration file) to produce the
config.

Note that unless the load generator and the lwaftr are running on the
same NUMA nodes that their NICs are connected to, performance will be
terrible.  See [benchmarking.md](benchmarking.md) and
[performance.md](performance.md) for more.

First, start the lwAFTR:

```
$ sudo ./snabb lwaftr run \
    --conf program/lwaftr/tests/data/icmp_on_fail.conf \
    --v4 0000:01:00.1 --v6 0000:02:00.1
```

Then run a load generator:

```bash
$ cd src
$ sudo ./snabb loadtest transient  \
    program/lwaftr/tests/benchdata/ipv4-0550.pcap IPv4 IPv6 0000:01:00.0 \
    program/lwaftr/tests/benchdata/ipv6-0550.pcap IPv6 IPv4 0000:02:00.0
```

The load generator will push packets on the IPv4 and IPv6 interfaces,
ramping up from 0 Gbps to 10 Gbps (by default).  At each step it measures
the return traffic from the lwAFTR, and prints out all this information
to the console.  The load generator stops when the test is done.

## Running the lwaftr on one NIC ('on a stick')

To more efficiently use network bandwidth, it makes sense to run the lwaftr on
just one NIC, because traffic is not symmetric. To do this, use --on-a-stick,
and specify only one PCI address:

```
$ sudo ./snabb lwaftr run --conf /tmp/icmp_on_fail.conf \
    --on-a-stick 0000:02:00.1
```

You can run a load generator in on-a-stick mode:

```
$ sudo ./snabb loadtest transient \
    program/lwaftr/tests/benchdata/ipv4_and_ipv6_stick_imix.pcap ALL ALL \
    0000:82:00.1
```

For the main lwaftr instance to receive any traffic, the 82:00.1 port should be
wired to the 02:00.1 one.

## The packetblaster

Another way of generating load is via the `packetblaster lwaftr` command,
see [its documentation](../../packetblaster/lwaftr/README).
