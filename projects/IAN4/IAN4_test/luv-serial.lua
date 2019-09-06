local coroutine = require 'coroutine'
local uv = require 'luv'
local serial = require 'serial'

SerialPort = {
    BAUD_300 = serial.SERIAL_BAUD_300,
    BAUD_2400 = serial.SERIAL_BAUD_2400,
    BAUD_4800 = serial.SERIAL_BAUD_4800,
    BAUD_9600 = serial.SERIAL_BAUD_9600,
    BAUD_19200 = serial.SERIAL_BAUD_19200,
    BAUD_38400 = serial.SERIAL_BAUD_38400,
    BAUD_57600 = serial.SERIAL_BAUD_57600,
    BAUD_115200 = serial.SERIAL_BAUD_115200,
    BAUD_460800 = serial.SERIAL_BAUD_460800,

    DATA_5 = serial.SERIAL_DATA_5,
    DATA_6 = serial.SERIAL_DATA_6,
    DATA_7 = serial.SERIAL_DATA_7,
    DATA_8 = serial.SERIAL_DATA_8,

    STOP_1 = serial.SERIAL_STOP_1,
    STOP_2 = serial.SERIAL_STOP_2,

    PARITY_NONE = serial.SERIAL_PARITY_NONE,
    PARITY_ODD = serial.SERIAL_PARITY_ODD,
    PARITY_EVEN = serial.SERIAL_PARITY_EVEN,

    FLOW_OFF = serial.SERIAL_FLOW_OFF,
    FLOW_HW = serial.SERIAL_FLOW_HW,
    FLOW_XON_XOFF = serial.SERIAL_FLOW_XON_XOFF,

    DTR_ON = serial.SERIAL_DTR_ON,
    DTR_OFF = serial.SERIAL_DTR_OFF,
    RTS_ON = serial.SERIAL_RTS_ON,
    RTS_OFF = serial.SERIAL_RTS_OFF,

    ERR_NOERROR = serial.SERIAL_ERR_NOERROR,
    ERR_UNKNOWN = serial.SERIAL_ERR_UNKNOWN,
    ERR_OPEN = serial.SERIAL_ERR_OPEN,
    ERR_CLOSE = serial.SERIAL_ERR_CLOSE,
    ERR_FLUSH = serial.SERIAL_ERR_FLUSH,
    ERR_CONFIG = serial.SERIAL_ERR_CONFIG,
    ERR_READ = serial.SERIAL_ERR_READ,
    ERR_WRITE = serial.SERIAL_ERR_WRITE,
    ERR_SELECT = serial.SERIAL_ERR_SELECT,
    ERR_TIMEOUT = serial.SERIAL_ERR_TIMEOUT,
    ERR_IOCTL = serial.SERIAL_ERR_IOCTL,
    ERR_PORT_CLOSED = serial.SERIAL_ERR_PORT_CLOSED,
}

function SerialPort:open(dev)
    local err, port = serial.open(dev)
    if err ~= SerialPort.ERR_NOERROR then
        return err, nil
    end
    local instance = {
        _port = port,
        _poll = uv.new_poll(port:fd())
    }
    self.__index = self
    setmetatable(instance, self)
    return err, instance
end

function SerialPort:set_baud_rate(baud)
    if self._port:set_baud_rate(baud) ~= self.ERR_NOERROR then
        print('Failed setting BAUD rate')
    end
    return self
end

function SerialPort:set_data_bits(data_bits)
    if self._port:set_data_bits(data_bits) ~= self.ERR_NOERROR then
        print('Failed setting data bits')
    end
    return self
end

function SerialPort:set_parity(parity)
    if self._port:set_parity(parity) ~= self.ERR_NOERROR then
        print('Failed setting parity')
    end
    return self
end

function SerialPort:set_stop_bits(stop_bits)
    if self._port:set_stop_bits(stop_bits) ~= self.ERR_NOERROR then
        print('Failed setting stop bits')
    end
    return self
end

function SerialPort:set_flow_control(flow_control)
    if self._port:set_flow_control(flow_control) ~= self.ERR_NOERROR then
        print('Failed setting flow control')
    end
    return self
end


function SerialPort:read(len, callback)
    local this = self

    self._poll:start('rd', function(_, events)
        this._poll:stop()
        err, data, size = this._port:read(len)
        if err ~= 0 then
            callback(err)
        else
            callback(nil, data)
        end
    end)
end

function SerialPort:read_until(lineEnding, callback)
    local line = ''
    local this = self

    lineEnding = lineEnding or '\n'
    local function readChar()
        this:read(1, function(err, data)
            if err ~= 0 then
                callback(err)
            else
                line = line .. data
                if data == lineEnding then
                    callback(err, data)
                else
                    readChar()
                end
            end
        end)
    end
    readChar()
end

function SerialPort:read_line(callback)
    self:read_until('\n', callback)
end
--
-- read with 2 timeouts
-- first timeout is until first character is received
-- second timeout is then to be used while still data comes back
--
databuf=nil

function SerialPort:read_t2(t1,t2)
    local this = self
    local cr = coroutine.running()
    databuf=""

    local timer = uv.new_timer()
    local tim2 = uv.new_timer()
    timer:start(t1, 0, function()	-- start first timeout for first char
        coroutine.resume(cr)
    end)

    self._poll:start('rd', function(_, events)
        err, data, size = this._port:read(1024)
	if data then 
          databuf = databuf .. data
	  tim2:stop()
	  tim2:start(t2,0, function()		-- start in-read timeout
            coroutine.resume(cr)
          end)
	end
    end)
    coroutine.yield()
    timer:close()
    tim2:close()
    this._poll:stop()
    return databuf
end

function SerialPort:read_timeout(timeout, len)
    len = len or 64
    local this = self
    local cr = coroutine.running()
    local data = nil
    local timer = uv.new_timer()
    timer:start(timeout, 0, function()
        timer:close()
        this._poll:stop()
        coroutine.resume(cr)
    end)

    self._poll:start('rd', function(_, events)
        this._poll:stop()
        timer:close()
        err, data, size = this._port:read(64)
        if err == 0 then

        end
        coroutine.resume(cr)
    end)
    coroutine.yield()
    return data
end

function SerialPort:write(data)
    return self._port:write(data)
end

function SerialPort:close()
    return self._port:close()
end

return SerialPort
