import Adafruit_GPIO.FT232H as FT232H

file = open('Blobs/blob_enrol', 'rb')
# file = open('Blobs/blob_eval', 'rb')
blob = file.read()


# Take first FT232H device
ft232h = FT232H.FT232H()

# Create a SPI interface from the FT232H using pin 8 (C0) as chip select.
# Use a clock speed of 3mhz, SPI mode 0, and most significant bit first.
spi = FT232H.SPI(ft232h, cs=8, max_speed_hz=1000000, mode=0, bitorder=FT232H.MSBFIRST)

#blob = ["\x00", "\x01", "\x02", "\x03"]

print "Write blob to device ",

# dismiss first byte, to align the data correctly
last_byte = blob[1] 
for i in range(1, len(blob)):
	
	# send a byte and receive the last ...
	value = spi.transfer( blob[i] )

	# check if spi answer equals last byte
	last_byte = value
	if(last_byte != value):
		print "comm error "+str(ord(last_byte))+" != "+str(ord(value))

	if(i%1000 == 0):
 		print ".",

print ""
print "Done! "+str(len(blob))+" bytes"
