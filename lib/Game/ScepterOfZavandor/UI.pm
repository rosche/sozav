# $Id: UI.pm,v 1.10 2009-02-15 15:16:57 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI;

use Game::Util 	qw(add_array_indices debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);
use Scalar::Util qw(weaken);

use Game::ScepterOfZavandor::Constant	qw(
    @Character
);

BEGIN {
    add_array_indices 'UI', qw(GAME PLAYER LOG_PATH LOG_FH);
}

sub new {
    @_ == 2 || badinvo;
    my $class = shift;
    my $game  = shift;

    my $self = bless [], $class;
    $self->[UI_GAME] = $game;

    return $self;
}

make_ro_accessor (
    a_game     => UI_GAME,
    a_log_path => UI_LOG_PATH,
    a_log_fh   => UI_LOG_FH,
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

# Abstract methods:
#    in
#    out
#    out_error
#    out_notice

sub info {
    my $self = shift;
    $self->out(@_);
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

sub start_actions {
}

sub can_underline {
    @_ == 1 || badinvo;
    return $_[0]->underline("hi mom") ne "hi mom";
}

sub underline {
    @_ == 2 || badinvo;
    return $_[1];
}

#------------------------------------------------------------------------------

sub choose_character {
    @_ >= 3 || badinvo;
    my $self       = shift;
    my $player_num = shift;
    my @c          = @_;

    if (@c == 1) {
	return $c[0];
    }

    my @name = @Character[@c];
    $self->out("\n");
    my $c = $self->prompt_for_index(
		    "Choose character for player $player_num, "
			. "or press Enter for a random one: ",
		    \@name,
		    allow_empty => 1,
		    header      => "Available characters:\n",
    	    	    indent      => "  ");
    if ($c eq '') {
    	$c = int rand @name;
    }
    return $c[$c];
}

sub prompt {
    @_ >= 3 || badinvo;
    my $self = shift;
    my ($prompt, $rchoice, @opt) = @_;

    return RS::Handy::prompt $prompt, $rchoice,
	    iosub => sub { $self->prompt_iosub(@_) },
	    @opt;
}

sub prompt_iosub {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $prompt = shift;

    return $self->in($prompt);
}

sub prompt_for_index {
    @_ >= 3 || badinvo;
    my $self   = shift;
    my $prompt = shift;
    my $rlist  = shift;
    my @opt    = @_;

    process_arg_pairs \@opt, (
	allow_empty => \(my $allow_empty),
	header      => \(my $header),
	indent      => \(my $indent = ""),
    );

    $self->out($header)
	if defined $header;

    my $ct = @$rlist;
    my $width = length $ct;
    for (0..$#{ $rlist }) {
	$self->out(sprintf "%s%${width}d. %s\n", $indent, $_+1, $rlist->[$_]);
    }

    # XXX add single-letter choices, perhaps determined by caller,
    # perhaps automatically

    my $n = $self->prompt($prompt, [1..$ct, $allow_empty ? "" : ()]);
    if ($n ne '') {
	$n--;
    }

    return $n;
}

sub tag_abbrev {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $full   = shift;
    my $abbrev = shift;

    $full =~ s/(\Q$abbrev\E)/$self->underline($1)/e
	or xconfess "full ", dstr $full, " abbrev ", dstr $abbrev;
    return $full;
}

1
