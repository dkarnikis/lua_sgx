all:
	#gcc mod.c  -llua -lm -shared  -o foo.so
	gcc client.c tweetnacl.c tools.c randombytes.c sample.c -lcrypto -g -llua -lm -shared -fPIC -o foo.so -DDEBUG
clean:
	rm -f foo.so a.out
