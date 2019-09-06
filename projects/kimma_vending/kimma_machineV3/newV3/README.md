#Cashless master daemon

Use raspi folder for raspberry installation (with MDB PI hat) and barionet folder for barionet installation (with MDB-USB)

##Run with parameters, example:
	lua cashlessMasterDaemon.lua vmc-slave-address=0x60 vmc-feature-level=2
##Parameters available (default):
 - vmc-slave-address (0x10)
 - vmc-feature-level (3)
 - vmc-display-columns (0)
 - vmc-display-rows (0)
 - vmc-max-price (0xFFFF)
 - vmc-min-price (0x0000)
 
 - tcp-allow-remote-hosts (false) [to allow tcp connections outside 127.0.0.1 set this to true]
 - tcp-port (31421) [tcp server port]
 - tcp-client-timeout (3) [timeout measured from connection intialization to sending a VEND]
 
 - timeout-start (0) [timeout from sending VEND to cashless device starting a session]
 - timeout-vend (0) [timeout for vend approval by cashless device]
 - usb-reconnect-delay (30) [how much time to wait between retries to connect to MDB-USB]
 - debug (false) [enables debug mode]
 - mdb-sniff (false) [enables mdb sniffing]

##Commands:
 - VEND,<amount>,<(optional)startTimeout:seconds>,<(optional)vendApproveTimeout:seconds> [initiates a VEND]
 - STOP [stops the current running session]

##Responses:
 - FAILED,INVALID_STATE [failed to start the session because reader is not in the INIT state]
 - FAILED,MISSING_ARGUMENT [<amount> argument is probably missing]
 - FAILED,INVALID_ARGUMENT,<number> [argument number <number> is invalid and cannot be parsed]
 - FAILED,TIMEOUT,START [start timeout timed out]
 - FAILED,TIMEOUT,VEND [vend timeout timed out] 
 - FAILED,READER_RESET [failed due to reader being reset]
 - FAILED,VEND_DENIED [vend was denied by cashless device]
 - STOPPED,VEND [session stopped during VEND state due to host sending STOP command]
 - STOPPED,STARTING [session stopped during STARTING state due to host sending STOP command]
 - STOPPED,CREDIT [session stopped during CREDIT state due to host sending STOP command]
 - SUCCESS [session successful!]