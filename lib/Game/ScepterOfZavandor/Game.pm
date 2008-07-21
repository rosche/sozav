# $Id: Game.pm,v 1.2 2008-07-21 16:24:43 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Game;

use Game::Util	qw(add_array_indices debug debug_var make_rw_accessor);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant	qw(
    /^GEM_/
    @Character
    @Config_by_num_players
    @Gem
);
use Game::ScepterOfZavandor::Deck	();
use Game::ScepterOfZavandor::Player	();

BEGIN {
    add_array_indices 'GAME', (
	'INITIALIZED',
	'OPTION',
	'PLAYER',
	'GEM_DECKS',
	'ARTIFACT_DECK',
	'PLAYER_ORDER',
    );
}

sub new {
    my ($class) = @_;

    my $self = bless [], $class;
    $self->[GAME_INITIALIZED] = 0;
    $self->[GAME_OPTION] = [];
    $self->[GAME_PLAYER] = [];

    return $self;
}

make_rw_accessor (
    a_gem_decks => GAME_GEM_DECKS,
);

sub add_player {
    @_ == 2 || badinvo;
    my ($self, $player) = @_;

    $player->isa(Game::ScepterOfZavandor::Player::)
	or xcroak "non-player object ", dstr $player;

    push @{ $self->[GAME_PLAYER] }, $player;
}

sub init {
    @_ == 1 || badinvo;
    my ($self) = @_;

    if ($self->[GAME_INITIALIZED]) {
    	xcroak "game is already initialized";
    }

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

    # XXX artifact deck

    # assign characters and initialize players

    my @c = RS::Handy::shuffle 0..$#Character;
    for my $player ($self->players) {
    	$player->init($self, shift @c);
    }

    $self->[GAME_INITIALIZED] = 1;
}

sub play {
    @_ == 1 || badinvo;
    my ($self) = @_;

    while (1) {
    	# phase 1. turn order

	# XXX

	$self->[GAME_PLAYER_ORDER] = [$self->players];

	# phase 1. refill artifacts

	# phase 2. gain energy

	for ($self->players) {
	    $_->gain_energy;
	}

	# phase 3: player actions

	for (@{ $self->[GAME_PLAYER_ORDER] }) {
	    $_->actions;
	}

	# phase 4: check victory conditions

	# phase 4: hand limit
    }
}

#------------------------------------------------------------------------------

sub draw_from_deck {
    @_ == 3 || badinvo;
    my ($self, $gtype, $ct) = @_;

    return $self->[GAME_GEM_DECKS][$gtype]->draw($ct);
}

sub players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return @{ $self->[GAME_PLAYER] };
}

sub num_players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return scalar $self->players;
}

#------------------------------------------------------------------------------

1
