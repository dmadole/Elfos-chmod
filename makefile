
all: chmod.bin

lbr: chmod.lbr

clean:
	rm -f chmod.lst
	rm -f chmod.bin
	rm -f chmod.lbr

chmod.bin: chmod.asm include/bios.inc include/kernel.inc
	asm02 -L -b chmod.asm
	rm -f chmod.build

chmod.lbr: chmod.bin
	rm -f chmod.lbr
	lbradd chmod.lbr chmod.bin

