#include <stdio.h>
#include "lprefix.h"
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

int lua_main(int argc, char **argv);
int main(int argc, char **argv) {
    printf("edw\n");
    lua_main(argc, argv);
}
