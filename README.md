# nimMulticast
procs to join and leave a multicast group

# installation
```bash
nimble install nimMulticast
```

# usage:
```nim
import net
import nimMulticast

const 
  HELLO_PORT = 1900
  HELLO_GROUP = "239.255.255.250" # router discovery
  MSG_LEN = 1024

var 
  data: string = ""
  address: string = ""
  port: Port

var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
socket.setSockOpt(OptReuseAddr, true)
socket.bindAddr(Port(HELLO_PORT))

if not socket.joinGroup(HELLO_GROUP):
  echo "could not join multicast group"
  quit()


# For testing we speak upnp manually
var disc = """M-SEARCH * HTTP/1.1
Host:239.255.255.250:1900
ST:urn:schemas-upnp-org:device:InternetGatewayDevice:1
Man:"ssdp:discover"
MX:3""" & "\c\r\c\r" 

# Socket is still a "normal" socket.
# To send to the multicast group just send to its address
discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), disc)

# The socket is supposed to receive every udp datagram
# sent to the multicast group.
while true:
  echo "R: ", socket.recvFrom(data, MSG_LEN, address, port ), " ", address,":", port, " " , data

# Instruct the kernel to leave the group. 
assert socket.leaveGroup(HELLO_GROUP) == true


```
