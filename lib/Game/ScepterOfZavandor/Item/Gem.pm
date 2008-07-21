# $Id: Gem.pm,v 1.2 2008-07-21 00:20:03 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Gem;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);

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
    my ($class, $gtype, $game) = @_;

    defined $Gem[$gtype] or die;;

    my $self = $class->SUPER::new(ITEM_TYPE_GEM);
    $self->[ITEM_GEM_TYPE]      = $gtype;
    $self->[ITEM_GEM_DECK]      = $game->a_gem_decks->[$gtype];
    $self->[ITEM_GEM_ACTIVE_VP] = $Gem_data[$gtype][GEM_DATA_VP];
    $self->[ITEM_GEM_ACTIVE]    = 0;

    return $self;
}

make_rw_accessor (
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

sub is_active {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->[ITEM_GEM_ACTIVE];
}

sub activate {
    @_ == 1 || badinvo;
    my $self = shift;

    return if $self->is_active;

    # XXX check for slots

    $self->[ITEM_GEM_ACTIVE] = 1;
    $self->a_vp($self->[ITEM_GEM_ACTIVE_VP])
}

sub produce_energy {
    @_ == 1 || badinvo;
    my $self = shift;

    # XXX
    return $self->is_active ? $self->[ITEM_GEM_DECK]->draw : ();
}

1
