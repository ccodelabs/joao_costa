local uv = require "luv"
local coroutine = require "coroutine"

--Standard delay function with luv library (timeout in ms)
function luvdelay(timeout)
    local cr = coroutine.running()
    local timer = uv.new_timer()

    timer:start(
        timeout,
        0,
        function()
            timer:close()
            timer:stop()
            coroutine.resume(cr)
        end
    )
    coroutine.yield()
end

function loop1()
    while 1 do
        print("qwdeqw")
        a = io.read()
        print(a)
    end
end

function loop2()
    while 1 do
        print(2)
        luvdelay(2000)
    end
end

local cr1 = coroutine.create(loop1)
local cr2 = coroutine.create(loop2)
coroutine.resume(cr1)
coroutine.resume(cr2)

uv.run()
