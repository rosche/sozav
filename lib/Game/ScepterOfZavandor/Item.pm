# $Id: Item.pm,v 1.17 2012-09-14 01:16:54 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload (
    '""'  => "as_string",
    '<=>' => "spaceship",
);

use Game::Util  	qw($Debug add_array_indices debug eval_block
			    make_ro_accessor make_rw_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(refaddr weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ENERGY_EST_/
    /^ITEM_/
    @Item_type
);

BEGIN {
    add_array_indices 'ITEM', qw(
	GAME
	PLAYER
    	TYPE
	DATA
	STATIC_VP
	GEM_SLOTS
	HAND_COUNT
	HAND_LIMIT_MODIFIER
    );
}

sub new {
    (@_ >= 3 || @_ <= 4) || badinvo;
    my ($class, $player_or_game, $itype, $rdata) = @_;

    defined $itype && $itype >= 0 && $itype <= $#Item_type
	or xconfess;

    my ($game, $player);
    if (eval_block { $player_or_game->isa("Game::ScepterOfZavandor::Game") }) {
	$game   = $player_or_game;
	$player = undef;
    }
    # XXX required quoting
    elsif (eval_block { $player_or_game->isa("Game::ScepterOfZavandor::Player") }) {
	$player = $player_or_game;
	$game   = $player->a_game;
    }
    else {
	xconfess dstr $player_or_game;
    }

    my $self = bless [], $class;
    $self->[ITEM_GAME] = $game;
    weaken $self->[ITEM_GAME];
    $self->a_player($player);
    $self->[ITEM_TYPE] = $itype;
    $self->a_data($rdata);
    $self->a_static_vp(0);
    $self->a_hand_count(0);
    $self->a_hand_limit_modifier(0);
    $self->a_gem_slots(0);

    return $self;
}

make_ro_accessor (
    a_game                => ITEM_GAME,
    a_item_type           => ITEM_TYPE,
);

make_rw_accessor (
    a_data                => ITEM_DATA,
    a_static_vp           => ITEM_STATIC_VP,
    a_hand_count          => ITEM_HAND_COUNT,
    a_hand_limit_modifier => ITEM_HAND_LIMIT_MODIFIER,
    a_gem_slots           => ITEM_GEM_SLOTS,
);

for (qw(Artifact Auctionable
	Energy Energy::Card Energy::Dust Energy::Concentrated
	Gem Knowledge Sentinel TurnOrder)) {
    my $pkg = __PACKAGE__ . "::$_";
    my $method = "is_" . lc $_;
    $method =~ s/::/_/g;
    my $sub = sub {
	@_ == 1 || badinvo;
	return $_[0]->isa($pkg);
    };
    no strict 'refs';
    *$method = $sub;
}

sub a_player {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;

    my $old = $self->[ITEM_PLAYER];
    if (@_) {
	my $new = shift;
	$self->[ITEM_PLAYER] = $new;
	if ($new) {
	    weaken $self->[ITEM_PLAYER];
	}
    }
    return $old;
}

sub data_ix {
    return ITEM_DATA;
}

sub data {
    @_ >= 2 || badinvo;
    my $self = shift;
    my @ix   = @_;

    my $rd = $self->[ITEM_DATA]
    	or xconfess "no data list for $self";

    my @r;
    for my $ix (@ix) {
	$ix >= 0 && $ix <= $#{ $rd } || xconfess dstr $ix;
	push @r, $rd->[$ix];
    }

    return @r == 1 ? $r[0] : @r;
}

# XXX somethign like this but generic
#for my $i (0..$#Auctionable_data_field) {
#    no strict 'refs';
#    *{ "get_data_" . lc $Auctionable_data_field[$i] } = sub {
#	@_ == 1 || badinvo;
#	return $_[0]->data($i);
#    }
#}

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;

    my @r;

    my $vp = $self->vp;
    if ($vp) {
	push @r, "vp=$vp";
    }

    push @r,
	    "hl=$self->[ITEM_HAND_COUNT]",
    	if $Debug > 1;

    # XXX inaccurate with concentrated energy, opals
    if (1) {
	my @ee = $self->produce_energy_estimate;
	if (@ee) {
	    push @r, "energy=" . join "/", @ee;
	}
    }

    return @r;
}

sub as_string {
    @_ == 3 || badinvo;
    my $self = shift;

    return sprintf "%s(%s)",
	$Item_type[$self->[ITEM_TYPE]],
	join " ", $self->as_string_fields;
}

sub as_string_as_is {
    @_ == 3 || badinvo;
    my $self = shift;

    return join " ", $self->as_string_fields;
}

# - XXX caller shouldn't have to test item type first because of more
#   specific spaceship operators (don't know what this means)

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b) = @_;

    0
	or $a->[ITEM_TYPE] <=> $b->[ITEM_TYPE]
	or $b->vp          <=> $a->vp
	# XXX compare name?
	or refaddr($a)     <=> refaddr($b)
}

sub allows_player_to_buy_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    return 0;
}

# XXX make a global item type, then use the same function for auctionables
# and gems?

sub cost_mod_on_auc_type {
    return 0;
}

sub energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return 0;
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;
    return;
}

sub produce_energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;
    return;
}

sub produces_energy_of_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;
    return 0;
}

# Call this after removing an item from a person's inventory.  There's no
# default for it, but it's defined for any object which can be removed
# from a person's inventory.
#
#sub use_up {
#    @_ == 1 || badinvo;
#    my $self = shift;
#}

sub vp {
    @_ == 1 || badinvo;
    my $self = shift;
    return $self->a_static_vp + $self->vp_extra;
}

sub vp_extra {
    return 0;
}

1
