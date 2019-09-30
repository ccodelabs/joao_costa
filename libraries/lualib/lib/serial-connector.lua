local serial = require('serial');
local str_utils = require('str_utils');

local module = {};

module.DEBUG = false;

--Helper functions--
local function removeNils(data)
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

function module.new(uv, base_path, reconnect_delay, on_connect, on_disconnect, on_line_read)

  local handle;
  local poll;
  local timer;
  local object = {};

  function object.getHandle()
    return handle;
  end

  function object.init()
    --Get serial handle
    handle = nil;
    poll = nil;
    timer = nil;
    for i=0,10,1 do
      local err, p = serial.open(base_path..tostring(i));
      if p~=nil then
        handle = p;
        break;
      end
    end

    if handle==nil then
      --Cannot open handle
      io.write('Cannot open serial handle, retrying in '..tostring(reconnect_delay)..' seconds...','\n');
      io.flush();
      --Auto-reconnect after some time...
      timer = uv.new_timer();
      uv.timer_start(timer,reconnect_delay*1000,0,function()
        timer:stop();
        timer:close();
        timer = nil;
        object.init();
      end);
      return false;
    end

    poll = uv.new_poll(handle:fd());
    
    local dataBuffer = '';
    local dataTable = {};

    poll:start('rd', function(_, events)
      local err, data, size = handle:read(128);

      if size==0 then
        --Disconnected
        io.write("Serial device disconnected",'\n');

        if on_disconnect~=nil then on_disconnect(); end

        poll:stop();
        object.init();
        poll = nil;
      end

      while data~=nil do
        dataBuffer=dataBuffer..data;
        err, data, size = handle:read(128);
      end

      local line = "";
      for i=1,#dataBuffer,1 do
          if dataBuffer:sub(i,i)=='\n' then
              if line~=nil and line~="" then
                  if module.DEBUG then print("Serial received:",line); end
                  if on_line_read~=nil then on_line_read(line); end
                  line = "";
              end
          else
             line = line..dataBuffer:sub(i,i);
          end
      end

      dataBuffer = line;
    end);

    if on_connect~=nil then on_connect(); end
  end

  function object.write(data)
    if handle==nil then
      return false;
    end
    handle:write(data);
    return true;
  end

  function object.disconnect()
    if handle~=nil then
      handle:close();
      handle = nil;
    end
    if timer~=nil then
      timer:stop();
      timer:close();
      timer = nil;
    end
    if poll~=nil then
      poll:stop();
      poll = nil;
    end
  end

  return object;

end

return module;