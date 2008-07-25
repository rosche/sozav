# $Id: Gem.pm,v 1.5 2008-07-25 17:36:23 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Gem;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    @Gem
    @Gem_data
);
use Game::ScepterOfZavandor::Player ();

BEGIN {
    add_array_index 'ITEM', $_ for map { "GEM_$_" }
	qw(TYPE PLAYER DECK ACTIVE_VP ACTIVE);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $gtype, $player) = @_;

    defined $Gem[$gtype] or xcroak;;
    $player->isa(Game::ScepterOfZavandor::Player::) or xcroak;

    my $self = $class->SUPER::new(ITEM_TYPE_GEM);
    $self->[ITEM_GEM_TYPE]      = $gtype;
    $self->[ITEM_GEM_PLAYER]    = $player;
    weaken $self->[ITEM_GEM_PLAYER];
    $self->[ITEM_GEM_DECK]      = $player->a_game->a_gem_decks->[$gtype];
    weaken $self->[ITEM_GEM_DECK];
    $self->[ITEM_GEM_ACTIVE_VP] = $Gem_data[$gtype][GEM_DATA_VP];
    $self->[ITEM_GEM_ACTIVE]    = 0;

    return $self;
}

make_ro_accessor (
    a_gem_type => ITEM_GEM_TYPE,
    a_player   => ITEM_GEM_PLAYER,
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
    my ($a, $b) = @_;

    return $a->[ITEM_GEM_TYPE] <=> $b->[ITEM_GEM_TYPE];
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
