# $Id: Item.pm,v 1.4 2008-07-23 01:09:06 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload '""' => "as_string";

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

sub is_energy {
    @_ == 1 || badinvo;
    return $_[0]->isa(Game::ScepterOfZavandor::Item::Energy::);
}

sub is_gem {
    @_ == 1 || badinvo;
    return $_[0]->isa(Game::ScepterOfZavandor::Item::Gem::);
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

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    # I think gems and energy are the only things which can be discarded.
    # I don't now if this assumption has influenced any code, but I'm
    # testing it here so I'll know if it's wrong.

    $self->is_gem || $self->is_energy
	or xcroak "->use_up called on $self";

    return;
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
