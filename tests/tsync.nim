import net
import ../multicast

const HELLO_PORT = 1900
const HELLO_GROUP = "239.255.255.250"
const TEST_MSG = "testmsg"
const MSG_LEN = TEST_MSG.len

var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
socket.setSockOpt(OptReuseAddr, true)
socket.bindAddr(Port(HELLO_PORT))

if not socket.joinGroup(HELLO_GROUP):
  echo "could not join multicast group"

socket.enableBroadcast true
echo "enabled broadcast for the socket"

discard socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), TEST_MSG)

var 
  data: string = ""
  address: string = ""
  port: Port

echo "R: ", socket.recvFrom(data, MSG_LEN, address, port ), " ", address,":", port, " " , data