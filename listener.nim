## Let socket join a multicast group
## TODO test on windows
import net
import os
import strutils
import nativesockets

when defined windows:
  from windows import InAddr, inet_addr, setSockOpt
else:
  from posix import InAddr, inet_addr, setSockOpt

type 
  ip_mreq = object {.pure, final.}
    imr_multiaddr*: InAddr
    imr_interface*: InAddr

const IP_ADD_MEMBERSHIP  = 35.cint
const IP_DROP_MEMBERSHIP = 36.cint
const IPPROTO_IP = 0.cint
const HELLO_PORT = 12346
const HELLO_GROUP = "225.0.0.39"


proc joinGroup*(socket: Socket, group: string): bool = 
  ## Joins a multicast group
  ## return true if sucessfull
  ## false otherwise
  var mreq = ip_mreq()
  mreq.imr_multiaddr.s_addr = inet_addr(HELLO_GROUP)
  mreq.imr_interface.s_addr= htonl(INADDR_ANY)

  var res = setSockOpt(socket.getFd(), IPPROTO_IP, IP_ADD_MEMBERSHIP, addr mreq, sizeof(ip_mreq).SockLen)
  if res == 0: 
    return true
  else:
    return false

when isMainModule:

  var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
  socket.setSockOpt(OptReuseAddr, true)
  socket.bindAddr(Port(HELLO_PORT))

  if not socket.joinGroup(HELLO_GROUP):
    echo "could not join multicast group"
    quit()

  const MSG_LEN = 256
  var 
    data: string = ""
    address: string = ""
    port: Port

  while true:
    echo "R:", socket.recvFrom(data, MSG_LEN, address, port ), data


