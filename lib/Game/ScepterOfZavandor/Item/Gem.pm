# $Id: Gem.pm,v 1.8 2008-07-31 00:52:13 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Gem;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    @Gem
    @Gem_data
);

BEGIN {
    add_array_index 'ITEM', $_ for map { "GEM_$_" }
	qw(TYPE DECK ACTIVE_VP ACTIVE);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $gtype) = @_;

    defined $Gem[$gtype] or xconfess;;

    my $self = $class->SUPER::new(ITEM_TYPE_GEM, $player, $Gem_data[$gtype]);
    $self->[ITEM_GEM_TYPE]      = $gtype;
    # XXX lose this, always go through links?
    $self->[ITEM_GEM_DECK]      = $player->a_game->a_gem_decks->[$gtype];
    weaken $self->[ITEM_GEM_DECK];
    # XXX lose this field, get it from data directly
    $self->[ITEM_GEM_ACTIVE_VP] = $self->data(GEM_DATA_VP);
    $self->[ITEM_GEM_ACTIVE]    = 0;

    return $self;
}

make_ro_accessor (
    a_gem_type => ITEM_GEM_TYPE,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
    	$Gem[$self->[ITEM_GEM_TYPE]],
	$self->is_active ? "active" : ();
    return @r;
}

sub spaceship {
    @_ == 3 || badinvo;
    my ($a, $b, $rev) = @_;

    ($a->a_item_type == $b->a_item_type)
	    ? $a->[ITEM_GEM_TYPE] <=> $b->[ITEM_GEM_TYPE]
	    : 0
    	or $a->SUPER::spaceship($b, $rev)
}

sub activate {
    @_ == 1 || badinvo;
    my $self = shift;

    return if $self->is_active;

    debug "activate $self";

    # XXX check for slots

    $self->[ITEM_GEM_ACTIVE] = 1;
    $self->a_vp($self->[ITEM_GEM_ACTIVE_VP])
}

sub deactivate {
    @_ == 1 || badinvo;
    my $self = shift;

    return if !$self->is_active;

    debug "deactivate $self";

    $self->[ITEM_GEM_ACTIVE] = 0;
    $self->a_vp(0);
}

sub is_active {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->[ITEM_GEM_ACTIVE];
}

sub energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->a_player->gem_value($self);
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->is_active ? $self->[ITEM_GEM_DECK]->draw : ();
}

sub produce_energy_estimate {
    @_ == 1 || badinvo;
    my $self = shift;

    # XXX handle opals
    $self->a_gem_type == GEM_OPAL
	and return;

    # XXX it might be nice if gems participating in concentrated energy
    # had their numbers adjusted appropriately

    return $self->is_active ? $self->[ITEM_GEM_DECK]->energy_estimate : ();
}

sub use_up {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->deactivate;
}

1

__END__

energy or gem
    buy artifact, gem
    change possible

energy
    hand limit
    change possible
