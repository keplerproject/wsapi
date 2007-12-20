# $Id: Makefile,v 1.4 2007/12/20 16:11:42 mascarenhas Exp $

include config

all: fastcgi

cgi:

config:
	touch config

fastcgi: src/fastcgi/lfcgi.so

src/fastcgi/lfcgi.so: src/fastcgi/lfcgi.o src/fastcgi/lfcgi.h
	$(CC) $(CFLAGS) -shared -o src/fastcgi/lfcgi.so src/fastcgi/lfcgi.o -lfcgi 

install:
	mkdir -p $(LUA_DIR)/wsapi
	cp src/wsapi/*.lua $(LUA_DIR)/wsapi

install-fcgi: install
	cp src/fastcgi/lfcgi.so $(LUA_LIBDIR)/

install-rocks: install
	mkdir -p $(PREFIX)/samples
	cp -r samples/* $(PREFIX)/samples
	mkdir -p $(PREFIX)/doc
	cp -r doc/* $(PREFIX)/doc

install-rocks-all: install-fcgi install-rocks

clean:
	rm src/fastcgi/lfcgi.o src/fastcgi/lfcgi.so
