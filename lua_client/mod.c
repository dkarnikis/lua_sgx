#include <lua.h>
#include <lauxlib.h>


static int foo(lua_State* L)
{
  char *a = luaL_checkstring(L, 1);
  char *b = luaL_checkstring(L, 2);
  lua_pushstring(L, a);
  return 1;
}


static luaL_Reg const foolib[] = {
  { "foo", foo },
  { 0, 0 }
};


#ifndef FOO_API
#define FOO_API
#endif

FOO_API int luaopen_foo(lua_State* L)
{
  luaL_newlib(L, foolib);
  return 1;
}
