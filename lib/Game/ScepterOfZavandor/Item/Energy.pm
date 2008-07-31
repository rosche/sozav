# $Id: Energy.pm,v 1.9 2008-07-31 18:09:04 roderick Exp $

use strict;

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util		qw(add_array_index debug make_ro_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);

#use Game::ScepterOfZavandor::Constant qw(
#);

BEGIN {
    add_array_index 'ITEM', $_ for map { "ENERGY_$_" } qw(VALUE);

    # XXX min, average, max possible values for this type of thing
    # (differs for cards), use to show min, average, max energy a
    # person has
    #
    # XXX or maybe store this in a central array indexed by type of
    # thing (1, 2, 5, 10 dust, 4 gem cards types, 4 concntrated energy
    # types)
}

sub new {
    @_ == 5 || badinvo;
    my ($class, $player_or_game, $itype, $value, $hand_count) = @_;

    $value >= 1 or xconfess dstr $value;

    my $self = $class->SUPER::new($player_or_game, $itype);
    $self->[ITEM_ENERGY_VALUE] = $value;
    $self->a_hand_count($hand_count);

    return $self;
}

make_ro_accessor (
    a_value => ITEM_ENERGY_VALUE,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
	sprintf("v=%2d", $self->a_value),
	sprintf("hc=%1d", $self->a_hand_count),
    	sprintf("hcr=%3.1f", $self->a_value / $self->a_hand_count);
    return @r;
}

sub energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->a_value;
}

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b, $rev) = @_;

    # Prefer cards with a higher value:hand-count ratio.

    ($a->a_item_type == $b->a_item_type)
	    ? ($a->a_value/$a->a_hand_count) <=> ($b->a_value/$b->a_hand_count)
	    : 0
    	or $a->SUPER::spaceship($b, $rev)
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;
    # nothing to do for most types of energy
}


#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Card;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util		qw(add_array_index debug make_ro_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    @Gem
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "ENERGY_CARD_$_" } qw(DECK);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $deck, $value) = @_;

    my $self = $class->SUPER::new($deck->a_game, ITEM_TYPE_CARD, $value, 1);

    $self->[ITEM_ENERGY_CARD_DECK] = $deck;
    weaken $self->[ITEM_ENERGY_CARD_DECK];

    return $self;
}

make_ro_accessor (
    a_deck => ITEM_ENERGY_CARD_DECK,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
    	$Gem[$self->a_deck->a_gem_type];
    return @r;
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->[ITEM_ENERGY_CARD_DECK]->discard($self);
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Dust;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(debug);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^DUST_/
    /^ITEM_/
    @Dust_data
);

{

my %dust_to_hand_count;

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $value) = @_;

    if (!%dust_to_hand_count) {
	# wait until run time as options can change it
	%dust_to_hand_count
	    = map { $_->[DUST_DATA_VALUE] => $_->[DUST_DATA_HAND_COUNT] }
		@Dust_data;
    }

    my $hl = $dust_to_hand_count{$value};
    defined $hl or xconfess dstr $value;

    return $class->SUPER::new($player, ITEM_TYPE_DUST, $value, $hl);
} }

sub make_dust {
    @_ == 3 || badinvo;
    my ($class, $player, $tot_value) = @_;

    $tot_value > 0 or xconfess dstr $tot_value;

    # XXX this can cheat you if there's no 1 dust:  6 energy -> 5 dust
    # chit, could be 2+2+2 chits

    my @r;
    for my $v (map { $_->[DUST_DATA_VALUE] } @Dust_data) {
	while ($tot_value >= $v) {
	    push @r, $class->new($player, $v);
	    $tot_value -= $v;
	}
    }
    # XXX info if you lost 1 dust
    return @r;
}

sub make_dust_from_opals {
    @_ == 3 || badinvo;
    my ($class, $player, $opal_count) = @_;

    return $class->make_dust($player, $class->opal_count_to_energy_value($opal_count));
}

sub opal_count_to_energy_value {
    @_ == 2 || badinvo;
    my ($class, $opal_count) = @_;

    $opal_count > 0 or xconfess dstr $opal_count;

    my $tot_value = 0;
    for (@Dust_data) {
    	my $val = $_->[DUST_DATA_VALUE];
	my $ct  = $_->[DUST_DATA_OPAL_COUNT];
	next unless $ct;
	while ($opal_count >= $ct) {
	    $tot_value += $val;
	    $opal_count -= $ct;
	}
    }

    return $tot_value;
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Concentrated;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(debug);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    $Concentrated_hand_count
    @Gem_data
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $gtype) = @_;

    return $class->SUPER::new($player,
				ITEM_TYPE_CONCENTRATED,
				$Gem_data[$gtype][GEM_DATA_CONCENTRATED],
    	    	    	    	$Concentrated_hand_count);
}

# XXX include gem type
#sub as_string_fields {
#    @_ || badinvo;
#    my $self = shift;
#    my @r = $self->SUPER::as_string_fields(@_);
#    push @r,
#    	$Gem[$self->a_deck->a_gem_type];
#    return @r;
#}

#------------------------------------------------------------------------------

1
