# $Id: Makefile,v 1.4 2008-08-07 11:01:04 roderick Exp $

install_dest 		= /usr/local/src/zavandor-inst
install_rsync_args      =

all_files		:= $(shell find -type f ! -name '*~' ! -name '*\#')

all: TAGS

TAGS: $(filter-out ./TAGS, $(all_files))
	etags $^

install: all
	rsync -ia --delete-excluded -C $(install_rsync_args) . $(install_dest)

test-install: install_rsync_args_no = -n
test-install: install
