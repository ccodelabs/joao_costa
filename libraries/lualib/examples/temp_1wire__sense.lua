-- see if the file exists
function file_exists(file)
    local f = io.open(file, "rb")
    if f then
        f:close()
    end
    return f ~= nil
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
function lines_from(file)
    if not file_exists(file) then
        return {}
    end
    lines = {}
    for line in io.lines(file) do
        lines[#lines + 1] = line
    end
    return lines
end

--Read one-wire temperature sensor
function read_temp(time, serial_port)
    temp_sensor = "/sys/bus/w1/devices/28-041720d980ff/w1_slave"
    local exist= file_exists(temp_sensor)
    
    
    file = io.open(temp_sensor, "r")
    file:close()
end

file = "/sys/bus/w1/devices/28-041720d980ff/w1_slave"
f = file_exists(file)
print(f, " ", type(f))

lines = lines_from(file)
print(lines[1])
