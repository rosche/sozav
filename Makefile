# $Id: Makefile,v 1.7 2012-04-28 20:02:24 roderick Exp $

all:

install_dest 		= /usr/local/src/zavandor-inst
install_rsync_args      =

all_files		:= $(shell find -type f ! -name '*~' ! -name '*\#')

pm_file			:= $(shell find lib -name '*.pm')
pm_name			:= $(shell echo "$(pm_file)" | \
				sed 's,lib/,,g; s,\.pm,,g; s,/,-,g')
pm_test			:= $(patsubst %,t/0-load-%.t,$(pm_name))

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
