


-- product table, containing technical data for how to dispense products
-- local products:
--   m{} contains the motor IDs to start/stop
--   if pulse=xx  is given these pulses are counted to stop in position
--   if timerstop is given the motors will be switched off latest at that time
-- remote products
--   ext= is the the command to be sent by udp
--   ip is the ip address to send the command to
--   port is the port number to send the command to

Products = {
    [1] =   { m={1,25},price=0.08,pulse=3,timerstop=10 },
    [2] =   { m={2,25},price=0.01,pulse=3,timerstop=10 },
    [3] =   { m={3,25},price=0.05,pulse=3,timerstop=10 },
    [4] =   { m={4,25},price=0.02,pulse=3,timerstop=10 },
    [5] =   { m={1,26},price=0.05,timerstop=4 },
    [6] =   { m={2,26},price=0.5,timerstop=4 },
    [7] =   { ext="coffee",ip="192.168.2.134",port=12345,price=0.08 },
}
