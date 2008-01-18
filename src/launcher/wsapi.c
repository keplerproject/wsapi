
/*
** Simple Lua interpreter.
** This program is used to run a Lua file embedded as a resource.
** It creates a Lua state, opens all its standard libraries, and run
** the Lua file in a protected environment just to redirect the error
** messages to stdout and stderr.
**
** $Id: wsapi.c,v 1.1 2008/01/18 19:25:21 mascarenhas Exp $
*/

#include <string.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <windows.h>
#include <io.h>
#include <fcntl.h>

/*
** Report error message.
** Assumes that the error message is on top of the stack.
*/
static int report (lua_State *L) {
	fprintf (stderr, "lua: fatal error: `%s'\n", lua_tostring (L, -1));
	fflush (stderr);
	printf ("Content-type: text/plain\n\nConfiguration fatal error: see error log!\n");
	printf ("%s", lua_tostring(L, -1));
	return 1;
}

static int runlua (lua_State *L, LPTSTR lua_string) {
	int err_func;

	lua_pushliteral(L, "debug");
	lua_rawget(L, LUA_GLOBALSINDEX);  /* get traceback function */
        lua_pushliteral(L, "traceback");
        lua_gettable(L, -2);
	err_func = lua_gettop (L);
	return (luaL_loadstring (L, lua_string)) ||
	  (lua_pcall (L, 0, 0, err_func));
}

/*
** MAIN
*/
int main (int argc, char *argv[]) {
	char name[ MAX_PATH ];
	DWORD dwLength;
	int size;
	TCHAR lua_string[10000];
	lua_State *L = lua_open();
	(void)argc; /* avoid "unused parameter" warning */
	size = LoadString(GetModuleHandle(NULL), 1, lua_string,
			  sizeof(lua_string)/sizeof(TCHAR));
	if(size) {
		luaL_openlibs(L);
		/*_setmode(_fileno(stdin), _O_BINARY);
		  _setmode(_fileno(stdout), _O_BINARY);*/
		if (runlua (L, lua_string)) {
			report (L);
			lua_close (L);
			return EXIT_FAILURE;
		}
	} else {
	  lua_close(L);
	  fprintf(stderr, "could not load Lua resource\n");
	  printf ("Content-type: text/plain\n\nConfiguration fatal error: see error log!\n");
	}
	lua_close (L);
	return EXIT_SUCCESS;
}
