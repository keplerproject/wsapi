# $Id: Makefile,v 1.2 2007/12/11 18:42:08 mascarenhas Exp $

include config

all: fastcgi

cgi:

fastcgi: src/fastcgi/lfcgi.so

src/fastcgi/lfcgi.so: src/fastcgi/lfcgi.o src/fastcgi/lfcgi.h
	$(CC) $(CFLAGS) -shared -o src/fastcgi/lfcgi.so src/fastcgi/lfcgi.o -lfcgi 

install:
	mkdir -p $(LUA_DIR)/wsapi
	cp src/wsapi/*.lua $(LUA_DIR)/wsapi
	cp src/fastcgi/lfcgi.so $(LUA_LIBDIR)/

clean:
	rm src/fastcgi/lfcgi.o src/fastcgi/lfcgi.so
