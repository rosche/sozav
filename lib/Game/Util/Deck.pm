# $Id: Deck.pm,v 1.6 2012-09-21 12:34:53 roderick Exp $

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

sub all_deck_items {
    @_ == 1 || badinvo;
    my $self = shift;
    return $self->draw_deck_items, $self->discard_deck_items;
}

sub draw_deck_items {
    @_ == 1 || badinvo;
    my $self = shift;
    return @{ $self->[DECK_DRAW] };
}

sub discard_deck_items {
    @_ == 1 || badinvo;
    my $self = shift;
    return @{ $self->[DECK_DISCARD] };
}

sub shuffle {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->[DECK_DRAW] = [RS::Handy::shuffle
			    @{ $self->[DECK_DRAW] },
			    @{ $self->[DECK_DISCARD] }];
    $self->[DECK_DISCARD] = [];
}

sub maybe_shuffle {
    @_ == 1 || badinvo;
    my ($self) = @_;

    if (!@{ $self->[DECK_DRAW] } && $self->[DECK_AUTO_RESHUFFLE]) {
	$self->shuffle;
    }
}

sub draw {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;
    my $ct   = @_ ? shift : 1;

    my @r;
    for (1..$ct) {
    	$self->maybe_shuffle;
	push @r, shift @{ $self->[DECK_DRAW] };
    }

    return @r == 1 ? $r[0] : @r;
}

sub draw_first_matching_no_shuffle {
    @_ == 2 || badinvo;
    my ($self, $test_sub) = @_;

    for my $ix (0..$#{ $self->[DECK_DRAW] }) {
    	if ($test_sub->($self->[DECK_DRAW][$ix])) {
	    return splice @{ $self->[DECK_DRAW] }, $ix, 1;
	}
    }
    return undef;
}

sub discard {
    @_ >= 2 || badinvo;
    my ($self, @card) = @_;

    push @{ $self->[DECK_DISCARD] }, @card;
}

sub push {
    @_ >= 2 || badinvo;
    my ($self, @card) = @_;

    push @{ $self->[DECK_DRAW] }, @card;
}

1
