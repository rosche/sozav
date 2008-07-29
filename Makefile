# $Id: Makefile,v 1.1 2008-07-29 16:46:02 roderick Exp $

all_files := $(shell find -type f ! -name '*~' ! -name '*#')

all: TAGS

TAGS: $(all_files)
	etags $^
