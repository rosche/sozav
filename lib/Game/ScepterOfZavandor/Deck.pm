# $Id: Deck.pm,v 1.1 2008-07-17 01:49:09 roderick Exp $

package Game::ScepterOfZavandor::Deck;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use Game::ScepterOfZavandor::Game qw(/^GEM_/);
use Game::ScepterOfZavandor::Util;

use vars qw($VERSION @EXPORT @EXPORT_OK);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT_OK = qw(
    );
}

use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

sub new {
    @_ == 2 || badinvo;
    my ($class, $gtype) = @_;

    my $self = bless [], $class;
    $self->[GAME_OPTION] = [];
    $self->[GAME_PLAYER] = [];

    return $self;
}

sub add_player {
    @_ == 2 || badinvo;
    my ($self, $player) = @_;

    ref $player or die dstr $player;

    push @{ $self->[GAME_PLAYER] }, $player;
}

sub start {
    @_ == 1 || badinvo;
    my ($self) = @_;

    my $num_players = $self->num_players;
    debug_var num_players => $num_players;
    my $num_players_config = $Config_by_num_players[$num_players];
    if (!$num_players_config) {
	xcroak "invalid number of players $num_players";
    }

    # initialize gem decks

    $self->[GAME_GEM_DECKS] = [];
    for my $i (0..$#Gem) {
    	next if $i == GEM_OPAL;
	$self->[GAME_GEM_DECKS][$i] = Game::ScepterOfZavandor::Deck->new($i);
    }
}

#------------------------------------------------------------------------------

sub num_players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return scalar @{ $self->[GAME_PLAYER] };
}

#------------------------------------------------------------------------------

1
