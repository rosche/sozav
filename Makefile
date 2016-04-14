# $Id: Makefile,v 1.8 2012-09-14 01:16:51 roderick Exp $

all:

install_dest 		= $(HOME)/src/sozav-inst
install_rsync_args      =

all_files		:= $(shell find -type f \
	    	    	    	! -name '*~' ! -name '*\#' ! -name '.\#*')

pm_file			:= $(shell find lib -name '*.pm' ! -name '.*')
pm_name			:= $(shell echo "$(pm_file)" | \
				sed 's,lib/,,g; s,\.pm,,g; s,/,-,g')
pm_test			:= $(patsubst %,t/0-load-%.t, \
				$(filter-out Game-ScepterOfZavandor-Test, \
					    $(pm_name)))

all: $(pm_test)
$(pm_test): create-load-test
	./$^ $@

all: TAGS
TAGS: $(pm_file)
	etags $^

.PHONY: test
test: all
	./run-tests t/*.t

install: all
	rsync -ia \
		--delete-excluded \
		--cvs-exclude \
		--omit-dir-times \
		--exclude cover_db \
	    $(install_rsync_args) . $(install_dest)

test-install: install_rsync_args = -n
test-install: install
