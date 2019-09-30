import os

class comand:

    def __init__(self,text):
        self.text=text
        #self.user=user
        p = os.popen('ls -l')
        self.response=p.read()

p1=comand("ls")
print(p1.response)