# $Id: Item.pm,v 1.6 2008-07-25 17:39:35 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload (
    '""'  => "as_string",
    '<=>' => "spaceship",
);

use Game::Util  	qw($Debug add_array_indices debug
			    make_ro_accessor make_rw_accessor);
use RS::Handy		qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    @Item_type
);

BEGIN {
    add_array_indices 'ITEM', qw(
    	TYPE
	VP
	GEM_SLOTS
	HAND_COUNT
	HAND_LIMIT_MODIFIER
    );
}

sub new {
    @_ == 2 || badinvo;
    my ($class, $itype) = @_;

    defined $itype && $itype >= 0 && $itype <= $#Item_type
	or die;

    my $self = bless [], $class;
    $self->[ITEM_TYPE] = $itype;
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
    a_vp                  => ITEM_VP,
    # XXX pass these to ->new and make them read only?
    a_hand_count          => ITEM_HAND_COUNT,
    a_hand_limit_modifier => ITEM_HAND_LIMIT_MODIFIER,
    a_gem_slots           => ITEM_GEM_SLOTS,
);

for (qw(Artifact Auctionable Energy Gem Sentinel)) {
    my $pkg = __PACKAGE__ . "::$_";
    my $method = "is_" . lc $_;
    my $sub = sub {
	@_ == 1 || badinvo;
	return $_[0]->isa($pkg);
    };
    no strict 'refs';
    *$method = $sub;
}

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

sub discount_on {
    @_ == 2 || badinvo;
    my $self = shift;
    # XXX sentinel
    my $auc_type = shift;

    # XXX
    #return $_[0]->isa(Game::ScepterOfZavandor::Item::Artifact::);
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

__END__

- item objects

    - item
	- VP

    - item::energy (card or chit)
	- value
	- hand limit count

    - item::knowledge

    - item::gem
    	- active/inactive?
	- limit (5 for ruby)

    - item::auctionable

    - item::auctionable::artifact

    - item::auctionable::sentinel
