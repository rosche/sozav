# $Id: Deck.pm,v 1.2 2008-07-18 14:27:47 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Deck;

use base qw(Game::Util::Deck);

use Game::Util	qw(add_array_index debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    @Gem
    @Gem_data
);
use Game::ScepterOfZavandor::Item::Energy ();

BEGIN {
    add_array_index 'DECK', qw(GTYPE);
}

sub new {
    @_ == 2 || badinvo;
    my ($class, $gtype) = @_;

    my $self = $class->SUPER::new;

    $self->[DECK_GTYPE]   = $gtype;

    $self->discard(
	map { Game::ScepterOfZavandor::Item::Energy::Card->new($self, $_) }
	    @{ $Gem_data[$gtype][GEM_DATA_CARD_LIST] });
    $self->shuffle;

    return $self;
}

sub draw {
    my $self = shift;

    my @r = $self->SUPER::draw(@_);
    if (!defined $r[-1]) {
	xcroak "ran out of $Gem[$self->[DECK_GTYPE]] cards";
    }

    return @r == 1 ? $r[0] : @r;
}

1
