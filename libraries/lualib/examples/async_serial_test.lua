local uv = require "luv"
require "io"
local str_utils = require("str_utils");
require("myfunctions")
local serial = require('serial');

debug=true

function triggered_func(pinNum,status)
    print("Changed ", pinNum);
    print("Status ", status);
    --fileArr[pinNum]:seek("set",0)
   --local state = fileArr[pinNum]:read("*n")

end

function cb()
  print('polled')
  res=os.capture("head -c 2 /dev/ttyUSB0")
  print(res)
end
  
function os.capture(cmd, raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function main()
    i=0
    readerErr, readerP = serial.open('/dev/ttyUSB0');
    if readerP==nil then
        print('File is nil!')
    else
      readerPoll = uv.new_poll(readerP:fd());
      readerPoll:start('rd', cb)
    end
end 


print('Started')
main()

while true do
    uv.run()
end
