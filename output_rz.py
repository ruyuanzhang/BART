# import windll, to be able to load the inpoutx64.dll/inpout32.dll file
import os
from ctypes import cdll
import sys
from time import sleep
import sys

## If no input is given, write '1' to parallel port
address = int(0xEFF8) # 0x378 in hex
num = 1
marker = sys.argv[1]
print(marker)

# ## if two inputs are given
# if len(sys.argv) > 2:
#     # cast string arguments to:
#     address = int(sys.argv[1],16) # hexadecimal integer
#     num = int(sys.argv[2]) # decimal integer

# load dll.
# Select either inpout32.dll or inpoutx64.dll, depending on which
#  Python version you use. If you get the error:
# WindowsError: [Error 193] %1 is not a valid Win32 application
# You have used the wrong one.
#dll_file = rzpath('C:\ProgramData\Anaconda2\Lib\inpoutx64.dll')
#p = cdll.LoadLibrary('inpoutx64.dll')

# write data
#p.Out32(address,255)
#sleep(0.1)
#p.Out32(address,0)