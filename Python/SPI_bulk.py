import Adafruit_GPIO.FT232H as FT232H

file = open('Blobs/blob_eval', 'rb')
# file = open('Blobs/blob_enrol', 'rb')
 
blob = file.read()

# Take first FT232H device
ft232h = FT232H.FT232H()

# Create a SPI interface from the FT232H using pin 8 (C0) as chip select.
# Use a clock speed of 3mhz, SPI mode 0, and mostspot significant bit first.
spi = FT232H.SPI(ft232h, cs=8, max_speed_hz=1000000, mode=0, bitorder=FT232H.MSBFIRST)

#blob = ["\x00", "\x01", "\x02", "\x03"]

print ("Write blob to device ")

#revoke the first byte to align the communication
blob = blob[1:]
n = 512
blob_chunks = [blob[i:i+n] for i in range(0, len(blob), n)]        # use xrange in py2k
write_cnt = 0
for chunk in blob_chunks:
	check = spi.transfer( chunk )
	write_cnt += len(check)
	
	for i in range(1, len(check)):
		if(hex(ord(chunk[i-1])) != hex(check[i])):
			print ("ERROR @ "+str(i)+" ",)
			print (hex(ord(chunk[i-1])), hex(check[i]))

print ("")
print ("Done! "+str(len(blob))+" bytes")
