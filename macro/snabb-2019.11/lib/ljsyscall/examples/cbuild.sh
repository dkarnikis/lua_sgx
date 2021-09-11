#!/bin/sh

# bundle up all the Lua files. This will be more files than you can possibly need...

mkdir -p obj

cd include/luajit-2.0 && make && cd ../..

LIBDIR=include/luajit-2.0/src
INCDIR=include/luajit-2.0/src
JITDIR=include/luajit-2.0/src/jit

# example of how to build a C executable

[ ! -f syscall.lua ] && echo "This script is designed to be run from top level directory" && exit

rm -f ./obj/cbuild
rm -f ./obj/*.{o,a}

FILES=`find syscall.lua syscall -name '*.lua'`

for f in $FILES
do
  NAME=`echo ${f} | sed 's/\.lua//'`
  MODNAME=`echo ${NAME} | sed 's@/@.@g'`
  luajit -b -t o -n ${MODNAME} ${f} obj/${MODNAME}.o
done

FILES=`find $JITDIR -name '*.lua'`

for f in $FILES
do
  NAME=`echo ${f} | sed "s@$JITDIR@@g" | sed 's/\.lua//'`
  MODNAME=jit`echo ${NAME} | sed 's@/@.@g'`
  luajit -b -t o -n ${MODNAME} ${f} obj/${MODNAME}.o
done

FILES='test/test.lua test/linux.lua test/netbsd.lua test/rump.lua test/servetests.lua include/ffi-reflect/reflect.lua include/luaunit/luaunit.lua include/strict/strict.lua'

for f in $FILES
do
  NAME=`echo ${f} | sed 's/\.lua//'`
  MODNAME=`echo ${NAME} | sed 's@/@.@g'`
  luajit -b -t o -n ${MODNAME} ${f} obj/${MODNAME}.o
done

# small stub to create Lua state and call hello world
cc -c -fPIC -I${INCDIR} examples/cstub.c -o obj/cstub.o

ar cr obj/libtest.a obj/cstub.o obj/syscall*.o obj/jit*.o obj/test*.o obj/include*.o

#ld -o obj/cbuild --whole-archive obj/libhello.a --no-whole-archive ${LIBDIR}/libluajit.a -ldl -lm
cc -Wl,-E -o obj/cbuild obj/cstub.o ${LIBDIR}/libluajit.a obj/syscall*.o -ldl -lm

# for OSv - note this requires luajit .o files be built with -fPIC TODO patch and rebuild
cc -shared -fPIC -Wl,-E -o obj/cbuild.so obj/cstub.o ${LIBDIR}/libluajit.a obj/syscall*.o

#./obj/cbuild

