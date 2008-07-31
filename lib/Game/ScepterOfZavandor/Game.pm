# $Id: Game.pm,v 1.10 2008-07-31 20:47:09 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Game;

# XXY class::makemethods

use Game::Util	qw(add_array_indices debug debug_var
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr shuffle xconfess);

use Game::ScepterOfZavandor::Constant	qw(
    /^GEM_/
    /^OPT_/
    @Character
    @Config_by_num_players
    @Dust_data
    $Dust_data_val_1
    $Game_end_sentinels_sold_count
    @Gem
    @Option
    %Option
    @Sentinel_real_ix_xxx
);
use Game::ScepterOfZavandor::Item::Artifact	();
use Game::ScepterOfZavandor::Item::Sentinel	();
use Game::ScepterOfZavandor::Item::TurnOrder	();
use Game::ScepterOfZavandor::Deck		();
use Game::ScepterOfZavandor::Player		();

BEGIN {
    add_array_indices 'GAME', (
	'INITIALIZED',
	'OPTION',
	'PLAYER',
	'GEM_DECKS',
	'ARTIFACT_DECK',
	'ARTIFACTS_ON_AUCTION',
	'ARTIFACTS_AT_ONCE',
	'SENTINEL',
	'TURN_ORDER',
	'TURN_NUM',
    );
}

sub new {
    my ($class) = @_;

    my $self = bless [], $class;
    $self->[GAME_INITIALIZED]          = 0;
    $self->[GAME_OPTION]               = [];
    $self->[GAME_PLAYER]               = [];
    $self->[GAME_ARTIFACTS_ON_AUCTION] = [];
    $self->[GAME_SENTINEL]             = [];

    for (0..$#Option) {
	# XXY non-boolean types
	$self->option($_, 0);
    }

    return $self;
}

make_ro_accessor (
    a_gem_decks => GAME_GEM_DECKS,
);

make_rw_accessor (
    a_turn_num => GAME_TURN_NUM,
);

sub die_if_initialized {
    @_ == 1 || badinvo;
    my ($self) = @_;

    if ($self->[GAME_INITIALIZED]) {
    	xconfess "game is already initialized";
    }
}

sub add_player {
    @_ == 2 || badinvo;
    my ($self, $player) = @_;

    $player->isa(Game::ScepterOfZavandor::Player::)
	or xconfess "non-player object ", dstr $player;

    push @{ $self->[GAME_PLAYER] }, $player;
}

sub option {
    @_ == 2 || @_ == 3 || badinvo;
    my $self = shift;
    my $opt = shift;

    if (!$opt < 0 || $opt > @Option) {
	xconfess "invalid option ", dstr $opt;
    }

    my $old = $self->[GAME_OPTION][$opt];
    if (@_) {
	my $new = shift;
	$self->die_if_initialized;
	# XXY check type
	$self->[GAME_OPTION][$opt] = $new;
    }

    return $old;
}

sub init {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->die_if_initialized;

    $self->info("options: ", join(" ",
	map { ($self->option($_) ? "" : "!") . $Option[$_] } 0..$#Option));

    my $num_players = $self->num_players;
    debug_var num_players => $num_players;
    my $num_players_config = $Config_by_num_players[$num_players];
    if (!$num_players_config) {
	xconfess "invalid number of players $num_players";
    }
    my ($artifacts_at_once, $artifact_copies) = @$num_players_config;
    $self->[GAME_ARTIFACTS_AT_ONCE] = $artifacts_at_once;

    # add 1 dust if desired

    if ($self->option(OPT_1_DUST)) {
	push @Dust_data, $Dust_data_val_1;
    }

    # initialize gem decks

    $self->[GAME_GEM_DECKS] = [];
    for my $i (0..$#Gem) {
    	next if $i == GEM_OPAL;
	$self->[GAME_GEM_DECKS][$i]
	    = Game::ScepterOfZavandor::Deck->new($self, $i);
    }

    # initialize artifact deck

    $self->[GAME_ARTIFACT_DECK]
	= Game::ScepterOfZavandor::Item::Artifact->new_deck($self, $artifact_copies);
    #print "artifact deck:\n";
    #print $_, "\n" while $_ = $self->[GAME_ARTIFACT_DECK]->draw;

    $self->[GAME_SENTINEL]
	= [Game::ScepterOfZavandor::Item::Sentinel->new_deck($self)];

    # create turn order markers

    $self->[GAME_TURN_ORDER] = [];
    for (0 .. $num_players-1) {
    	push @{ $self->[GAME_TURN_ORDER] },
	    Game::ScepterOfZavandor::Item::TurnOrder->new($self, $_);
    }

    # assign characters and initialize players

    my @c = RS::Handy::shuffle 0..$#Character;
    for my $player ($self->players) {
    	$player->init(shift @c);
    }

    # XXX convenience when testing
    $self->[GAME_PLAYER] =
	[sort { $a->a_char <=> $b->a_char } $self->players];

    $self->[GAME_TURN_NUM]    = 0;
    $self->[GAME_INITIALIZED] = 1;
}

#------------------------------------------------------------------------------

sub play {
    @_ == 1 || badinvo;
    my ($self) = @_;

    while (1) {
    	# phase 1. turn order

	$self->a_turn_num(1 + $self->a_turn_num);

    	my @p = $self->players_in_order;
	if ($self->a_turn_num > 1) {
	    for (@p) {
		$_->remove_items($_->turn_order_card);
	    }
	}
	for (0..$#p) {
	    my $to = $self->[GAME_TURN_ORDER][$_];
	    $to->a_player($p[$_]);
	    $p[$_]->add_items($to);
	    $p[$_]->a_score_at_turn_start($p[$_]->score);
	}

	# phase 1. refill artifacts

	while (@{ $self->[GAME_ARTIFACTS_ON_AUCTION] }
		    < $self->[GAME_ARTIFACTS_AT_ONCE]) {
	    my $i = $self->[GAME_ARTIFACT_DECK]->draw
		or last;
	    push @{ $self->[GAME_ARTIFACTS_ON_AUCTION] }, $i;
	}

	# phase 2. gain energy

	for (@p) {
	    $_->gain_energy;
	}

	# phase 3: player actions

	for (@p) {
	    $_->actions;
	}

	# phase 4: check victory conditions

	if (@Sentinel_real_ix_xxx - @{ $self->[GAME_SENTINEL] }
	    	>= $Game_end_sentinels_sold_count) {
	    last;
	}

	# phase 4: hand limit

	for (@p) {
	    $_->enforce_hand_limit;
	}
    }

    $self->info("Game over");
    my $place         = 0;
    my $nominal_place = 0;
    my $prev_score    = undef;
    for my $player ($self->players_in_order) {
	$nominal_place++;
    	my $this_score = $player->score;
	$place = (defined $prev_score && $this_score == $prev_score)
    	    	    	? $place
			: $nominal_place;
	$self->info(sprintf "  %s. %3d %s",
		    $place,
		    $player->score,
		    $player->name);
	for my $item (sort { $a <=> $b } grep { $_->vp } $player->items) {
	    $self->info(" " x 11, $item);
	}
	$prev_score = $this_score;
    }
}

#------------------------------------------------------------------------------

sub auction_all {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return $self->auction_artifacts, $self->auction_sentinels;
}

sub auction_artifacts {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return @{ $self->[GAME_ARTIFACTS_ON_AUCTION] };
}

sub auction_sentinels {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return @{ $self->[GAME_SENTINEL] };
}

sub auctionable_sold {
    @_ == 2 || badinvo;
    my $self = shift;
    my $auc  = shift;

    my $r = $auc->is_artifact
    	    	? $self->[GAME_ARTIFACTS_ON_AUCTION]
		: $auc->is_sentinel
		    ? $self->[GAME_SENTINEL]
		    : xconfess "auctionable_sold $auc";

    my @old = @$r;
    my @new = grep { $_ != $auc } @old;
    @new == @old - 1
	or xconfess "$auc not available for purchase";
    @$r = @new;
}

sub draw_from_deck {
    @_ == 3 || badinvo;
    my ($self, $gtype, $ct) = @_;

    return $self->[GAME_GEM_DECKS][$gtype]->draw($ct);
}

# XXX
sub log {
    @_ > 1 || badinvo;
    my $self = shift;

    print "log: ", @_, "\n";
}

# XXX
sub info {
    @_ > 1 || badinvo;
    my $self = shift;

    print @_, "\n";
}

sub players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return @{ $self->[GAME_PLAYER] };
}

sub players_in_order {
    @_ == 1 || badinvo;
    my ($self) = @_;

    # Arbitrary order for players with the same score and score from
    # gems is done by doing an initial shuffle and using a stable sort.

    my @p = shuffle $self->players;

    return map { $p[$_] } sort { 0
    	    or $p[$b]->score           <=> $p[$a]->score
    	    or $p[$b]->score_from_gems <=> $p[$a]->score_from_gems
    	    or    $b                   <=>    $a
    } 0..$#p;
}

sub num_players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return scalar $self->players;
}


#------------------------------------------------------------------------------

1
