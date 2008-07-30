# $Id: Makefile,v 1.3 2008-07-30 17:03:09 roderick Exp $

all_files := $(shell find -type f ! -name '*~' ! -name '*\#')

all: TAGS

TAGS: $(filter-out ./TAGS, $(all_files))
	etags $^
