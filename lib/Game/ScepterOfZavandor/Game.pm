# $Id: Game.pm,v 1.3 2008-07-23 01:03:20 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Game;

use Game::Util	qw(add_array_indices debug debug_var make_ro_accessor);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr xcroak);

use Game::ScepterOfZavandor::Constant	qw(
    /^GEM_/
    /^OPT_/
    @Character
    @Config_by_num_players
    @Dust_data
    $Dust_data_val_1
    @Gem
    @Option
    %Option
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

    for (0..$#Option) {
	# XXX non-boolean types
	$self->option($_, 0);
    }

    return $self;
}

make_ro_accessor (
    a_gem_decks => GAME_GEM_DECKS,
);

sub die_if_initialized {
    @_ == 1 || badinvo;
    my ($self) = @_;

    if ($self->[GAME_INITIALIZED]) {
    	xcroak "game is already initialized";
    }
}

sub add_player {
    @_ == 2 || badinvo;
    my ($self, $player) = @_;

    $player->isa(Game::ScepterOfZavandor::Player::)
	or xcroak "non-player object ", dstr $player;

    push @{ $self->[GAME_PLAYER] }, $player;
}

sub option {
    @_ == 2 || @_ == 3 || badinvo;
    my $self = shift;
    my $opt = shift;

    if (!$opt < 0 || $opt > @Option) {
	xcroak "invalid option ", dstr $opt;
    }

    my $old = $self->[GAME_OPTION][$opt];
    if (@_) {
	my $new = shift;
	$self->die_if_initialized;
	# XXX check type
	$self->[GAME_OPTION][$opt] = $new;
    }

    return $old;
}

sub init {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->die_if_initialized;

    # XXX
    print "options: ", join(" ",
	map { ($self->option($_) ? "" : "!") . $Option[$_] } 0..$#Option),
	"\n";

    my $num_players = $self->num_players;
    debug_var num_players => $num_players;
    my $num_players_config = $Config_by_num_players[$num_players];
    if (!$num_players_config) {
	xcroak "invalid number of players $num_players";
    }

    # add 1 dust if desired

    if ($self->option(OPT_1_DUST)) {
	push @Dust_data, $Dust_data_val_1;
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
    	$player->init(shift @c);
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

	for ($self->players) {
	    $_->enforce_hand_limit;
	}
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
