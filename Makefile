# $Id: Makefile,v 1.1.1.1 2007/10/30 23:44:45 mascarenhas Exp $

include config

all: src/fastcgi/lfcgi.so

src/fastcgi/lfcgi.so: src/fastcgi/lfcgi.o src/fastcgi/lfcgi.h
	$(CC) $(CFLAGS) -shared -o src/fastcgi/lfcgi.so src/fastcgi/lfcgi.o -lfcgi 

install:
	mkdir -p $(LUA_DIR)/wsapi
	cp src/wsapi/*.lua $(LUA_DIR)/wsapi
	cp src/fastcgi/lfcgi.so $(LUA_LIBDIR)/

clean:
	rm src/fastcgi/lfcgi.o src/fastcgi/lfcgi.so
