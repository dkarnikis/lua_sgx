#include <stdio.h>
#include <time.h>
#include <stdlib.h> 

int
main(int argc, char **argv)
{
    FILE *f;
    int i, j;
    if (argc == 1) {
        printf("Usage: ./rand bytes_to_gen output\n");
        return -1;
    }
    f = fopen(argv[2], "w");

    srand(time(0));
    char *p = malloc(atoi(argv[1]));
    j = 0;
    for (i = 0; i < atoi(argv[1]); i++) {
#if 1
        if (j == 511) {
            p[i] = '\n';
            j = -1;
        } else
#endif
            p[i] = rand();
        j++;
    }
    fwrite(p, sizeof(char), atoi(argv[1]), f);
    fclose(f);
}
