# $Id: UI.pm,v 1.5 2008-07-31 18:09:03 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI;

use Game::Util 	qw(add_array_indices debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Scalar::Util qw(weaken);

BEGIN {
    add_array_indices 'UI', qw(PLAYER);
}

sub new {
    @_ == 1 || badinvo;
    my ($class) = @_;

    my $self = bless [], $class;

    return $self;
}

#make_rw_accessor (
#    a_player => UI_PLAYER,
#);

# XXX duplicate of Item->a_player, move to a util lib?
sub a_player {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;
    my $old = $self->[UI_PLAYER];
    if (@_) {
	$self->[UI_PLAYER] = shift;
	weaken $self->[UI_PLAYER];
    }
    return $old;
}

sub start_actions {
}

1
