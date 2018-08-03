#!/bin/python
import sys
from PIL import Image
import struct
import numpy as np

filename = "logic_sniff_evaluation.txt"
outfilename = "blob_eval"	

fingerprint_image = "fp16.tif"

# Open logic sniff we want to use to build the new blob
with open(filename) as f:
    content = f.readlines()

if(content[1].split(",")[-2] != "0xFC"):
	print "ERROR: misalign ..."
	exit()


# data we want to inject (192x192 bytes)
img = Image.open(fingerprint_image) 	#Can be many different formats.
img = img.convert('L')  				# convert rgb images to grey value!
img_data = img.load()

print img.size 	#Get the width and hight of the image for iterating over
img_bytes = []
i = 0

for y in range(0, img.size[1]):
	for x in range(0, img.size[0]):
		img_bytes.append( chr( img_data[x,y] ) )


if(len(img_bytes) != 36864):
	print "ERROR: image size NOT 36864  <---"
	exit()


blob = []
# dismiss first line with tab infos
for i in range(1, len(content)):
	# just copy data from the origin logic sniff
	hex_str = content[i].split(",")[-1].replace("\n","")
	hex_byte = hex_str[2:].decode("hex")
	# print ord(hex_data)
	blob.append(hex_byte)


inject_cnt = 0
c4_cnt = 0 # first c4 is for the preimage, second for the full image
inject_positions = []
for i in range(1, len(content)):
	cmd = content[i-1].split(",")[-2]
	# if previous cmd is 0xC4, then image bytes have to follow ...	
	if( cmd == "0xC4" ):
		c4_cnt += 1
		if((c4_cnt%2 == 0)): # only inject at any second c4 ...
			inject_positions.append(i)

bytes_to_inject = len(img_bytes)

# inject data
print inject_positions
for v in inject_positions:
	blob[ v : v+bytes_to_inject ] = img_bytes


f = open(outfilename, 'w')
for i in range(0, len(blob)):
	f.write(blob[i])
f.close()

print "save "+str(len(blob))+" bytes to blob"
