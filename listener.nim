## Let socket join a multicast group
## TODO test on windows
import net
import os
import strutils
import nativesockets

when defined windows:
  from winlean import In_Addr, inet_addr, setSockOpt
  # const IP_ADD_MEMBERSHIP  = 5.cint
  # const IP_DROP_MEMBERSHIP = 6.cint 
  # const IP_MULTICAST_TTL = 3.cint
  const IP_ADD_MEMBERSHIP  = 12.cint
  const IP_DROP_MEMBERSHIP = 13.cint  
  const IP_MULTICAST_TTL = 10.cint  
else:
  from posix import In_Addr, inet_addr, setSockOpt
  const IP_ADD_MEMBERSHIP  = 35.cint
  const IP_DROP_MEMBERSHIP = 36.cint  
  const IP_MULTICAST_TTL = 33.cint

type 
  ip_mreq = object {.pure, final.}
    imr_multiaddr*: InAddr
    imr_interface*: InAddr


const IPPROTO_IP = 0.cint

proc joinGroup*(socket: Socket, group: string, ttl = 255): bool = 
  ## Joins a multicast group
  ## return true if sucessfull
  ## false otherwise
  ## 
  ## Values for TTL:
  ## 
  ##   TTL     Scope
  ## ----------------------------------------------------------------------
  ##    0 Restricted to the same host. Won't be output by any interface.
  ##    1 Restricted to the same subnet. Won't be forwarded by a router.
  ##  <32 Restricted to the same site, organization or department.
  ##  <64 Restricted to the same region.
  ## <128 Restricted to the same continent.
  ## <255 Unrestricted in scope. Global.

  var mreq = ip_mreq()
  mreq.imr_multiaddr.s_addr = inet_addr(group)
  mreq.imr_interface.s_addr= htonl(INADDR_ANY)
  var res = setSockOpt(socket.getFd(), IPPROTO_IP, IP_ADD_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
  if res != 0: 
    return false

  socket.getFd().setSockOptInt(IPPROTO_IP, IP_MULTICAST_TTL, ttl)
  return true

when isMainModule:
  # const HELLO_PORT = 12346
  # const HELLO_GROUP = "225.0.0.39"

  
  ## Bittorrent local peer discovery
  #const HELLO_PORT = 6771
  #const HELLO_GROUP = "239.192.152.143"

  const HELLO_PORT = 1900
  const HELLO_GROUP = "239.255.255.250"


#   var disc = """M-SEARCH * HTTP/1.1
# HOST: 239.255.255.250:1900
# MAN: "ssdp:discover"
# MX: 10
# ST: urn:dial-multiscreen-org:service:dial:1
# USER-AGENT: Google Chrome/59.0.3071.115 Windows
# """ & "\c\r\c\r" 

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
    quit()

  var 
    data: string = ""
    address: string = ""
    port: Port

  # discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)
  # discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)
  # discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)
  discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)
  while true:
    echo "R: ", socket.recvFrom(data, MSG_LEN, address, port ), " ", address,":", port, " " , data


