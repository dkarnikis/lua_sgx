#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include "tools.h"
#include "tweetnacl.h"
#include "../Enclave_t.h"
#include "sgx_defs.h"
#include "sgx_trts.h"
#include "../sgx_structs.h"
#include "../sgx_funcs.h"

void output_key(char *str, unsigned char key[], int key_size) {
    int i;
    printf("Printing: %s", str);//, key_size, key);
    for (i = 0; i < key_size; i++) {
        printf("%u", key[i]);
    }
    printf("\n");
}

void
decrypt(Content encrypted_buffer, unsigned char *client_public_key, unsigned char *server_secret_key)
{
    unsigned char nonce[crypto_box_NONCEBYTES];
    unsigned char *encrypted, *message;
    long esize;
    Content c;
    randombytes(nonce, sizeof(nonce));
    memset(nonce, 0, crypto_box_NONCEBYTES);
    c = encrypted_buffer;
    memcpy(nonce, c.bytes, crypto_box_NONCEBYTES);
    esize = c.size - crypto_box_NONCEBYTES + crypto_box_BOXZEROBYTES;
    encrypted = (unsigned char *)calloc(1, esize);
    if (encrypted == NULL)
        perror("Malloc failed!");
    memset(encrypted, 0, crypto_box_BOXZEROBYTES);
    memcpy(encrypted + crypto_box_BOXZEROBYTES,
        c.bytes + crypto_box_NONCEBYTES, c.size - crypto_box_NONCEBYTES);
    // Equivalently, esize - crypto_box_BOXZEROBYTES
    free(c.bytes);
    // Output
    message = (unsigned char *)calloc(esize, sizeof(unsigned char));
    if (message == NULL)
        perror("Calloc failed!");
    // Encrypt
    crypto_box_open(message, encrypted, esize,
        nonce, client_public_key, server_secret_key);
    free(encrypted);
    printf("Message = %.*s\n", (int)(esize - crypto_box_ZEROBYTES), &message[crypto_box_ZEROBYTES]);
    free(message);
}

Content 
encrypt(unsigned char *string, size_t ks, unsigned char *server_public_key, unsigned char *client_secret_key)
{
    Content encrypted_buffer;
    unsigned char nonce[crypto_box_NONCEBYTES];
    long psize;
    unsigned char *padded, *encrypted;
    Content c;
    randombytes(nonce, sizeof(nonce));
    c.bytes = (unsigned char *)calloc(sizeof(unsigned char), 16);//strdup(string);
    memcpy(c.bytes, string, 16);
    c.size = ks;
    psize = crypto_box_ZEROBYTES + c.size;
    padded = (unsigned char *)calloc(1, psize);
    if (padded == NULL)
        perror("Malloc failed!");
    memset(padded, 0, crypto_box_ZEROBYTES);
    memcpy(padded + crypto_box_ZEROBYTES, c.bytes, c.size);
    free(c.bytes);
    // Output
    encrypted = (unsigned char *)calloc(psize, sizeof(unsigned char));
    if (encrypted == NULL)
        perror("Calloc failed!");
    // Encrypt
    crypto_box(encrypted, padded, psize, nonce, server_public_key, client_secret_key);
    free(padded);
    encrypted_buffer.size = psize - crypto_box_BOXZEROBYTES + sizeof(nonce);

    encrypted_buffer.bytes = (unsigned char *)calloc(1, encrypted_buffer.size);
    memset(encrypted_buffer.bytes, 0, encrypted_buffer.size); 

    memcpy(encrypted_buffer.bytes, nonce, sizeof(nonce));
    memcpy(&encrypted_buffer.bytes[sizeof(nonce)], encrypted + crypto_box_BOXZEROBYTES,
            psize - crypto_box_BOXZEROBYTES);
    free(encrypted);
    /* decrypt */
    return encrypted_buffer;
}

#if 0
int
main(int argc, char *argv[])
{
    system("rm -f encrypted");
    Content encrypted_buffer;
    unsigned char server_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char server_secret_key[crypto_box_SECRETKEYBYTES];
    unsigned char client_public_key[crypto_box_PUBLICKEYBYTES];
    unsigned char client_secret_key[crypto_box_SECRETKEYBYTES];
    crypto_box_keypair(server_public_key, server_secret_key);
    crypto_box_keypair(client_public_key, client_secret_key);
    output_key("Server public:", server_public_key, crypto_box_PUBLICKEYBYTES);
    output_key("Server secret:", server_secret_key, crypto_box_SECRETKEYBYTES);
    output_key("Client public:", client_public_key, crypto_box_PUBLICKEYBYTES);
    output_key("Client secret:", client_secret_key, crypto_box_SECRETKEYBYTES);
    encrypted_buffer = encrypt("hahaXd", server_public_key, client_secret_key);
    decrypt(encrypted_buffer, client_public_key, server_secret_key);
    return 0;
}
#endif
