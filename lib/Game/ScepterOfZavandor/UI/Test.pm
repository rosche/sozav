# $Id: Test.pm,v 1.2 2012-04-28 20:02:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Test;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util	qw(add_array_indices debug make_rw_accessor);
use RS::Handy	qw(xdie);

BEGIN {
    add_array_indices 'UI', map { "TEST_$_" } qw(WANT_CHAR);
}

make_rw_accessor (
   a_want_char => UI_TEST_WANT_CHAR,
);

sub choose_character {
    my $self = shift;
    my @c = @_;
    return $self->a_want_char;
}

sub in {
    return;
}

sub info {
}

sub out {
    my $self = shift;
    print @_
	or xdie "error writing to stdout:";
}

sub out_error {
    my $self = shift;
    $self->out("ERROR: ", @_);
}

sub out_notice {
    my $self = shift;
    $self->out("Notice: ", @_);
}

1