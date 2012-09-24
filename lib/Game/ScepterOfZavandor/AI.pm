use strict;

package Game::ScepterOfZavandor::AI;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 	qw(add_array_indices debug
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);

use Game::ScepterOfZavandor::Constant	qw(
    @Gem
);
#    /^GEM_DATA_/
#    /^KNOW_DATA_/
#    /^NOTE_/
#    @Character
#    @Gem_data
#    @Knowledge_data
#    @Note
#    @Option
#);

#------------------------------------------------------------------------------

sub new {
    my $self = shift->SUPER::new(@_);

    $self->a_ignore_unimplemented_notes(1);
    return $self;
}

# game-specific methods -----------------------------------------------------

sub choose_character {
    @_ >= 3 || badinvo;
    my $self       = shift;
    my $player_num = shift;
    my @c          = @_;

    return; # random
}

sub choose_active_gem_to_destroy {
    @_ == 1 || badinvo;
    my $self = shift;
    return $self->worst_active_gem;
}

sub choose_knowledge_type_to_advance {
    @_ == 1 || badinvo;
    my $self = shift;
    die "unimplemented";
    # xxx choose single if only 1?
}

# utility functions -----------------------------------------------------------
#
# These could be moved to Player if they're useful there.

sub advancable_knowledge_chips_by_cost {
    @_ == 1 || badinvo;
    my $self = shift;

    # sort in separate expression so it can't be in scalar context
    my @k = sort { $a->next_level_cost <=> $b->next_level_cost }
		grep { $_->is_assigned }
		    $self->a_player->knowledge_chips_advancable;
    return @k;
}

sub best_buyable_gem_type {
    @_ == 1 || badinvo;
    my $self = shift;

    for my $gtype (reverse 0..$#Gem) {
	if ($self->a_player->can_buy_gem_type_right_now($gtype)) {
	    return $gtype;
	}
    }
    die; # can't happen
}

sub worst_active_gem {
    @_ == 1 || badinvo;
    my $self = shift;

    my @g = $self->a_player->gems_by_cost;
    return @g ? $g[0] : ();
}

#------------------------------------------------------------------------------

1
