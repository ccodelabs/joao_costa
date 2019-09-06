local uv = require 'luv'
local uci = require 'uci'
local coroutine = require 'coroutine'
local serial = require 'luv-serial'

require 'keypad_serial'
ipport = 59999
chan = 0
access_key={1,3,0,3}   --to change the access_key, change this line

require 'nixio'
--require 'logic'

mode= nil

local err, serial_port = serial:open("/dev/ttyACM0")
if err ~= serial.ERR_NOERROR then
	print 'No RF Dongle found. Working without RF'
        serial_port=nil
else
	print 'Dongle found'
end

function serial_loop()
    while true do
        local data = serial_port:read_timeout(1000, 1000) --data is 1 bit
        if data ~= nil then
	   counter=counter+1
	   if counter ~=5 and counter ~=10 and counter~=15 then --ignore \n characters
	    totalstr=totalstr..data   --concat bit
	   end

	   if counter==19 then		
		print("Data: ",totalstr)
		for i = 1,16,4 do
	           substr=string.sub(totalstr,i,i+3) --str with 4 bits equal 1 char
		   print('substring: ',substr,'\n Len:',string.len(substr))
		   decimal=tonumber(substr,2)      --number pressed in keypad
		   numbers[count1+1]=decimal	   -- append numbers typed to array
		   count1=count1+1
		end 
		for k=0,3,1 do print('Numbers: ',numbers[k+1],'Access_Key: ',access_key[k+1]) end
		if numbers[1]==access_key[1] and numbers[2]==access_key[2] and numbers[3]==access_key[3] and numbers[4]==access_key[4] then
			opengate(1,serial_port)

		else 
		   print('Access Denied!')
		   serial_port:write("\n")              --turn ON red light omn keypad
		   serial_port:write("O1,1\n")
		end
	   end

        else
        print('Please insert the access key...')
	    serial_port:write("r\n")
	    totalstr=""
	    counter=0
	    count1=0
	    numbers={}
        end
    end
end

-- set mux first time

-- kick on the serial receiver for the first time
if serial_port~=nil then
  serial_port:write("r\n")

  local cr = coroutine.create(serial_loop)
  coroutine.resume(cr)
end

uv.run()
