#!/bin/bash
echo "STARTING UP..." > start.log

ARGS="debug=true tcp-allow-remote-hosts=true"

## Start the daemon
cd vemioDaemon/
nohup lua kimma_daemon.lua $ARGS >log.txt 2>error.txt&