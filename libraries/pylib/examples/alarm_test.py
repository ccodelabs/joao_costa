'''import time
import threading

def func1():
    print('Exit')

def func2():
    print(a)


a=1
print('start')
timer=threading.Timer(5, func1).start()
timer2=threading.Timer(1,func2).start()
while 1:
    print('\n')'''

'''
import serial.tools.list_ports
comlist = serial.tools.list_ports.comports()
connected = []
for element in comlist:
    connected.append(element.device)
print("Connected COM ports: " + str(connected))
for i in range(len(connected)):
    print(connected[i])
    print(i)
    break'''

import signal
import time

def handler():
    raise Exception("end of time")
   

# This function *may* run for an indetermined time...
def loop_forever():  
    while 1:
        print("sec")
        time.sleep(1)
        
'''  

# Register the signal function handler
#signal.signal(signal.SIGALRM, handler)


# Define a timeout for your function
signal.alarm(5)
#signal.alarm(0)


try:
    loop_forever()
except Exception as exc: 
    print(exc)

'''
import signal

def handler(signum, frame):
    print('Signal handler called with signal', signum)
    raise Exception("Couldn't open device!")

# Set the signal handler and a 5-second alarm
signal.signal(signal.SIGALRM, handler)
signal.alarm(5)

# This open() may hang indefinitely
try:
    loop_forever()
except Exception as exc: 
    print(exc)
print('ddd')

signal.alarm(0)          # Disable the alarm
