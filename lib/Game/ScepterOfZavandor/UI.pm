# $Id: UI.pm,v 1.2 2008-07-19 18:33:31 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI;

use Game::Util 	qw(add_array_indices debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

BEGIN {
    add_array_indices 'UI', qw(PLAYER);
}

sub new {
    @_ == 1 || badinvo;
    my ($class) = @_;

    my $self = bless [], $class;

    return $self;
}

make_rw_accessor (
    a_player => UI_PLAYER,
);

1
