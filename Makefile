# $Id: Makefile,v 1.2 2008-07-29 16:46:12 roderick Exp $

all_files := $(shell find -type f ! -name '*~' ! -name '*\#')

all: TAGS

TAGS: $(all_files)
	etags $^
