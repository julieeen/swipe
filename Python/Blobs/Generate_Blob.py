#!/bin/python
import sys
import cPickle as pickle

filename = "learning_spi_data.txt"

with open(filename) as f:
    content = f.readlines()

if(content[1].split(",")[-2] != "0xFC"):
	print "ERROR: misalign ..."
	exit()


blob = []
# dismiss first line with tab infos
for i in range(1, len(content)):
	# read value
	hex_str = content[i].split(",")[-1].replace("\n","")
	hex_byte = hex_str[2:].decode("hex")
	# print ord(hex_data)
	blob.append(hex_byte)


f = open('blob', 'w')
for i in range(0, len(blob)):
	f.write(blob[i])
f.close()

print "save "+str(len(blob))+" bytes to blob"
