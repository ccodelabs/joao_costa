#! /usr/bin/lua
--[[
Qibixx AG - 27 of September 2019
Script to interface with nextion display and VEMIO
run parameters (default):
-h           -   help
-t (false)   -   enable dash/transaction debug mode
-d (false)   -   enable global debug mode
-v (nil)    -    choose vemio serial port. If not specified, script discovers it
-n (nil)    -    choose Nextion serial port. If not specified, script discovers it

example: lua nextion_main.lua -d 1 -t1 -v /dev/ttyUSB0

Suggestion: let the script discover the ports. Takes around 20 seconds to initialize everything.
]]

require("myfunctions")

--Setting the dash address, or just leave that set to my wallet :) :
dashtx.address = "XkQ4j4yhQ4gzpWKVu3nSDhoWUw3tg6ZAkr";

--Setting up the dash network fee, defaults to 200 which is sufficient for now
--dashtx.NETWORK_FEE = 200;

--Initialize global flags
proceed=false
product=nil
prod=nil
lastVmsg=nil
switch_count=0

products_arr={'p1', --not used
'p2',
'pepsi',
'water',
'crisps',
'wine',
'beer',
'cola',
'coffee',}

--array with prices (eur) per product -> order from left to right and from top to down. Change it accordingly to your products
prices_arr={0.008,
0.008,
0.008,
0.008,
0.008,
0.008,
0.008,}

function main()
  debug,portnextion,portvemio,dashtx.DEBUG=detect_args() --Detect arguments in run command
  DL,DH=create_matrixes()

  if portvemio==nil then 
    if debug then print('[DEBUG] VEMIO port not specified. Entering discover mode...') end
    portvemio=discover_port('VEMIO',5,'VEMIO','V\n')
  end

  if portnextion==nil then
    if debug then print('[DEBUG] Nextion Display port not specified. Entering discover mode...') end
    portnextion=discover_port('Nextion Display',5,'home','page home'..string.char(0xff,0xff,0xff))
  end

  pn=initializeDisplay('Nextion',portnextion)
  pv=initializeVemio('Vemio',portvemio);

  init_prices()--update prices in page home according to table above

end


local ob
local i
  for i=1,#Products,1 do
    ob=string.format("product %u:",i)
    if Products[i] then
      if Products[i].m then 
        ob=ob..string.format(" (%u/%u) ",Products[i].m[1],Products[i].m[2]) .. Products[i].price
      else		-- external product
        ob=ob.. Products[i].ext .. " " .. Products[i].price
      end
      if Products[i].timerstop then ob=ob .. " !! TIMERSTOP AFTER " .. Products[i].timerstop end
      print(ob)
    else 
       break
    end
  end
  
main()

while true do
    uv.run()
end