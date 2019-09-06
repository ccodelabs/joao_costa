import serial
import time

#convert hex string to array with the readings (in miliVolts) of the 4 inputs arr[A1,A2,A3,A4]
def hex2intarray(raw):
    arr=[]
    if len(raw)==8: #only process if the reading is good
        for i in range(0,len(raw)-1,2):
            val=in_raw[i]*256+in_raw[i+1] #convert to int (MSB first)
            arr.append(val) #convert to int (mV) and append to array
    else:
        ser.flushOutput()
        ser.flushInput()
        ser.flush()
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print('Bad reading. Waiting for the next one...')
    
    return arr[::-1]  #return fliped array
        

#initial serial port configuration
def initserial():
    ser = serial.Serial()
    ser.baudrate = 115200
    ser.timeout = 3
    ser.port = '/dev/ttyUSB1' #choose USB PORT 
    #print(ser)
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



if __name__ == "__main__":

    ser = initserial()

    if ser.is_open:
        while 1:  #Main Loop
            ser.write(serial.to_bytes([0x3f,0x3f,0x3f,0x3f,0x3f,0x3f,0x3f,0x3f])) #write 8 bytes to serial port (1st adress + 7 random)
            time.sleep(1)  #wait for message to be sent
            ser.flushOutput() #clear output buffer
            in_raw = ser.read(80) #only 8 bytes arrive but read(80) to clear buffer            
            arr= hex2intarray(in_raw) #decode message
            print(arr)
            clearbuffers(ser)
            time.sleep(0.5)