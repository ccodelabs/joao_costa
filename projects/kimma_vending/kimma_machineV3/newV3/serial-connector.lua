local periphery = require('periphery');
local Serial = periphery.Serial;
local str_utils = require('str_utils');

local module = {};

--Helper functions--
function removeNils(data)
  local dataArr = {};
  local ret = '';
  local firstIndex = 1;
  for i=1,#data,1 do
    dataArr[i]=string.byte(data,i);
  end
  for i=1,#dataArr,1 do
    if dataArr[i]==0 then
      ret=ret..'';
    else
      ret=ret..string.char(dataArr[i]);
    end
  end
  return ret;
end
---------------------

function module.initializeDevice(on_connect, on_disconnect, on_data_read)
  --Get serial handle
  for i=0,10,1 do
    local p = Serial{device="/dev/ttyACM"..tostring(i), baudrate=115200, databits=8, parity="none", stopbits=1, xonxoff=false, rtscts=false};
  	if p~=nil then
  	  module.p = p;
      break;
    end
  end

  if module.p==nil then
    --Cannot open handle
    io.write('Cannot open serial handle, retrying in 30 seconds...','\n');
    io.flush();
    --Auto-reconnect after some time...
    local timer = uv.new_timer();
    uv.timer_start(timer,USB_RECONNECT_DELAY,0,function()
    	timer:stop();
  		timer:close();
      module.initializeMdbDevice();
    end);
    return false;
  end

  module.poll = uv.new_poll(module.p.fd);
  
  local dataBuffer = '';
  local dataTable = {};

  module.poll:start('rd', function(_, events)
    local data = module.p:read(128,0);

    if data==nil or data:len()==0 then
      --Disconnected
      io.write("Device Disconnected",'\n');

  	  on_disconnect();

      local previousPoll = module.poll;
      module.initializeDevice(on_connect, on_disconnect, on_data_read);
      previousPoll:stop();
    end

    if data~=nil then
      dataBuffer=dataBuffer..removeNils(data);
      --print("DATA BUFFER: "..dataBuffer);
      dataTable = str_utils.split(dataBuffer,'\n');
      for i=1,#dataTable-1,1 do
        local str = dataTable[i];
        if str~='' then
          on_data_read(str);
        end
        dataBuffer=dataBuffer:sub(str:len()+1,#dataBuffer);
      end
      if string.char(dataBuffer:byte(dataBuffer:len()))=='\n' then
        local str = dataBuffer:sub(1,dataBuffer:len()-1);
        dataBuffer = '';
        on_data_read(str);
      end
    end
  end);

  io.write("Device Connected",'\n');
  on_connect();

end

function module.write(data)
  module.p:write(data);
end

return module;