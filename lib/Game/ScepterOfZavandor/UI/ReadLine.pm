# $Id: ReadLine.pm,v 1.8 2008-08-11 23:53:48 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::ReadLine;

use base qw(Game::ScepterOfZavandor::UI::Stdio);

use Term::ReadLine	();
use Game::Util 		qw(add_array_index debug);
use RS::Handy		qw(badinvo data_dump define dstr xcroak);
use Symbol		qw(qualify_to_ref);

BEGIN {
    add_array_index 'UI', $_ for map { "READLINE_$_" } qw(OBJ);
}

my $Readline;

sub readline_init {
    @_ == 2 || badinvo;
    my ($in_fh, $out_fh) = @_;

    my $rl = Term::ReadLine->new('zavandor', $in_fh, $out_fh)
	or xcroak "can't initialize Term::ReadLine";

    my $a = $rl->Attribs;
    $a->{completion_entry_function} = $a->{list_completion_function};
    $a->{completion_word}           = [__PACKAGE__->get_action_names];

    # XXX comletion for gem, knowledge names when appropriate

    return $rl;
}

sub new {
    @_ == 4 || badinvo;
    my ($class, $game, $in_fh, $out_fh) = @_;

    $in_fh  = qualify_to_ref $in_fh , scalar caller;
    $out_fh = qualify_to_ref $out_fh, scalar caller;

    # XXX only 1 readline obj allowed with whatever module I'm using
    $Readline ||= readline_init $in_fh, $out_fh;

    my $self = $class->SUPER::new($game, $in_fh, $out_fh);
    $self->[UI_READLINE_OBJ] = $Readline;

    return $self;
}

sub in {
    @_ == 1 || @_ == 2 || badinvo;
    my $self   = shift;
    my $prompt = shift;

    if (!defined $prompt) {
	$prompt = "action (? for brief help): ";
	$prompt = $self->a_player->name . " $prompt"
	    if $self->a_player;
    }
    return $self->[UI_READLINE_OBJ]->readline($prompt);
}

1
