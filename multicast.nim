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
import net, os, nativesockets

const IPPROTO_IP = 0
const IPPROTO_IPV6 = 41

when defined windows:
  from winlean import In_Addr, inet_addr, setSockOpt# , # In6Addr
  # Old windows
  # const IP_ADD_MEMBERSHIP  = 5
  # const IP_DROP_MEMBERSHIP = 6 
  # const IP_MULTICAST_TTL = 3
  # New windows
  # TODO (my) mingw crosscompiler misses In6Addr so defined here
  type
    In6Addr = object
      bytes: array[0..15, char]
  const 
    IP_ADD_MEMBERSHIP  = 12
    IP_DROP_MEMBERSHIP = 13
    IP_MULTICAST_TTL = 10
    IPV6_JOIN_GROUP = 12 # TODO ipv6 needs testing
    IPV6_LEAVE_GROUP = 13 # TODO ipv6 needs testing
else:
  from posix import In_Addr, inet_addr, setSockOpt, In6Addr, 
    IPV6_JOIN_GROUP, IPV6_LEAVE_GROUP, inet_pton # , Tipv6_mreq
  const
    IP_ADD_MEMBERSHIP  = 35
    IP_DROP_MEMBERSHIP = 36
    IP_MULTICAST_TTL = 33
    # IPV6_JOIN_GROUP = 0 # TODO ipv6 needs testing
    # IPV6_LEAVE_GROUP = 0 # TODO ipv6 needs testing
type 
  ip_mreq = object {.pure, final.}
    imr_multiaddr*: InAddr
    imr_interface*: InAddr
  ipv6_mreq = object {.pure, final.} # there is in posix but missing in winlean!
    ipv6mr_multiaddr*: In6Addr ## IPv6 multicast address.
    ipv6mr_interface*: cint ## Interface index.    

proc isMulticastAddress*(ipAddr: IpAddress): bool =
  ## returns true wether the given IpAddress is a ipv4 or ipv6 multicast
  ## address, false otherwise
  case ipAddr.family
  of IPv4:
    let firstByte = ipAddr.address_v4[0].byte
    return firstByte.shr(4) == 0x0E # 1110
  of IPv6:
    let firstByte = ipAddr.address_v6[0]
    return firstByte == 0xFF 

proc isMulticastAddress*(group: string): bool =
  let ipAddr = parseIpAddress(group)
  return ipAddr.isMulticastAddress()

proc joinGroup*(fd: SocketHandle, ipAddr: IpAddress, ttl = 255): bool = 
  ## Instructs the os kernel to join a multicast group.
  ## returns true if sucessfull
  ## false otherwise
  ## 
  # Values for TTL:
  #  TTL     Scope
  # ----------------------------------------------------------------------
  #    0 Restricted to the same host. Won't be output by any interface.
  #    1 Restricted to the same subnet. Won't be forwarded by a router.
  #  <32 Restricted to the same site, organization or department.
  #  <64 Restricted to the same region.
  # <128 Restricted to the same continent.
  # <255 Unrestricted in scope. Global.
  case ipAddr.family
  of IPv4:
    var mreq = ip_mreq()
    mreq.imr_multiaddr.s_addr = inet_addr($ipAddr)
    mreq.imr_interface.s_addr= htonl(INADDR_ANY)
    var res = setSockOpt(fd, IPPROTO_IP, IP_ADD_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
    if res != 0: 
      return false
    fd.setSockOptInt(IPPROTO_IP, IP_MULTICAST_TTL, ttl)
    return true
  of IPv6:
    var mreq6 = ipv6_mreq()
    when defined windows:
      mreq6.ipv6mr_multiaddr.bytes = cast[array[0..15, char]](ipAddr.address_v6)
    else:
      mreq6.ipv6mr_multiaddr.s6_addr = cast[array[0..15, char]](ipAddr.address_v6)
    mreq6.ipv6mr_interface  = 0 # let os choose right interface; TODO?    
    var res = setSockOpt(fd, IPPROTO_IPV6, IPV6_JOIN_GROUP, addr mreq6, sizeof(ipv6_mreq).SockLen)
    return res == 0 

proc joinGroup*(socket: Socket, ipAddr: IpAddress, ttl = 255): bool = 
  return joinGroup(socket.getFd(), ipAddr, ttl)

proc joinGroup*(socket: Socket, group: string, ttl = 255): bool = 
  ## socket.joinGroup("239.2.3.4")
  let ipAddr = group.parseIpAddress()
  return socket.joinGroup(ipAddr, ttl)

proc leaveGroup*(fd: SocketHandle, ipAddr: IpAddress): bool =
  ## Instructs the os kernel to leave a multicast group.
  ## returns true if sucessfull
  ## false otherwise
  case ipAddr.family
  of IPv4:  
    var mreq = ip_mreq()
    mreq.imr_multiaddr.s_addr = inet_addr($ipAddr)
    mreq.imr_interface.s_addr = htonl(INADDR_ANY)
    var res = setSockOpt(fd, IPPROTO_IP, IP_DROP_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
    return res == 0 
  of IPv6:
    var mreq6 = ipv6_mreq()
    when defined windows:
      mreq6.ipv6mr_multiaddr.bytes = cast[array[0..15, char]](ipAddr.address_v6)
    else:
      mreq6.ipv6mr_multiaddr.s6_addr = cast[array[0..15, char]](ipAddr.address_v6)    
    mreq6.ipv6mr_interface =  0 # let os choose right interface; TODO?
    var res = setSockOpt(fd, IPPROTO_IPV6, IPV6_LEAVE_GROUP, addr mreq6, sizeof(ipv6_mreq).SockLen)
    return res == 0

proc leaveGroup*(socket: Socket, ipAddr: IpAddress): bool =
  return leaveGroup(socket.getFd(), ipAddr)

proc leaveGroup*(socket: Socket, group: string): bool =
  ## socket.leaveGroup("239.2.3.4")
  let ipAddr = group.parseIpAddress()
  return socket.leaveGroup(ipAddr)

proc enableBroadcast*(fd: SocketHandle, enable: bool) =
  ## enables the socket for broadcast
  let broadcastEnable = if enable: 1 else: 0
  setsockoptint(fd, SOL_SOCKET.int, SO_BROADCAST.int,  broadcastEnable);  

proc enableBroadcast*(socket: Socket, enable: bool) =
  socket.getFd.enableBroadcast(enable)

when isMainModule:
  assert "224.0.0.0".isMulticastAddress == true
  assert "239.2.3.4".isMulticastAddress == true
  assert "239.255.255.255".isMulticastAddress == true
  assert "192.168.2.1".isMulticastAddress == false
  assert "ff02::1".isMulticastAddress == true
  assert "2001:0da0:0aab:12f1::aff1".isMulticastAddress == false  