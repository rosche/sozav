# $Id: Item.pm,v 1.2 2008-07-18 16:01:38 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item;

use overload '""' => "as_string";

use Game::Util  qw(add_array_indices debug make_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

BEGIN {
    add_array_indices 'ITEM', qw(VP HAND_LIMIT);
}

sub new {
    @_ == 1 || badinvo;
    my ($class) = @_;

    my $self = bless [], $class;
    $self->a_vp(0);
    $self->a_hand_limit(0);

    return $self;
}

make_accessor (
    a_vp => ITEM_VP,
    a_hand_limit => ITEM_HAND_LIMIT,
);

sub as_string {
    @_ == 3 || badinvo;
    my $self = shift;

    return "item(vp=$self->[ITEM_VP] hl=$self->[ITEM_HAND_LIMIT])";
}

sub is_gem {
    @_ == 1 || badinvo;
    return $_[0]->isa(Game::ScepterOfZavandor::Item::Gem::);
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
