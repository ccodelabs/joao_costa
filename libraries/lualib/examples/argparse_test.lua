#! /usr/bin/lua
local argparse = require "argparse"
local inspect = require('inspect')
local toboolean = require('toboolean')


--detect argument from command line
function detect_args()
    local parser = argparse()
    parser:option("-p --port", "Nextion Display port (ex.: /dev/ttyUSB0)", nil)
    parser:option("-d --debug", "Enable Debug mode (ex.: true)", 'false')
    local args = parser:parse()
    args.debug=toboolean(args.debug)
    port=args.port
    if args.debug then print('Arguments:\n'..inspect(args)) end
    return args.debug,args.port
  end


debug,port=detect_args()
print(port)