#
#
#                  nimMulticast
#        (c) Copyright 2017 David Krause
#
#    See the file "LICENSE", included in this
#    distribution, for details about the copyright.
#
## procs to work with multicast groups and ip broadcast
## tested on windows and linux
import net
import os
import nativesockets

when defined windows:
  from winlean import In_Addr, inet_addr, setSockOpt, In6Addr, inet_pton
  # Old windows
  # const IP_ADD_MEMBERSHIP  = 5.cint
  # const IP_DROP_MEMBERSHIP = 6.cint 
  # const IP_MULTICAST_TTL = 3.cint

  # New windows
  const 
    IP_ADD_MEMBERSHIP  = 12.cint
    IP_DROP_MEMBERSHIP = 13.cint  
    IP_MULTICAST_TTL = 10.cint  
    IPV6_JOIN_GROUP = 12.cint # TODO
    IPV6_LEAVE_GROUP = 13.cint # TODO
else:
  from posix import In_Addr, inet_addr, setSockOpt, In6Addr, 
    IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, inet_pton # , Tipv6_mreq
  const
    IP_ADD_MEMBERSHIP  = 35.cint
    IP_DROP_MEMBERSHIP = 36.cint  
    IP_MULTICAST_TTL = 33.cint
    # IPV6_JOIN_GROUP = 0 # TODO
    # IPV6_LEAVE_GROUP = 0 # TODO

type 
  ip_mreq = object {.pure, final.}
    imr_multiaddr*: InAddr
    imr_interface*: InAddr
  ipv6_mreq = object {.pure, final.} # there is in posix but missing in winlean!
    ipv6mr_multiaddr*: In6Addr ## IPv6 multicast address.
    ipv6mr_interface*: cint ## Interface index.    

const IPPROTO_IP = 0.cint
const IPPROTO_IPV6 = 41.cint

proc isMulticastAddress*(ipAddr: IpAddress): bool =
  ## returns true wether the given IpAddress is a ipv4 or ipv6 multicast
  ## address, false otherwise
  ## Examples:
  ##
  # runnableExamples:
  #   doAssert "224.0.0.0".isMulticastAddress == true
  #   doAssert "239.2.3.4".isMulticastAddress == true
  #   doAssert "239.255.255.255".isMulticastAddress == true
  #   doAssert "192.168.2.1".isMulticastAddress == false
  case ipAddr.family
  of IPv4:
    # IPv4 multicast addresses are defined by the leading address bits of 1110
    let firstByte = ipAddr.address_v4[0].byte
    return firstByte.shr(4) == 0x0E # 1110
  of IPv6:
    let firstByte = ipAddr.address_v6[0]
    return firstByte == 0xFF 

proc isMulticastAddress*(group: string): bool =
  let ipAddr = parseIpAddress(group)
  return ipAddr.isMulticastAddress()

proc joinGroup*(socket: Socket, ipAddr: IpAddress, ttl = 255): bool = 
  ## Instructs the os kernel to join a multicast group.
  ## returns true if sucessfull
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
  case ipAddr.family
  of IPv4:
    var mreq = ip_mreq()
    mreq.imr_multiaddr.s_addr = inet_addr($ipAddr)
    mreq.imr_interface.s_addr= htonl(INADDR_ANY)
    var res = setSockOpt(socket.getFd(), IPPROTO_IP, IP_ADD_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
    if res != 0: 
      return false
    socket.getFd().setSockOptInt(IPPROTO_IP, IP_MULTICAST_TTL, ttl)
    return true
  of IPv6:
    var mreq6 = ipv6_mreq()
    mreq6.ipv6mr_multiaddr.s6_addr = cast[array[0..15, char]](ipAddr.address_v6)
    mreq6.ipv6mr_interface  = 0 # let os choose right interface; TODO?    
    var res = setSockOpt(socket.getFd(), IPPROTO_IPV6, IPV6_JOIN_GROUP, addr mreq6, sizeof(ipv6_mreq).SockLen)
    if res != 0: 
      return false
    return true

proc joinGroup*(socket: Socket, group: string, ttl = 255): bool = 
  ## socket.joinGroup("239.2.3.4")
  let ipAddr = group.parseIpAddress()
  return socket.joinGroup(ipAddr, ttl)

proc leaveGroup*(socket: Socket, ipAddr: IpAddress): bool =
  ## Instructs the os kernel to leave a multicast group.
  ## returns true if sucessfull
  ## false otherwise
  case ipAddr.family
  of IPv4:  
    var mreq = ip_mreq()
    mreq.imr_multiaddr.s_addr = inet_addr($ipAddr)
    mreq.imr_interface.s_addr= htonl(INADDR_ANY)
    var res = setSockOpt(socket.getFd(), IPPROTO_IP, IP_DROP_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
    if res != 0: 
      return false
    return true
  of IPv6:
    var mreq6 = ipv6_mreq()
    mreq6.ipv6mr_multiaddr.s6_addr = cast[array[0..15, char]](ipAddr.address_v6)
    mreq6.ipv6mr_interface =  0 # let os choose right interface; TODO?
    var res = setSockOpt(socket.getFd(), IPPROTO_IPV6, IPV6_LEAVE_GROUP, addr mreq6, sizeof(ipv6_mreq).SockLen)
    if res != 0: 
      return false
    return true

proc leaveGroup*(socket: Socket, group: string): bool =
  ## socket.leaveGroup("239.2.3.4")
  let ipAddr = group.parseIpAddress()
  return socket.leaveGroup(ipAddr)

proc enableBroadcast*(socket: Socket, enable: bool) =
  ## enables the socket for broadcast
  let broadcastEnable = if enable: 1 else: 0
  setsockoptint(socket.getFd(), SOL_SOCKET.int, SO_BROADCAST.int,  broadcastEnable);  

when false: # isMainModule : # ipv4 test
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


when isMainModule: # ipv6 test
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
  sleep 5000
  echo socket.leaveGroup("ff02::2")
  while true:
      echo "R: ", socket.recvFrom(data, 1024, address, port ), " ", address,":", port, " " , data

when isMainModule:
    doAssert "224.0.0.0".isMulticastAddress == true
    doAssert "239.2.3.4".isMulticastAddress == true
    doAssert "239.255.255.255".isMulticastAddress == true
    doAssert "192.168.2.1".isMulticastAddress == false
    doAssert "ff02::1".isMulticastAddress == true
    doAssert "2001:0da0:0aab:12f1::aff1".isMulticastAddress == false
