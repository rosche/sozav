use strict;

package Game::ScepterOfZavandor::Item::Gem;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw(add_array_indices debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant qw(
    /^GEM_/
    /^ITEM_/
    /^NOTE_/
    /^OPT_/
    @Gem
    @Gem_data
);

BEGIN {
    add_array_indices 'ITEM', map { "GEM_$_" }
	qw(TYPE DECK ACTIVE_VP ACTIVE);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $player, $gtype) = @_;

    defined $Gem[$gtype] or xconfess;;

    my $self = $class->SUPER::new($player, ITEM_TYPE_GEM, $Gem_data[$gtype]);
    $self->[ITEM_GEM_TYPE]      = $gtype;
    # XXX lose this, always go through links?
    $self->[ITEM_GEM_DECK]      = $player->a_game->gem_deck($gtype);
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

    $b->is_gem
	    ? $b->[ITEM_GEM_TYPE] <=> $a->[ITEM_GEM_TYPE]
	    : 0
    	or $a->SUPER::spaceship($b, $rev)
}

#------------------------------------------------------------------------------

sub abbrev {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->data(GEM_DATA_ABBREV);
}

sub activate {
    @_ == 1 || badinvo;
    my $self = shift;

    return if $self->is_active;

    debug "activate $self";

    $self->a_player->num_free_gem_slots
    	or xconfess "no free gem slots";

    $self->[ITEM_GEM_ACTIVE] = 1;
    $self->a_game->note_to_players(NOTE_GEM_ACTIVATE, $self->a_player, $self);
}

sub deactivate {
    @_ == 1 || badinvo;
    my $self = shift;

    return if !$self->is_active;

    debug "deactivate $self";

    $self->[ITEM_GEM_ACTIVE] = 0;
    $self->a_game->note_to_players(NOTE_GEM_DEACTIVATE, $self->a_player, $self);
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

    if (!$self->is_active) {
	return;
    }

    my $game = $self->a_player->a_game;
    if ($game->a_turn_num == 1
	    && $game->option(OPT_5_SAPPHIRE_START)
	    && $self->a_gem_type == GEM_SAPPHIRE) {
	my $deck = $self->[ITEM_GEM_DECK];
	my $c = $deck->draw_first_matching_no_shuffle(
		    sub { shift->energy == 5 });
    	if ($c) {
	    return $c;
	}
	# This can't really happen.
	my $p = $self->a_player;
	debug "no 5 sapphire cards left, $p gets dust, deck: $deck\n";
	return Game::ScepterOfZavandor::Item::Energy::Dust->make_dust($p, 5);
    }

    return $self->[ITEM_GEM_DECK]->draw;
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

sub vp_extra {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->is_active ? $self->[ITEM_GEM_ACTIVE_VP] : 0;
}

1

__END__

energy or gem
    buy artifact, gem
    change possible

energy
    hand limit
    change possible
