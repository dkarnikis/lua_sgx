CC=gcc
CFLAGS=-fPIC -shared -Ofast -Wno-discarded-qualifiers -Wno-unused-result
LIBS=-lm
INCLUDES=includes
BIN=liblclient.so
SRC_DIR=src
OBJ_DIR=obj

ifeq ($(wrk), 1)
		# path to WRKJIT
        LIBS += -L ../../macro/wrk2/deps/luajit/src -lluajit  -D__LUA_JIT__
else ifeq ($(snabb), 1)
		LIBS += -L ../../macro/lsnabb/lib/luajit/src -lraptorjit -D__RAPTOR__JIT__
		INCLUDES += -I ../../macro/lsnabb/lib/luajit/src
else
		LIBS += -llua
endif

SRC_FILES := $(wildcard $(SRC_DIR)/*.c)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.c,$(OBJ_DIR)/%.o,$(SRC_FILES))

$(BIN): $(OBJ_FILES)
	$(CC) $(CFLAGS) $(LIBS) -o $@ $^

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) $(LIBS) -I $(INCLUDES) -c -o $@ $<

clean:
	rm -rf $(OBJ_FILES) $(BIN)

