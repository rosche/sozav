use strict;

package Game::ScepterOfZavandor::Undo;

use Game::Util	qw(add_array_indices debug
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);
use Storable	qw(store);


#------------------------------------------------------------------------------

sub xxx {
    @_ == 2 || badinvo;
    store @_;
}

#------------------------------------------------------------------------------

1
