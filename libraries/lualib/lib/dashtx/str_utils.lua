local module = {};

function module.split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, '([^'..sep..']+)') do
                t[i] = str
                i = i + 1
        end
        return t
end

function module.starts_with(str, start)
  return str:sub(1, #start) == start;
end

function module.hex_str_to_byte_arr(str)
  local data = {}  
  for i=1,#str,1 do
    if i%2==0 then data[i/2] = tonumber(str:sub(i-1,i),16) end;
  end
  return data;
end

function module.byte_arr_to_hex_str(arr)
  local str='';
  for i=1,#arr,1 do
    str=str..string.format('%02X', arr[i]);
  end
  return str;
end

function module.str_contains(str, val)
  for i=1,#str-#val+1,1 do
    if str:sub(i,i+#val-1) == val then return true end;
  end
  return false;
end

function module.contains(strArr, val)
  for i=1,#strArr,1 do
    if strArr[i] == val then return true end;
  end
  return false;
end

return module;