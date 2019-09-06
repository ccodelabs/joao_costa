import serial
import time
      
#initial serial port configuration
def initserial():
    ser = serial.Serial()
    ser.baudrate = 115200
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
    arr=[None]*9 #array which will contain bytes sent by TFmini
    ser = initserial()   

    if ser.is_open:
        clearbuffers(ser)
        arr=concat9bytes(arr)
        print(arr)
        print(type(arr[0]))

        while 1: #Main loop
            if arr[0]==b'\x59' and arr[1]==b'\x59': #if order is correct then get measurement, drop 9 bytes and get next 9
                distance=ord(arr[2])+ord(arr[3])*256
                print(distance)
                time.sleep(0.105)
                clearbuffers(ser)
                arr=concat9bytes(arr) #read 9 new bytes and append to array


            else: #drop 1st byte, shift all to the left and concat another one
                print('else')
                for i in range(0,len(arr)-1,1):
                    arr[i]=arr[i+1]  #shift array

                arr[len(arr)-1]=ser.read(1) #concat next incoming byte 

            