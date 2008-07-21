# $Id: Deck.pm,v 1.3 2008-07-21 17:39:52 roderick Exp $

package Game::Util::Deck;

use strict;

use Game::Util	qw(add_array_indices debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

BEGIN {
    add_array_indices 'DECK', qw(DRAW DISCARD AUTO_RESHUFFLE);
}

sub new {
    @_ || badinvo;
    my ($class, @card) = @_;

    my $self = bless [], $class;
    $self->[DECK_DRAW]    = [];
    $self->[DECK_DISCARD] = [];
    $self->a_auto_reshuffle(1);

    if (@card) {
	$self->discard(@card);
	$self->shuffle;
    }

    return $self;
}

make_rw_accessor a_auto_reshuffle => DECK_AUTO_RESHUFFLE;

sub shuffle {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->[DECK_DRAW] = [RS::Handy::shuffle
			    @{ $self->[DECK_DRAW] },
			    @{ $self->[DECK_DISCARD] }];
    $self->[DECK_DISCARD] = [];
}

sub draw {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;
    my $ct   = @_ ? shift : 1;

    my @r;
    for (1..$ct) {
	if (!@{ $self->[DECK_DRAW] } && $self->[DECK_AUTO_RESHUFFLE]) {
	    $self->shuffle;
	}
	push @r, shift @{ $self->[DECK_DRAW] };
    }

    return @r == 1 ? $r[0] : @r;
}

sub discard {
    @_ >= 2 || badinvo;
    my ($self, @card) = @_;

    push @{ $self->[DECK_DISCARD] }, @card;
}

1
