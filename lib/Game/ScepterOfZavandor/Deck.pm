# $Id: Deck.pm,v 1.7 2008-07-31 18:09:03 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Deck;

use base qw(Game::Util::Deck);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ENERGY_EST_/
    /^GEM_/
    @Gem
    @Gem_data
);
use Game::ScepterOfZavandor::Item::Energy ();

BEGIN {
    add_array_index 'DECK', 'GAME';
    add_array_index 'DECK', 'GTYPE';
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $game, $gtype) = @_;

    my $self = $class->SUPER::new;

    $self->[DECK_GAME ] = $game;
    $self->[DECK_GTYPE] = $gtype;

    $self->discard(
	map { Game::ScepterOfZavandor::Item::Energy::Card->new($self, $_) }
	    @{ $Gem_data[$gtype][GEM_DATA_CARD_LIST] });
    $self->shuffle;

    return $self;
}

make_ro_accessor (
    a_game     => DECK_GAME,
    a_gem_type => DECK_GTYPE,
);

sub draw {
    @_ || badinvo;
    my $self = shift;

    my @r = $self->SUPER::draw(@_);
    if (!defined $r[-1]) {
	# XXX find out what's supposed to happen
	xcroak "ran out of $Gem[$self->a_gem_type] cards";
    }

    return @r == 1 ? $r[0] : @r;
}

sub energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    my $gtype = $self->a_gem_type;

    my @ee;
    $ee[ENERGY_EST_MIN] = $Gem_data[$gtype][GEM_DATA_CARD_MIN];
    $ee[ENERGY_EST_AVG] = $Gem_data[$gtype][GEM_DATA_CARD_AVG];
    $ee[ENERGY_EST_MAX] = $Gem_data[$gtype][GEM_DATA_CARD_MAX];

    return @ee;
}

1
