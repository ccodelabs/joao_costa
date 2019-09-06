require "os"


local state = 0
local lasttime = 0
local value = 0
local digits =0

wie_state = function(num)
--  print(string.format("wiestate: state=%d lasttime=%d acttime=%d value=%d num=%d",state,lasttime,os.time(),value,num))
  if state==0 or os.time()-lasttime>2 then 			-- catch first char
    state=1
    value=num
    lasttime=os.time()
    digits=1
    return nil
  else
    if state==1 then			-- catch next chars until 4 digits collected
      if num<10 then
        value=10*value+num
        lasttime=os.time()
        digits=digits+1
      else				-- got * or #
        digits=4			-- so force end of code
      end
      if digits==4 then state=0 return value end
    end
  end
end

wie_decode = function(input)
  local i=1
  local l
  local subs
  local xc=0
  local v
  local x

  l=input:len()
  if l<4 then return nil end
  if l==4 then
    return wie_state((input:byte(1)-48)*8+(input:byte(2)-48)*4+(input:byte(3)-48)*2+(input:byte(4)-48)*1)
  else
    print("check string " .. l .. " - " .. input)
  end
  return nil
end
