'''
Python Script to interface MDB-USB as master with cashless reader as slave.
Created 6 Sep 2019 by João Costa - Qibixx AG
'''
import serial
import time
import sys



if len(sys.argv)<2:
    debug = False
elif arg_arr[0]=='debug':
    arg_arr=[]
    arg_arr=sys.argv[1].split('=')
    debug=int(arg_arr[1])
else:
    exit('Unknown Argument. Exiting...')

if debug:print('Debug Activated!')


# initial serial port configuration
def initserial():
    ser = serial.Serial()
    ser.baudrate = 115200
    ser.timeout = 1
    ser.port = '/dev/ttyACM1'  # choose USB PORT
    ser.open()  # open serial comunication
    time.sleep(1)  # wait for serial comunication to be established
    return ser  # pass the handler

#Init MDB master and slave (reader device)
def init_devices(ser):
    res, lines = write_and_readlns("D,2\n", ser)  # start the master device in Direct Vend mode
    if res.find('D,ERR,"cashless master is on"')!=-1:
        res, lines = write_and_readlns("D,0\n", ser)  # Master Device was already enabled. Restart it
        res, lines = write_and_readlns("D,2\n", ser) 

    while res.find('d,STATUS,RESET')==-1:
        print('Waiting for cashless master to respond...')
        res = read_and_wait()

    while res.find('d,STATUS,INIT')==-1:  #Wait for cashless reader (slave) to respond
        print('Waiting for STATUS = INIT. Please enable the reader...')
        res = read_and_wait(ser)
    
    res, lines = write_and_readlns("D,READER,1\n", ser)  # Enable the reader
    while res.find('d,STATUS,IDLE')==-1:  #Wait for cashless reader (slave) to be IDLE
        print('Waiting for STATUS = IDLE...')
        res = read_and_wait(ser)
    if debug: print("Slave device is IDLE...")

# read response from serial and return array of lines
def write_and_readlns(send_str, ser):
    if debug: print("Sending: "+send_str.strip())
    ser.write(send_str.encode())
    response=read_and_wait(ser)
    lines = response.split("\r\n")
    if len(lines) != 0:
        return response, lines
    else:
        ser.close()
        exit("Device is not responding. Quitting...")

# read from serial and block code execution
def read_and_wait(ser):
    while ser.inWaiting() < 5:  # Wait for media to be inserted
        #if debug:print('Waiting')
        time.sleep(0.5)
    res = ser.read(ser.inWaiting()).decode("utf-8").strip()
    if debug: print('Received: '+res)
    return res


#detect if cashless device supports direct vend or not. Returns: false if not, response if yes
def detect_direct_vend(amount,product,ser):
    res, lines = write_and_readlns("D,REQ,"+amount+","+product+"\n", ser)  # Request Vending
    if lines[0] == 'd,ERR,"-1"':  #Normal device returns error
        return False
    elif lines[0] == 'd,STATUS,VEND': #to test with normal MDB as slave,put here len(res)>5
        return res
    else:exit('Unknown response by the slave. Exiting...')

#if device dont supports direct vend, call this function
def normal_vend(amount, product, ser):
    print('Please insert payment media in the cashless device...')
    req_str="D,REQ,"+amount+","+product+"\n"
    res=read_and_wait(ser)
    if debug:print(res)
    if res.find('d,STATUS,CREDIT,')!=-1:
        cash= res[res.find('d,STATUS,CREDIT,')+16:len(res)-3]
        print('Media Detected with '+cash)
        if float(cash)>=float(amount):
            res, lines = write_and_readlns(req_str, ser)
            if res.find('d,STATUS,VEND')!=-1:
                end_transaction(amount,product,ser)
            else:
                exit('Bad Response from the reader. Exiting...')

        else:
            exit('Payment media has no sufficient funds to purchase the desired product.\nExiting...')
    else:
        exit('Bad Response from the reader. Exiting...')


#Call this function when waiting for confirmation by the slave device)
def end_transaction(amount,product,ser):
    print('Waiting for transaction to be confirmed...')
    res=read_and_wait(ser)
    if res.find('SUCCESS')!=-1 or res.find('d,STATUS,RESULT,1')!=-1 :
        print('Success! Deviced was charged for '+amount+', for product '+product)
    elif res.find('FAILED')!=-1 or res.find('d,STATUS,RESULT,-1')!=-1:
        print('Transaction Denied by cashless device!')
    else:
        print('Transaction Failed!')
    if debug:print('Going back to IDLE state...')
    res, lines = write_and_readlns("D,END\n", ser)

#Disable the slave, master and close serial port.
def end_comunication(ser):
    res, lines = write_and_readlns("D,READER,0\n", ser)  # Disable the reader (slave)
    res, lines = write_and_readlns("D,0\n", ser)  # Disable the host (master)
    ser.close()

if __name__ == "__main__":
    print("Initializing serial port...")
    ser = initserial()
    if  ser.is_open:
        init_devices(ser)                
        amount,product=input("Enter the amount and the product to dispense, separated by a space and hit enter\n(ex.:1.2 10): ").strip().split() #wait for user input

        direct = detect_direct_vend(amount,product,ser)        
        if not direct: #Automatically falls back to D,1 (normal Vend) and proceed
            normal_vend(amount,product,ser)  
        else: #Direct Vend detected
            if debug: print('Direct Vend detected')
            res=read_and_wait(ser)  #Wait for user to present the card
            end_transaction(amount,product,ser)

        end_comunication(ser)
        print("Finished...")
    else:
        print("Failed to open Serial port")
