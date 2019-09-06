import serial
import time
      
#initial serial port configuration
def initserial():
    ser = serial.Serial()
    ser.baudrate = 9600
    ser.timeout = 3
    ser.port = '/dev/ttyUSB0' #choose USB PORT 
    print(ser)
    ser.open() #open serial comunication
    time.sleep(1) #wait for serial comunication to be established
    return ser #pass the handler

#reset buffers
def clearbuffers(ser):
    ser.flushOutput()
    ser.flushInput()
    ser.flush()
    ser.reset_input_buffer()
    ser.reset_output_buffer()

#Read 9 bytes, convert to hex strings and append them to an array
def concat9bytes(arr):
    for i in range(0,9,1):
        val=ser.read(1)
        arr[i]=val
    return arr



if __name__ == "__main__":
    ser = initserial()   

    if ser.is_open:
        clearbuffers(ser)
        packet= b"\x74\x30\x2E\x74\x78\x74\x3d\x22\x32\x32\x33\x22\xff\xff\xff"
        print(type(packet))
        time.sleep(1)
        ser.write(packet)
        print(packet)
        print("Done. Going to sleep...")
        time.sleep(5)