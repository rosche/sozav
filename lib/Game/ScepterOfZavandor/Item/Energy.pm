use strict;

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util		qw(add_array_indices debug make_ro_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);

#use Game::ScepterOfZavandor::Constant qw(
#);

BEGIN {
    add_array_indices 'ITEM', map { "ENERGY_$_" } qw(VALUE);

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

    # This sorts items with higher value:hand-count ratio later.

    $b->is_energy
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

use Game::Util		qw(add_array_indices debug make_ro_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    @Gem
);

BEGIN {
    add_array_indices 'ITEM', map { "ENERGY_CARD_$_" } qw(DECK);
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

use Game::Util	qw(debug knapsack_0_1);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^DUST_/
    /^ITEM_/
);

{

# XXX need game object to validate dust amount
sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $value) = @_;

    my $hl;
    # XXX need game object to validate dust amount, this won't choke on
    # 1 dust even if the option isn't turned on
    for (@Game::ScepterOfZavandor::Constant::Dust_data,
	    $Game::ScepterOfZavandor::Constant::Dust_data_val_1) {
    	if ($_->[DUST_DATA_VALUE] == $value) {
	    $hl = $_->[DUST_DATA_HAND_COUNT];
	    last;
	}
    }
    defined $hl or xconfess dstr $value;

    return $class->SUPER::new($player, ITEM_TYPE_DUST, $value, $hl);
} }

#------------------------------------------------------------------------------

=begin comment

sub xxx_make_dust_with_hand_limit {
    @_ == 4 || badinvo;
    my ($class, $player, $tot_value, $max_hand_count) = @_;

    $tot_value > 0 or xconfess dstr $tot_value;

    my @dd = @{ $player->a_game->a_dust_data };

    my @r;
    my $tot_hand_count = 0;

    my $add_one_kind = sub {
    	my $rdust = shift;
	my $v     = $rdust->[DUST_DATA_VALUE];
	my $hc    = $rdust->[DUST_DATA_HAND_COUNT];
	while ($tot_value >= $v) {
	    if ($max_hand_count && $tot_hand_count + $hc > $max_hand_count) {
	    	return;
	    }
	    push @r, $class->new($player, $v);
	    $tot_value      -= $v;
	    $tot_hand_count += $hc;
	}
    };

    # Instead of doing a generalized solution based on @Dust, this
    # hardcodes knowledge about the dust.

#    $add_one_kind->(shift @dd);
#
#    if ($tot_value % 2 == 0
#	    && (!$max_hand_count
#		    || $tot_hand_count + $tot_value/2 <= $max_hand_count)) {
#	$add_one_kind->(grep { $_->[DUST_DATA_VALUE] == 2 } @dd);
#    }


    $player->a_game->dust_data_loop(sub { $add_one_kind->($_) });

#    while ($tot_value > 0
#	    # XXX 10 (count 3) -> 5 2 2 2 (count 5), needs 2 extra hc
#	    && (!$max_hand_count || $tot_hand_count < $max_hand_count)) {
#    	for (reverse 0 .. $#r) {
#	    my $this_v  = $r[$_]->energy;
#	    my $this_hc = $r[$_]->hand_count;
#	    if ($this_v % 2) {
#		# most trailing odd dust, split it up
#		$tot_value -= $this_v;
#		$hc        -= $this_hc;


    # XXX info if you lost dust

    return @r;
}

sub xxx_make_dust {
    @_ == 3 || badinvo;
    my $class = shift;
    return $class->make_dust_with_hand_limit(@_, 0);
}

=end

=cut

#------------------------------------------------------------------------------

sub make_dust {
    @_ == 3 || badinvo;
    my ($class, $player, $tot_value, $max_hand_count) = @_;

    $tot_value > 0 or xconfess dstr $tot_value;

    # XXX this can cheat you if there's no 1 dust:  6 energy -> 5 dust
    # chit, could be 2+2+2 chits

    # XXX perhaps just special-case ($t % 10) == 6 and ($t % 10) == 8
    # instead of doing a full knapsack thing

    my @r;
    my $tot_hand_count = 0;
    $player->a_game->dust_data_loop(sub {
    	my $v  = $_->[DUST_DATA_VALUE];
    	my $hc = $_->[DUST_DATA_HAND_COUNT];
	while ($tot_value >= $v) {
	    if ($max_hand_count && $tot_hand_count + $hc > $max_hand_count) {
		last;
	    }
	    push @r, $class->new($player, $v);
	    $tot_value -= $v;
	    $tot_hand_count += $hc;
	}
    });

    # XXX info if you lost dust

    return @r;
}

sub make_dust_with_hand_limit {
    @_ == 4 || badinvo;
    my ($class, $player, $tot_value, $max_hand_count) = @_;

    $tot_value > 0 or xconfess dstr $tot_value;

    # XXX this has got to be completely wrong, doesn't it maximize the
    # energy you can get for the hand count, ignoring the $tot_value

    my @dummy = ();
    #print "tot_value=$tot_value dummy=";
    $player->a_game->dust_data_loop(sub {
    	my $hc = $_->[DUST_DATA_HAND_COUNT];
    	my $v  = $_->[DUST_DATA_VALUE];
	for (1 .. $tot_value / $v) {
	    #print " $v";
	    #push @dummy, [$v, $v/$hc];
	    push @dummy, [$hc, $v];
	}
    });
    #print "\n";
    #@dummy or xconfess; # XXX what about 1?

    # XXX this isn't trying to minimize hand limit?
    my ($got_cost, $got_value, @want_dummy)
	= knapsack_0_1 \@dummy, sub { @{ +shift } }, $max_hand_count,
    	    	    	sub { $_[0] > $_[1] || $_[2] + $_[3] > $tot_value };

    my @r;
    for (@want_dummy) {
    	my ($hc, $v) = @$_;
	push @r, $class->new($player, $v);
    }

    # XXX info if you lost dust

    return @r;
}

sub make_dust_from_opals {
    @_ == 3 || badinvo;
    my ($class, $player, $opal_count) = @_;

    return $class->make_dust($player,
			      $class->opal_count_to_energy_value($opal_count));
}

sub opal_count_to_energy_value {
    @_ == 2 || badinvo;
    my ($class, $opal_count) = @_;

    $opal_count > 0 or xconfess dstr $opal_count;

    my $tot_value = 0;
    for (@Game::ScepterOfZavandor::Constant::Dust_data) {
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
