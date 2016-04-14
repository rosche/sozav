use strict;

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util		qw(add_array_indices debug make_ro_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);

BEGIN {
    add_array_indices 'ITEM', map { "ENERGY_$_" } qw(VALUE);
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
    /^OPT_/
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

sub as_string_fields_public_info {
    @_ || badinvo;
    my $self = shift;

    my @r = $self->SUPER::as_string_fields_public_info(@_);
    if (!$self->a_game->option(OPT_PUBLIC_MONEY)) {
	# not a pretty hack
	for (@r) {
	    s/^v=.*/v= ?/s;
	    s/^hcr=.*//s;
	}
    }
    return @r;
}

sub energy_public {
    @_ == 1 || badinvo;
    my $self = shift;

    if ($self->a_game->option(OPT_PUBLIC_MONEY)) {
	return $self->SUPER::energy_public($self);
    }

    return $self->a_deck->energy_estimate;
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->a_deck->discard($self);
}

#------------------------------------------------------------------------------

package Game::ScepterOfZavandor::Item::Energy::Dust;

use base qw(Game::ScepterOfZavandor::Item::Energy);

use Game::Util	qw(debug knapsack_0_1);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^DUST_/
    /^ITEM_/
    /^OPT_/
);

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $value) = @_;

    my $rdd = $player->a_game->a_dust_data_hash->{$value}
        or xconfess dstr $value;
    my $hl = $rdd->[DUST_DATA_HAND_COUNT];

    return $class->SUPER::new($player, ITEM_TYPE_DUST, $value, $hl);
}

#------------------------------------------------------------------------------

sub make_dust_with_hand_limit {
    @_ == 4 || badinvo;
    my ($class, $player, $tot_value, $max_hand_count) = @_;

    $tot_value > 0       or xconfess dstr $tot_value;
    $max_hand_count >= 0 or xconfess dstr $max_hand_count;

    my $rdd_hash        = $player->a_game->a_dust_data_hash;
    my $remaining_value = $tot_value;
    my $used_hand_count = 0;
    my @r;

    my $add_one = sub {
	my $rdust = shift;
	my $v     = $rdust->[DUST_DATA_VALUE];
	my $hc    = $rdust->[DUST_DATA_HAND_COUNT];
        if ($remaining_value < $v
            || ($max_hand_count && $used_hand_count + $hc > $max_hand_count)) {
            return 0;
        }
        push @r, $class->new($player, $v);
        $remaining_value -= $v;
        $used_hand_count += $hc;
        return 1;
    };

    my $add_one_kind = sub {
	my $rdust = shift;
        while ($add_one->($rdust)) {
            # empty loop
        }
    };

    my $add = sub {
        $add_one->($rdd_hash->{+shift});
    };

    if ($player->a_game->option(OPT_1_DUST)) {
        for (@{ $player->a_game->a_dust_data }) {
            $add_one_kind->($_)
        }
        # XXX info if you lost dust
        return @r;
    }

    # There's no 1 dust so it's trickier.  The presence of
    # $max_hand_count means this doesn't map well to a knapsack problem.
    #
    # Instead of doing a generalized solution based on @Dust, this
    # hardcodes knowledge about the dust.

    while ($remaining_value > 13) {
        $add->(10)
            or last;
    }

    my $remaining_hand_count = $max_hand_count
                                    ? $max_hand_count - $used_hand_count
                                    : 23;
    if ($remaining_value >= 13 && $remaining_hand_count >= 6) {
        $add->(5);
        $add->(2);
        $add->(2);
        $add->(2);
        $add->(2);
    }
    elsif ($remaining_value >= 12 && $remaining_hand_count >= 4) {
        $add->(10);
        $add->(2);
    }
    elsif ($remaining_value >= 11 && $remaining_hand_count >= 5) {
        $add->(5);
        $add->(2);
        $add->(2);
        $add->(2);
    }
    elsif ($remaining_value >= 10 && $remaining_hand_count >= 3) {
        $add->(10);
    }
    elsif ($remaining_value >= 9 && $remaining_hand_count >= 4) {
        $add->(5);
        $add->(2);
        $add->(2);
    }
    elsif ($remaining_value >= 8 && $remaining_hand_count >= 4) {
        $add->(2);
        $add->(2);
        $add->(2);
        $add->(2);
    }
    elsif ($remaining_value >= 7 && $remaining_hand_count >= 3) {
        $add->(5);
        $add->(2);
    }
    elsif ($remaining_value >= 6 && $remaining_hand_count >= 3) {
        $add->(2);
        $add->(2);
        $add->(2);
    }
    elsif ($remaining_value >= 5 && $remaining_hand_count >= 2) {
        $add->(5);
    }
    elsif ($remaining_value >= 4 && $remaining_hand_count >= 2) {
        $add->(2);
        $add->(2);
    }
    # 3 impossible
    elsif ($remaining_value >= 2 && $remaining_hand_count >= 1) {
        $add->(2);
    }
    # 1 impossible

    # XXX info if you lost dust

    return @r;
}

#------------------------------------------------------------------------------

sub make_dust {
    @_ == 3 || badinvo;
    my ($class, $player, $tot_value) = @_;

    return $class->make_dust_with_hand_limit($player, $tot_value, 0);
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
#	$Gem[$self->a_deck->a_gem_type];
#    return @r;
#}

#------------------------------------------------------------------------------

1
