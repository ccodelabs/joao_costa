import time
import threading

gcount=0

def dialog_thread(name):
    str1 = "Wait for " + name+"'s input:..."
    a = input(str1)
    print("Input by " + name + " was " + a)


def print_nums():
    for i in range(10):
        print(i)

#schedualed event (calls himself)
def hello():
    global gcount
    if gcount<3:
        print(time.ctime()+" : hello")
        threading.Timer(5, hello).start()
        gcount+=1


if __name__ == '__main__':
    t = threading.Thread(target=dialog_thread, args=('joao',)) #pass arguments to thread
    t2 = threading.Thread(target=print_nums)
    hello()
    t.start() #start threads
    t2.start()
    
    t.join()#Main thread will wait for t to be complete

    print('Done')
