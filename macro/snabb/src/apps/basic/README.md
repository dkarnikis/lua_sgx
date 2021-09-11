# Basic Apps (apps.basic.basic_apps)

The module *apps.basic.basic_apps* provides apps with general
functionality for use in you app networks.

## Source

The `Source` app is a synthetic packet generator. On each breath it fills
each attached output link with new packets. It accepts a number as its
configuration argument which is the byte size of the generated packets. By
default, each packet is 60 bytes long. The packet data is initialized with
zero bytes.

    DIAGRAM: Source
    +--------+
    |        |
    |        *---- (any)
    |        |
    | Source *---- (any)
    |        |
    |        *---- (any)
    |        |
    +--------+

## Join

The `Join` app joins together packets from N input links onto one
output link. On each breath it outputs as many packets as possible
from the inputs onto the output.

    DIAGRAM: Join
              +--------+
              |        |
    (any) ----*        |
              |        |
    (any) ----*  Join  *----- out
              |        |
    (any) ----*        |
              |        |
              +--------+

## Split

The `Split` app splits packets from multiple inputs across multiple
outputs. On each breath it transfers as many packets as possible from
the input links to the output links.

    DIAGRAM: Split
              +--------+
              |        |
    (any) ----*        *----- (any)
              |        |
    (any) ----* Split  *----- (any)
              |        |
    (any) ----*        *----- (any)
              |        |
              +--------+

## Sink

The `Sink` app receives all packets from any number of input links and
discards them. This can be handy in combination with a `Source`.

    DIAGRAM: Sink
              +--------+
              |        |
    (any) ----*        |
              |        |
    (any) ----*  Sink  |
              |        |
    (any) ----*        |
              |        |
              +--------+

## Tee

The `Tee` app receives all packets from any number of input links and
transfers each received packet to all output links. It can be used to
merge and/or duplicate packet streams

    DIAGRAM: Tee
              +--------+
              |        |
    (any) ----*        *----- (any)
              |        |
    (any) ----*  Tee   *----- (any)
              |        |
    (any) ----*        *----- (any)
              |        |
              +--------+

## Repeater

The `Repeater` app collects all packets received from the `input` link
and repeatedly transfers the accumulated packets to the `output`
link. The packets are transmitted in the order they were received.

    DIAGRAM: Repeater
              +----------+
              |          |
              |          |
    input ----* Repeater *----- output
              |          |
              |          |
              +----------+

## Truncate

The `Truncate` app sends all packets received from the `input` to the `output`
link and truncates or zero pads each packet to a given length. It accepts a
number as its configuration argument which is the length of the truncated or
padded packets.

    DIAGRAM: Truncate
              +----------+
              |          |
    input ----* Truncate *---- output
              |          |
              +----------+

## Sample

The `Sample` app forwards packets every *n*th packet from the `input` link to
the `output` link, and drops all others packets. It accepts a number as its
configuration argument which is *n*.

    DIAGRAM: Sample
              +--------+
              |        |
    input ----* Sample *---- output
              |        |
              +--------+
