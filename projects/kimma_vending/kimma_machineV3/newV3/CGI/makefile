AFLAGS  = -f coff
CC      = gcc
CFLAGS  = -g -D_REENTRANT -D_GNU_SOURCE -O0
INCPATH =
LINK	= gcc
LFLAGS	=
LIBS	=

HEADERS =
SOURCES = process_donation.c
OBJECTS = process_donation.o
TARGET  = process_donation.bin

.SUFFIXES: .cpp .cxx .cc .c .s .asm

.cpp.o:
	$(CC) -c $(CFLAGS) $(INCPATH) $<

.cxx.o:
	$(CC) -c $(CFLAGS) $(INCPATH) $<

.cc.o:
	$(CC) -c $(CFLAGS) $(INCPATH) $<

.c.o:
	$(CC) -c $(CFLAGS) $(INCPATH) $<

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(LINK) $(LFLAGS) -o $(TARGET) $(OBJECTS) $(LIBS)

tmake: Makefile

clean:
	@rm -f $(TARGET) $(OBJECTS)
