# $Id: Auctionable.pm,v 1.1 2008-07-24 13:46:54 roderick Exp $

use strict;

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Auctionable;

use base qw(Game::ScepterOfZavandor::Item);

use Carp	qw(confess);
use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr);

BEGIN {
    add_array_index 'ITEM', $_ for map { "AUC_$_" } qw(TYPE MIN_BID);
}

sub new {
    @_ == 4 || badinvo;
    my ($class, $auc_type, $min_bid) = @_;

    # XXX validate $auc_type
    $min_bid > 0
	or confess "min_bid ", dstr $min_bid;

    my $self = $class->SUPER::new($itype);
    $self->[ITEM_AUC_TYPE]    = $auc_type;
    $self->[ITEM_AUC_MIN_BID] = $min_bid;

    return $self;
}

make_ro_accessor (
    a_auc_type => ITEM_AUC_TYPE,
    a_min_bid  => ITEM_AUC_MIN_BID,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
    	# XXX name
	sprintf("min=%3d", $self->a_min_bid);
    return @r;
}

sub energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->a_value;
}

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b) = @_;

    # Prefer cards with a higher value:hand-count ratio.

    return(($a->a_value/$a->a_hand_count) <=> ($b->a_value/$b->a_hand_count));
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;
    # nothing to do for most types of energy
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

my %dust_to_hand_count
    = map { $_->[DUST_DATA_VALUE] => $_->[DUST_DATA_HAND_COUNT] } @Dust_data;

sub new {
    @_ == 2 || badinvo;
    my ($class, $value) = @_;

    my $hl = $dust_to_hand_count{$value};
    defined $hl or die dstr $value;

    return $class->SUPER::new(ITEM_TYPE_DUST, $value, $hl);
} }

sub make_dust {
    @_ == 2 || badinvo;
    my ($class, $tot_value) = @_;

    $tot_value > 0 or die dstr $tot_value;

    # XXX this can cheat you if there's no 1 dust:  6 energy -> 5 dust
    # chit, could be 2+2+2 chits

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

    $opal_count > 0 or die dstr $opal_count;

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
    $Concentrated_hand_count
    @Gem_data
);

sub new {
    @_ == 2 || badinvo;
    my ($class, $gtype) = @_;

    return $class->SUPER::new(ITEM_TYPE_CONCENTRATED,
				$Gem_data[$gtype][GEM_DATA_CONCENTRATED],
    	    	    	    	$Concentrated_hand_count);
}

#------------------------------------------------------------------------------

1
