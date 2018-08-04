import net, os, nativesockets
import ../multicast

when isMainModule and true: # ipv4 test
  ## Bittorrent local peer discovery
  #const HELLO_PORT = 6771
  #const HELLO_GROUP = "239.192.152.143"

  ## upnp router discovery
  const HELLO_PORT = 1900
  const HELLO_GROUP = "239.255.255.250"

  var disc = """M-SEARCH * HTTP/1.1
Host:239.255.255.250:1900
ST:urn:schemas-upnp-org:device:InternetGatewayDevice:1
Man:"ssdp:discover"
MX:3""" & "\c\r\c\r" 

  const MSG_LEN = 1024
  var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.setSockOpt(OptReuseAddr, true)
  socket.bindAddr(Port(HELLO_PORT))

  if not socket.joinGroup(HELLO_GROUP):
    echo "could not join multicast group"

  socket.enableBroadcast true
  echo "enabled broadcast for the socket"

  var 
    data: string = ""
    address: string = ""
    port: Port

  discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)
  discard socket.sendTo("255.255.255.255", Port(HELLO_PORT),  disc & "\nBROADCAST: truefoo")
  # for idx in 0..1
  while true:
    echo "R: ", socket.recvFrom(data, MSG_LEN, address, port ), " ", address,":", port, " " , data

  assert socket.leaveGroup(HELLO_GROUP) == true
  assert socket.leaveGroup(HELLO_GROUP) == false # cause we have left the group already

when isMainModule and false: # ipv6 test
  var socket = newSocket(AF_INET6, SOCK_DGRAM, IPPROTO_UDP)
  socket.setSockOpt(OptReuseAddr, true)
  # socket.bindAddr(Port(1900), "2003:eb:dbc0:e595:3ea9:f4ff:fe6e:e930")
  # socket.bindAddr(Port(1900), "::")
  socket.bindAddr(Port(1900), "::")
  # socket.bindAddr(Port(1900))

  if not socket.joinGroup("ff02::2"):  
    echo "could not join multicast group"
  else:
    echo "joined ipv6 multicast group!"

  var 
    data: string = ""
    address: string = ""
    port: Port

  echo socket.sendTo("ff02::2", Port 1900, "TESTDATA")
  sleep 1000
  echo socket.leaveGroup("ff02::2")
  while true:
      echo "R: ", socket.recvFrom(data, 1024, address, port ), " ", address,":", port, " " , data
