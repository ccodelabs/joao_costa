import serial
import time

# initial serial port configuration


def initserial():
    ser = serial.Serial()
    ser.baudrate = 115200
    ser.timeout = 3
    ser.port = '/dev/ttyACM0'  # choose USB PORT
    print(ser)
    ser.open()  # open serial comunication
    time.sleep(1)  # wait for serial comunication to be established
    return ser  # pass the handler

# reset buffers


def clearbuffers(ser):
    ser.flushOutput()
    ser.flushInput()
    ser.flush()
    ser.reset_input_buffer()
    ser.reset_output_buffer()

# Read 9 bytes, convert to hex strings and append them to an array


def concat9bytes(arr):
    for i in range(0, 9, 1):
        val = ser.read(1)
        arr[i] = val
    return arr


if __name__ == "__main__":
    arr = [None]*9  # array which will contain bytes sent by TFmini
    msg = "\x02\x30\x31\x30\x30\x03\x01"
    print("Initializing to send: ", msg)
    ser = initserial()

    if ser.is_open:
        clearbuffers(ser)
        #ser.write(serial.to_bytes([0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f, 0x3f]))
        ser.write(msg)
        time.sleep(1)  # wait for message to be sent
        ser.flushOutput()  # clear output buffer
        # only 8 bytes arrive but read(80) to clear buffer
        in_raw = ser.read(80)
        print(in_raw)
        ser.close()
