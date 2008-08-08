# $Id: Makefile,v 1.5 2008-08-08 11:20:19 roderick Exp $

install_dest 		= /usr/local/src/zavandor-inst
install_rsync_args      =

all_files		:= $(shell find -type f ! -name '*~' ! -name '*\#')

all: TAGS

TAGS: $(filter-out ./TAGS, $(all_files))
	etags $^

install: all
	rsync -ia \
		--delete-excluded \
		--cvs-exclude \
		--omit-dir-times \
	    $(install_rsync_args) . $(install_dest)

test-install: install_rsync_args_no = -n
test-install: install
