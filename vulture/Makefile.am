#
# vulture 0.9
# Copyright (C) 2003 by rd <rd@vnsecurity.net>
#

KERNELDIR = /usr/src/linux
MODVERFILE = $(KERNELDIR)/include/linux/modversions.h
MODDEFS = -D__KERNEL__ -DMODULE -DMODVERSIONS 

#ifdef DEBUG
MODDEFS += -DDEBUG
#endif

MODFLAGS = -I$(KERNELDIR)/include -include $(MODVERFILE)

AM_CFLAGS = -Wall -O2 -Wstrict-prototypes -fomit-frame-pointer -pipe -fno-strength-reduce -falign-loops=2 -falign-jumps=2 -falign-functions=2

bin_PROGRAMS = vulture.o cleaner.o vulturec

vulture_SOURCES =  vulture.c vulture.h
cleaner_SOURCES =  cleaner.c
vulturec_SOURCES =  vulturec.c vulture.h

vulture.o: vulture.c
	$(CC) $(AM_CFLAGS) $(MODDEFS) $(MODFLAGS) -c $^ -o $@

cleaner.o: cleaner.c
	$(CC) $(AM_CFLAGS) $(MODDEFS) $(MODFLAGS) -c $^ -o $@

vulturec: vulturec.c
	$(CC) $(AM_CFLAGS) $^ -o $@
