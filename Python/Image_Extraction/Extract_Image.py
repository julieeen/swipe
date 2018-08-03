import csv, json
from PIL import Image
import numpy
import json

def read_file(filename):
	with open(filename) as csvfile:
		reader = csv.reader(csvfile, delimiter='\t')
		a1 = []
		a2 = []
		a0 = []
		for i, line in enumerate(reader):
			if(i == 0):
				continue
			if len(line) >= 3:
				a0.append(float(line[0]))
				a1.append(int(line[2]))
				a2.append(int(line[1]))
			else:
				print("Zeile {} hat keine 3 tab-gentrennten Spalten: {}".format(i, line))
	return a0, a1, a2


liste0, liste1, liste2 = read_file("untitled.tsv")
print len(liste1), len(liste2)

# search for 0 -> 1 change in channel2 ("after sending")
spi_samples = []
for i, value in enumerate(liste2):
	if liste2[i-1] == 0 and value == 1:
		spi_samples.append(i)

numberOfBytes = (len(spi_samples)/8)
print "Bytes: "+str(numberOfBytes)

byts = []
for i in range(0, len(spi_samples), 8):
	byte_index = spi_samples[0+i:8+i]
	bytestr = ""
	for index in byte_index:
		bitvalue = liste1[index]
		bytestr += str(bitvalue)

	#print bytestr
	b_i = (int(bytestr, 2))
	byts.append(b_i)


# CREATE PNG FROM SNIFFED DATA
bmp_bs = byts[-192**2:] # take last 192*192

print len(bmp_bs)
cnt = 0
for i in range(0, len(bmp_bs)):
	if(bmp_bs[i] != 0):
		cnt += 1


store_img = Image.new('L', (192,192))
store_img.putdata(bmp_bs)
store_img.save('extracted.tif')
