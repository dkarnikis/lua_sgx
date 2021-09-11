# RawSocket App (apps.socket.raw)

The `RawSocket` app is a bridge between Linux network interfaces (`eth0`,
`lo`, etc.) and a Snabb app network. Packets taken from the `rx` port are
transmitted over the selected interface. Packets received on the
interface are put on the `tx` port.

    DIAGRAM: RawSocket
              +-----------+
              |           |
      rx ---->* RawSocket *----> tx
              |           |
              +-----------+

## Configuration

The `RawSocket` app accepts a string as its configuration argument. The
string denotes the interface to bridge to.

# UnixSocket App (apps.socket.unix)

The `UnixSocket` app provides I/O for a named Unix socket.

![UnixSocket](.images/UnixSocket.png)

## Configuration

The `UnixSocket` app takes a string argument which denotes the Unix socket
file name to open, or a table with the fields:

* `filename` - the Unix socket file name to open.
* `listen` - if `true`, listen for incoming connections on the socket
rather  than connecting to the socket in client mode.
* `mode` - can be "stream" or "packet" (the default is "stream"):
the difference is that in packet mode, the packets are not split
or merged (in both modes packets arrive in order).

__NOTE__: The socket is not opened until the first call to push() or pull().
If connection is lost, the socket will be re-opened on the next call
to push() or pull().
