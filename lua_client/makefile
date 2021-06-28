all:
	#gcc mod.c  -llua -lm -shared  -o foo.so
	gcc client.c tweetnacl.c tools.c randombytes.c sample.c -lcrypto -llua -lm -shared -fPIC -o foo.so -g
clean:
	rm -f foo.so a.out
