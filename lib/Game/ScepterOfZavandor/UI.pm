use strict;

package Game::ScepterOfZavandor::UI;

use Game::Util 	qw(add_array_indices debug
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant	qw(
    /^NOTE_/
    @Note
);

BEGIN {
    add_array_indices 'UI', qw(ID GAME PLAYER LOG_PATH LOG_FH
				IGNORE_UNIMPLEMENTED_NOTEs);
}

{ my $id = 'A';
sub new {
    @_ == 2 || badinvo;
    my $class = shift;
    my $game  = shift;

    my $self = bless [], $class;
    $self->[UI_ID]   = "ui-" . $id++;
    $self->[UI_GAME] = $game;
    $self->[UI_IGNORE_UNIMPLEMENTED_NOTES] = 0;

    return $self;
} }

make_ro_accessor (
    a_game     => UI_GAME,
    a_id       => UI_ID,
    a_log_path => UI_LOG_PATH,
    a_log_fh   => UI_LOG_FH,
);

make_rw_accessor (
    a_ignore_unimplemented_notes => UI_IGNORE_UNIMPLEMENTED_NOTES,
);

# XXX duplicate of Item->a_player, move to a util lib?
sub a_player {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;
    my $old = $self->[UI_PLAYER];
    if (@_) {
	$self->[UI_PLAYER] = shift;
	weaken $self->[UI_PLAYER];
    }
    return $old;
}

sub log_open {
    @_ == 2 || badinvo;
    my $self = shift;
    my $path = shift;

    my $fh;
    if (!open $fh, ">>", $path) {
	xconfess "can't write to $path: $!";
    }

    my $old = select $fh;
    $| = 1;
    select $old;

    $self->[UI_LOG_PATH] = $path;
    $self->[UI_LOG_FH  ] = $fh;
}

sub log_out {
    @_ || badinvo;
    my $self = shift;

    my $fh = $self->a_log_fh
	or return;
    print $fh @_
    	or xconfess "error writing to $self->a_log_path: $!";
}

sub log_close {
    @_ || badinvo;
    my $self = shift;

    my $fh = $self->a_log_fh
	or return;
    close $fh
    	or xconfess "error closing to $self->a_log_path: $!";
}

# game-specific methods -----------------------------------------------------

for (qw(
	choose_character
	choose_active_gem_to_destroy
	choose_knowledge_type_to_advance
	one_action
	solicit_bid
	)) {
    eval qq{
	sub $_ {
	    die "$_ unimplemented";
	}
    };
    die if $@;
}

sub maybe_confirm_payment {
    @_ == 2 || badinvo;
    my ($self, $payment) = @_;

    if ($payment > $self->a_player->current_energy_total) {
    	$self->ui_note(NOTE_CANT_AFFORD, $payment);
    	return 0;
    }

    return 1;
}

sub tag_abbrev {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $full   = shift;
    my $abbrev = shift;

    return $full;
}

sub start_actions {
    @_ == 1 || badinvo;
    my $self = shift;

    # Auto-activate gems to deal with losing something to a mirror/cloak,
    # or buying an elixir on somebody else's turn.

    $self->a_player->auto_activate_gems;
}

#------------------------------------------------------------------------------

sub ui_note_backend {
    @_ >= 3 || badinvo;
    my $self	= shift;
    my $is_global = shift;
    my $ntype	= shift;

    my $ndesc = $Note[$ntype];
    if (!defined $ndesc) {
	xconfess "invalid Note type ", dstr $ntype;
    }

    my $meth = "ui_note_$ndesc";
    if (!$self->can($meth) && $self->a_ignore_unimplemented_notes) {
	debug "$self ui ignoring note $ndesc";
    	return;
    }

    return $self->$meth(@_);
}

sub ui_note {
    my $self = shift;
    $self->ui_note_backend(0, @_);
}

sub ui_note_global {
    my $self = shift;
    $self->ui_note_backend(1, @_);
}

#------------------------------------------------------------------------------

1
