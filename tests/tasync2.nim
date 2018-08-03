# test useing asyncdispatch2 https://github.com/status-im/nim-asyncdispatch2

import asyncdispatch2, nativesockets
import ../multicast

const HELLO_PORT = 1900
const HELLO_GROUP = "239.255.255.250"
var disc = """M-SEARCH * HTTP/1.1
Host:239.255.255.250:1900
ST:urn:schemas-upnp-org:device:InternetGatewayDevice:1
Man:"ssdp:discover"
MX:3""" & "\c\r\c\r" 

var udp4DataAvailable: DatagramCallback = proc(transp: DatagramTransport, remote: TransportAddress): Future[void] {.async, gcsafe.} =
  echo "Data from:", remote
  var msg = transp.getMessage()
  echo repr msg

proc main(): Future[void] {.async.} =
  var ta = initTAddress("0.0.0.0:" & $HELLO_PORT)
  var data: ref byte
  data = new byte  
  var dsock4 = newDatagramTransport[byte](udp4DataAvailable, udata = data, local = ta)

  if not SocketHandle(dsock4.fd).joinGroup(HELLO_GROUP.parseIpAddress()):
    echo "could not join multicast group"

  var other = initTAddress(HELLO_GROUP & ":" & $HELLO_PORT)
  var msg = "testmsg2"
  await dsock4.sendTo(other, disc, disc.len())

asyncCheck main()
while true:
  poll()