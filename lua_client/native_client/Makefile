CC=gcc
CFLAGS=-fPIC -shared -Ofast -Wno-discarded-qualifiers -Wno-unused-result
LIBS=-lm -llua
INCLUDES=includes
BIN=liblclient.so
SRC_DIR=src
OBJ_DIR=obj
SRC_FILES := $(wildcard $(SRC_DIR)/*.c)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRC_FILES))

$(BIN): $(OBJ_FILES)
	   $(CC) $(CFLAGS) $(LIBS) -o $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	   $(CC) $(CFLAGS) $(LIBS) -I $(INCLUDES) -c -o $@ $<


clean:
	rm -rf $(OBJ_FILES) $(BIN)

