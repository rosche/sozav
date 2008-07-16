# $Id: Item.pm,v 1.1 2008-07-16 23:40:41 roderick Exp $

package Game::ScepterOfZavandor::Item;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo data_dump dstr xcroak);

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT = qw(
	add_array_index_type
	add_array_index
    );
    @EXPORT_OK = qw(
    	%Index
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

1
