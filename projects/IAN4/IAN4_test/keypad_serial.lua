--Turns ON/OFF relay, with time interval=time. Serial port is the hander that comunicates with the keypad, initialized in the main script
function opengate(time,serial_port)
    print('Access Granted!')
    file = io.open("/sys/class/gpio/gpio501/value", "w")
    file:write('1')
    file:close() 
    serial_port:write("\n")		--turn ON green light on keypad
    serial_port:write("O1,0\n")
    print('led on')
    
    os.execute("sleep " .. tonumber(time))

    file = io.open("/sys/class/gpio/gpio501/value", "w")
    file:write('0')
    file:close()
    serial_port:write("\n")              --turn ON red light on keypad
    serial_port:write("O1,1\n")
end
