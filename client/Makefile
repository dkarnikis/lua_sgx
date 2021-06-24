CC=gcc
CFLAGS=-Wall -pedantic -Ofast
LFLAGS=-lcrypto #-DDEBUG -g
SOURCE=*.c
APP=client

all:
	$(CC) -o $(APP) $(SOURCE) $(LFLAGS) $(CFLAGS)
clean:
	rm client
