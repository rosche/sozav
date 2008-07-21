# $Id: Item.pm,v 1.3 2008-07-21 02:35:02 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload '""' => "as_string";

use Game::Util  	qw($Debug add_array_indices debug make_rw_accessor);
use RS::Handy		qw(badinvo data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    @Item_type
);

BEGIN {
    add_array_indices 'ITEM', qw(TYPE VP HAND_LIMIT);
}

sub new {
    @_ == 2 || badinvo;
    my ($class, $itype) = @_;

    defined $itype && $itype >= 0 && $itype <= $#Item_type
	or die;

    my $self = bless [], $class;
    $self->a_item_type($itype);
    $self->a_vp(0);
    $self->a_hand_limit(0);

    return $self;
}

make_rw_accessor (
    a_item_type  => ITEM_TYPE,
    a_vp         => ITEM_VP,
    a_hand_limit => ITEM_HAND_LIMIT,
);


sub as_string_fields {
    @_ || badinvo;
    my $self = shift;

    my @r;
    push @r,
	    "vp=$self->[ITEM_VP]",
	    "hl=$self->[ITEM_HAND_LIMIT]",
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
    return $self->is_energy ? $self->a_value : 0;
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

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
