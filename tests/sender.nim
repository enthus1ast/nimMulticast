import net
import os
import strutils
const HELLO_PORT = 12346
const HELLO_GROUP = "225.0.0.39"

var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

while true:
  echo "snd"
  socket.sendTo(HELLO_GROUP, Port(HELLO_PORT), "hallo tobias\n")
  sleep(1_000)
