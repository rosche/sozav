# $Id: Item.pm,v 1.8 2008-07-29 18:07:22 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload (
    '""'  => "as_string",
    '<=>' => "spaceship",
);

use Game::Util  	qw($Debug add_array_indices debug
			    make_ro_accessor make_rw_accessor);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    @Item_type
);

BEGIN {
    add_array_indices 'ITEM', qw(
    	TYPE
	DATA
	PLAYER
	VP
	GEM_SLOTS
	HAND_COUNT
	HAND_LIMIT_MODIFIER
    );
}

sub new {
    (@_ >= 2 || @_ <= 4) || badinvo;
    my ($class, $itype, $player, $rdata) = @_;

    defined $itype && $itype >= 0 && $itype <= $#Item_type
	or xconfess;

    !defined $player
    	# XXX quoting on class name
	or eval { $player->isa("Game::ScepterOfZavandor::Player") }
	or xconfess;

    my $self = bless [], $class;
    $self->[ITEM_TYPE] = $itype;
    $self->a_player($player);
    $self->a_data($rdata);
    $self->a_vp(0);
    $self->a_hand_count(0);
    $self->a_hand_limit_modifier(0);
    $self->a_gem_slots(0);

    return $self;
}

make_ro_accessor (
    a_item_type           => ITEM_TYPE,
);

make_rw_accessor (
    # XXX maybe a ITEM_STATIC_VP, if that isn't set use a method (for
    # sentinels, gems)
    a_data                => ITEM_DATA,
    a_vp                  => ITEM_VP,
    a_hand_count          => ITEM_HAND_COUNT,
    a_hand_limit_modifier => ITEM_HAND_LIMIT_MODIFIER,
    a_gem_slots           => ITEM_GEM_SLOTS,
);

for (qw(Artifact Auctionable Energy Gem Knowledge Sentinel TurnOrder)) {
    my $pkg = __PACKAGE__ . "::$_";
    my $method = "is_" . lc $_;
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
    push @r,
	    "vp=$self->[ITEM_VP]",
	    "hl=$self->[ITEM_HAND_COUNT]",
    	if $Debug > 1;
    return @r;
}

sub as_string {
    @_ == 3 || badinvo;
    my $self = shift;

    return sprintf "%s(%s)",
	$Item_type[$self->[ITEM_TYPE]],
	join " ", $self->as_string_fields;
}

# - XXX name
# - XXX caller shouldn't have to test item type first because of more
#   specific spaceship operators

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b) = @_;

    return $a->[ITEM_TYPE] <=> $b->[ITEM_TYPE]
    	    or $b->[ITEM_VP] <=> $a->[ITEM_VP];
	    # XXX name?
}

sub allows_player_to_enchant_gem_type {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gtype = shift;

    return 0;
}

# XXX make a global item type, then use the same function for auctionables
# and gems?

sub discount_on_auc_type {
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

# Call this after removing an item from a person's inventory.  There's no
# default for it, but it's defined for any object which can be removed
# from a person's inventory.
#
#sub use_up {
#    @_ == 1 || badinvo;
#    my $self = shift;
#}

# This is overridden by sentinels.

sub vp {
    @_ == 1 || badinvo;
    my $self = shift;
    return $self->a_vp;
}

1
