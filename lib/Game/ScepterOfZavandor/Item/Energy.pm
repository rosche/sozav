# $Id: Energy.pm,v 1.2 2008-07-21 02:41:16 roderick Exp $

use strict;

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy;

use overload '<=>' => "spaceship";

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

#use Game::ScepterOfZavandor::Constant qw(
#);

BEGIN {
    add_array_index 'ITEM', $_ for map { "ENERGY_$_" } qw(VALUE);

    # XXX min, average, max possible values for this type of thing
    # (differs for cards), use to show min, average, max energy a
    # person has
    #
    # XXX or maybe store this in a central array indexed by type of
    # thing (1, 2, 10 dust, 4 gem cards types, 4 concntrated energy
    # types)
}

sub new {
    @_ == 4 || badinvo;
    my ($class, $itype, $value, $hand_limit) = @_;

    $value >= 1 or die;;

    my $self = $class->SUPER::new($itype);
    $self->a_value($value);
    $self->a_hand_limit($hand_limit);

    return $self;
}

make_rw_accessor (
    a_value => ITEM_ENERGY_VALUE,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
	"v=$self->[ITEM_ENERGY_VALUE]",
    	sprintf("hlr=%3.1f", $self->a_value / $self->a_hand_limit);
    return @r;
}

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b) = @_;

    # Prefer cards with a higher value:hand-limit ratio.

    return(($a->a_value/$a->a_hand_limit) <=> ($b->a_value/$b->a_hand_limit));
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Card;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(add_array_index debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "ENERGY_CARD_$_" } qw(DECK);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $deck, $value) = @_;

    my $self = $class->SUPER::new(ITEM_TYPE_CARD, $value, 1);

    $self->[ITEM_ENERGY_CARD_DECK] = $deck; # XXX circular reference

    return $self;
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->SUPER::use_up;
    $self->[ITEM_ENERGY_CARD_DECK]->discard($self);
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Dust;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^DUST_/
    /^ITEM_/
    @Dust_data
);

{

my %dust_to_hand_limit
    = map { $_->[DUST_DATA_VALUE] => $_->[DUST_DATA_HAND_LIMIT] } @Dust_data;

sub new {
    @_ == 2 || badinvo;
    my ($class, $value) = @_;

    my $hl = $dust_to_hand_limit{$value};
    defined $hl or die;

    return $class->SUPER::new(ITEM_TYPE_DUST, $value, $hl);
} }

sub make_dust {
    @_ == 2 || badinvo;
    my ($class, $tot_value) = @_;

    $tot_value > 0 or die;

    my @r;
    for my $v (map { $_->[DUST_DATA_VALUE] } @Dust_data) {
	while ($tot_value >= $v) {
	    push @r, $class->new($v);
	    $tot_value -= $v;
	}
    }
    return @r;
}

sub make_dust_from_opals {
    @_ == 2 || badinvo;
    my ($class, $opal_count) = @_;

    $opal_count > 0 or die;

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

    return $class->make_dust($tot_value);
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Concentrated;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    $Concentrated_hand_limit
    @Gem_data
);

sub new {
    @_ == 2 || badinvo;
    my ($class, $gtype) = @_;

    return $class->SUPER::new(ITEM_TYPE_CONCENTRATED,
				$Gem_data[$gtype][GEM_DATA_CONCENTRATED],
    	    	    	    	$Concentrated_hand_limit);
}

#------------------------------------------------------------------------------

1
