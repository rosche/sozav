# $Id: Game.pm,v 1.16 2012-04-28 20:02:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Game;

# XXY class::makemethods

use Game::Util	qw($Debug add_array_indices debug debug_var
		    make_ro_accessor make_rw_accessor valid_ix);
use List::MoreUtils qw(minmax);
use List::Util	qw(sum);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr
		    pwuid safe_tmp shuffle xconfess);

use Game::ScepterOfZavandor::Constant	qw(
    /^CHAR_/
    /^DUST_DATA_/
    /^GAME_GEM_DATA/
    /^GEM_/
    /^NOTE_/
    /^OPT_/
    @Character
    $Concentrated_additional_dust
    @Config_by_num_players
    @Dust_data
    $Dust_data_val_1
    $Game_end_sentinels_sold_count
    @Gem
    @Gem_data
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
	'PLAYER_TABLE_ORDER',
	'PLAYER_TURN_ORDER',
	'GEM_DATA',
	'DUST_DATA',
	'ARTIFACT_DECK',
	'ARTIFACTS_ON_AUCTION',
	'ARTIFACTS_AT_ONCE',
	'SENTINEL',
	'TURN_ORDER_CARD',
	'TURN_NUM',
    );
}

sub new {
    my ($class) = @_;

    my $self = bless [], $class;
    $self->[GAME_INITIALIZED]          = 0;
    $self->[GAME_OPTION]               = [];
    $self->[GAME_PLAYER_TABLE_ORDER]   = [];
    $self->[GAME_PLAYER_TURN_ORDER]    = [];
    $self->[GAME_GEM_DATA]             = [];
    $self->[GAME_DUST_DATA]            = [@Dust_data];
    $self->[GAME_ARTIFACTS_ON_AUCTION] = [];
    $self->[GAME_SENTINEL]             = [];

    for (0..$#Option) {
	# XXX non-boolean types
	$self->option($_, 0);
    }
    $self->option(OPT_VERBOSE           , 1);
    $self->option(OPT_DRUID_LEVEL_3_RUBY, 1);
    $self->option(OPT_9_SAGES_DUST      , 1);

    return $self;
}

make_ro_accessor (
    a_dust_data => GAME_DUST_DATA,
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

    push @{ $self->[GAME_PLAYER_TABLE_ORDER] }, $player;
}

sub new_ui {
    @_ == 1 || badinvo;
    my ($self) = @_;

    require Game::ScepterOfZavandor::UI::ReadLine;

    my $ui = Game::ScepterOfZavandor::UI::ReadLine->new($self, *STDIN, *STDOUT);
    # XXX opens for each player, desirable?
    $ui->log_open(scalar safe_tmp
		    dir => "/var/local/zavandor",
		    mode => 0666,
		    prefix => "zavandor.");
    $ui->log_out(scalar(localtime), "\n");

    # XXX not working
    if (my $peer = getpeername STDIN) {
	require Socket;
	my ($port, $iaddr) = Socket::sockaddr_in($peer);
	$ui->log_out("remote is ", Socket::inet_ntoa($iaddr), ":$port\n");
    }

    return $ui;
}

sub option {
    @_ == 2 || @_ == 3 || badinvo;
    my $self = shift;
    my $opt  = shift;

    valid_ix $opt, \@Option
	or xconfess "bad option index ", dstr $opt;

    my $old = $self->[GAME_OPTION][$opt];
    if (@_) {
	my $new = shift;
	$self->die_if_initialized;
	# XXY check type
	$self->[GAME_OPTION][$opt] = $new;
    }

    return $old;
}

sub option_toggle {
    @_ == 2 || @_ == 3 || badinvo;
    my $self = shift;
    my $opt = shift;

    return $self->option($opt, !$self->option($opt));
}

sub init {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->die_if_initialized;

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
    	push @{ $self->a_dust_data }, $Dust_data_val_1;
    }

    $self->init_items($artifact_copies);
    $self->init_players;

    $self->[GAME_TURN_NUM]    = 0;
    $self->[GAME_INITIALIZED] = 1;
}

# derive values from card distributions

sub init_card_info {
    @_ == 1 || badinvo;
    my $self = shift;

    my $tot = 0;
    for my $gi (0..$#Gem) {
    	my $deck = $self->gem_deck($gi)
	    or next;

	my @value = map { $_->energy } $deck->all_deck_items
	    or xconfess $gi;

	my $ct = scalar @value;
	$tot += $ct;
    	my ($min, $max) = minmax @value;
	my $avg  = sum(@value) / $ct;
	debug sprintf "%-8s count %2d min %2d max %2d avg %5.2f",
	    $Gem[$gi], $ct, $min, $max, $avg;

    	my $rgame_gem_data = $self->gem_data($gi);
	$rgame_gem_data->[GAME_GEM_DATA_CARD_MIN] = $min;
	$rgame_gem_data->[GAME_GEM_DATA_CARD_AVG] = $avg;
	$rgame_gem_data->[GAME_GEM_DATA_CARD_MAX] = $max;
    }
    $tot == 126 or xconfess $tot;
}

sub init_gem_decks {
    @_ == 1 || badinvo;
    my $self = shift;

    for my $i (0..$#Gem) {
    	next if $i == GEM_OPAL;
	$self->[GAME_GEM_DATA][$i] = [];
	my $deck = Game::ScepterOfZavandor::Deck->new($self, $i);
    	my $rdata = $self->gem_data($i);
	$rdata->[GAME_GEM_DATA_DECK] = $deck;
    }

    # have to do the card init before initializing players and the fairy
    # gets 2 sapphire cards
    $self->init_card_info;
}

sub init_items {
    @_ == 2 || badinvo;
    my $self            = shift;
    my $artifact_copies = shift;

    $self->init_gem_decks;

    # initialize artifact deck

    $self->[GAME_ARTIFACT_DECK]
	= Game::ScepterOfZavandor::Item::Artifact->new_deck($self,
							    $artifact_copies);
    if ($Debug > 2) {
	print "artifact deck:\n";
	print $_, "\n" while $_ = $self->[GAME_ARTIFACT_DECK]->draw;
    }

    $self->[GAME_SENTINEL]
	= [Game::ScepterOfZavandor::Item::Sentinel->new_deck($self)];

    # create turn order markers
    #
    # XXX options to use a different set, to give non-standard
    # discounts/penalties

    $self->[GAME_TURN_ORDER_CARD] = [];
    for (0 .. $self->num_players - 1) {
    	push @{ $self->[GAME_TURN_ORDER_CARD] },
	    Game::ScepterOfZavandor::Item::TurnOrder->new($self, $_);
    }
}

# assign characters and initialize players

sub init_players {
    @_ == 1 || badinvo;
    my $self = shift;

    my @all_c = 0..$#Character;
    if ($self->option(OPT_NO_DRUID)
	    && ($self->option(OPT_DUPLICATE_CHARACTERS)
    	    	    || $self->num_players < @all_c)) {
	@all_c = grep { $_ != CHAR_DRUID } @all_c;
    }

    if ($self->option(OPT_CHOOSE_CHARACTER)) {
	my @c          = @all_c;
    	my $player_num = 0;
	for my $player ($self->players_in_table_order) {
	    $player_num++;
	    @c = @all_c
		if $self->option(OPT_DUPLICATE_CHARACTERS);
	    my $c = $player->a_ui->choose_character($player_num,
							sort { $a <=> $b } @c);
	    $c //= splice @c, int rand @c, 1;
	    my @new = grep { $_ != $c } @c;
	    if (@c != @new + 1) {
		xconfess "$player chose bad character ", dstr $c;
	    }
	    @c = @new;
	    $player->init($c);
	}
    }
    else {
	my @c = shuffle @all_c;
	for my $player ($self->players_in_table_order) {
	    @c = shuffle @all_c
		if $self->option(OPT_DUPLICATE_CHARACTERS);
	    $player->init(shift @c);
	}
    }

    for ($self->players_in_table_order) {
	$_->init_items;
    }
}

sub note_to_players {
    @_ >= 2 || badinvo;
    my ($self, @rest) = @_;

    for ($self->players_in_table_order) {
	$_->a_ui->ui_note(@rest)
	    unless $_->a_ui->a_suppress_global_messages;
    }
}

#------------------------------------------------------------------------------

sub play {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->note_to_players(NOTE_GAME_START);
    while (1) {
	$self->a_turn_num(1 + $self->a_turn_num);

    	# phase 1. turn order

    	my @p = $self->generate_player_order;
	$self->[GAME_PLAYER_TURN_ORDER] = [@p];
	if ($self->a_turn_num > 1) {
	    for (@p) {
		$_->remove_items($_->turn_order_card);
	    }
	}
	for (0..$#p) {
	    my $to = $self->[GAME_TURN_ORDER_CARD][$_];
	    $to->a_player($p[$_]);
	    $p[$_]->add_items($to);
	    $p[$_]->a_score_at_turn_start($p[$_]->score);
	}
    	$self->note_to_players(NOTE_TURN_START);

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
	    $self->note_to_players(NOTE_ACTIONS_START, $_);
	    $_->actions;
	    $self->note_to_players(NOTE_ACTIONS_END, $_);
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
    $self->note_to_players(NOTE_GAME_END);
}

#------------------------------------------------------------------------------

sub auctionable_items {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return $self->auctionable_artifacts, $self->auctionable_sentinels;
}

sub auctionable_artifacts {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return @{ $self->[GAME_ARTIFACTS_ON_AUCTION] };
}

sub auctionable_sentinels {
    @_ == 1 || badinvo;
    my ($self) = @_;
    return @{ $self->[GAME_SENTINEL] };
}

sub auction_item {
    @_ == 4 || badinvo;
    my ($self, $start_player, $auc, $start_bid) = @_;

    my $min = $auc->a_data_min_bid;
    if ($start_bid < $min) {
    	die "bid too low (minimum $min, bid $start_bid)\n";
    }

    $self->note_to_players(NOTE_AUCTION_START, $start_player, $auc, $start_bid);

    my $cur_bid    = $start_bid;
    my $cur_winner = $start_player;

    my @bidder = $self->players_in_turn_order;
    my $next_bidder = sub {
    	push @bidder, shift @bidder;
    };
    # rotate @bidder until the current player is at the start
    {
    	my $ct = 0;
	while ($bidder[0] != $cur_winner) {
	    if ($ct++ > @bidder) {
		xconfess "start player isn't a bidder";
	    }
	    $next_bidder->();
	}
    }

  Bidder:
    $next_bidder->();
    while (@bidder > 1) {
	my $bidder = $bidder[0];

	my $new_bid;
	while (1) {
	    $new_bid = $bidder->a_ui->solicit_bid($auc, $cur_bid, $cur_winner);
	    $new_bid ||= 0;
	    if (!$new_bid || $new_bid > $cur_bid) {
	    	last;
	    }
	    $bidder->a_ui->ui_note(NOTE_INVALID_BID, $auc, $cur_bid, $new_bid);
	}

	$self->note_to_players(NOTE_AUCTION_BID, $bidder, $auc, $new_bid);

	if (!$new_bid) {
	    # pass
	    shift @bidder;
	}
	else {
	    $cur_bid = $new_bid;
	    $cur_winner = $bidder;
	    $next_bidder->();
	}
    }

    $self->note_to_players(NOTE_AUCTION_WON, $cur_winner, $auc, $cur_bid);
    $cur_winner->buy_auctionable($auc, $cur_bid);
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

    return $self->gem_deck($gtype)->draw($ct);
}

sub dust_data_loop {
    @_ == 2 || badinvo;
    my ($self, $callback) = @_;

    local $_;
    for (@{ $self->a_dust_data }) {
	$callback->();
    }
}

sub gem_data {
    @_ == 2 || badinvo;
    my ($self, $gtype) = @_;

    # XXX this should be a common idiom, make a sub which includes the die
    valid_ix $gtype, \@Gem
	or xconfess "bad gem index ", dstr $gtype;

    return $self->[GAME_GEM_DATA][$gtype];
}

sub gem_deck {
    @_ == 2 || badinvo;
    my ($self, $gtype) = @_;

    # XXX this should be a common idiom, make a sub which includes the die
    valid_ix $gtype, \@Gem
	or xconfess "bad gem index ", dstr $gtype;

    my $rdata = $self->gem_data($gtype)
    	or return;

    return $rdata->[GAME_GEM_DATA_DECK];
}

sub gem_energy_desc {
    @_ == 2 || badinvo;
    my ($self, $gtype) = @_;

    my $s = '';

    if ($gtype == GEM_OPAL) {
	$s .= join ", ",
		map({ "$_->" . Game::ScepterOfZavandor::Item::Energy::Dust
    	    	    	    	->opal_count_to_energy_value($_)
		} 1 .. (2 + grep { $_->[DUST_DATA_OPAL_COUNT] }
			    @{ $self->a_dust_data })),
    	    	"...";
    }
    else {
	my $ggd = $self->gem_data($gtype);
	$s .= sprintf "min %2d avg %4.1f max %2d concentrated %2d+%d",
		$ggd->[GAME_GEM_DATA_CARD_MIN],
		$ggd->[GAME_GEM_DATA_CARD_AVG],
		$ggd->[GAME_GEM_DATA_CARD_MAX],
		$Gem_data[$gtype][GEM_DATA_CONCENTRATED],
		$Concentrated_additional_dust;
    }

    return $s;
}

# XXX
sub log {
    @_ > 1 || badinvo;
    my $self = shift;

    print "log: ", @_, "\n";
}

sub players_in_table_order {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return @{ $self->[GAME_PLAYER_TABLE_ORDER] };
}

sub players_in_turn_order {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return @{ $self->[GAME_PLAYER_TURN_ORDER] };
}

# returns list of [place, player object] tuples

sub players_by_rank {
    @_ == 1 || badinvo;
    my ($self) = @_;

    my $place         = 0;
    my $nominal_place = 0;
    my $prev_score    = undef;
    my @ret;

    # There's no tie-breaker after score, the official rule is the
    # tied players have to play another game to decide!

    for my $player (sort { $b->score <=> $a->score } $self->players_in_table_order) {
	$nominal_place++;
    	my $this_score = $player->score;
	$place = (defined $prev_score && $this_score == $prev_score)
    	    	    	? $place
			: $nominal_place;
    	push @ret, [$place, $player];
	$prev_score = $this_score;
    }

    return @ret;
}

sub generate_player_order {
    @_ == 1 || badinvo;
    my ($self) = @_;

    # Arbitrary order for players with the same score and score from
    # gems is done by doing an initial shuffle and using a stable sort.

    my @p = shuffle $self->players_in_table_order;

    return map { $p[$_] } sort { 0
    	    or $p[$b]->score           <=> $p[$a]->score
    	    or $p[$b]->score_from_gems <=> $p[$a]->score_from_gems
    	    or    $a                   <=>    $b
    } 0..$#p;
}

sub num_players {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return scalar $self->players_in_table_order;
}


#------------------------------------------------------------------------------

sub prompt_for_options {
    @_ == 2 || badinvo;
    my $self = shift;
    my $ui   = shift;

    while (1) {
	my $w = 30;
	$ui->out("\n");
	$ui->out("Game options:\n");
	$ui->out("\n");
	$ui->out(sprintf "      %-${w}s%-${w}s\n", qw(enabled disabled));
	$ui->out(sprintf "      %-${w}s%-${w}s\n", qw(------- --------));
	for (0..$#Option) {
	    my $o = $self->option($_);
	    $ui->out($o ? "" : " " x $w,
		     sprintf "  %2d. %s\n", $_+1, $Option[$_]);
	}
	my $i = $ui->prompt("Type the number of the option to toggle, "
				. "or Enter to continue: ",
			    ["", 1..@Option]);
	last unless defined $i && $i ne '';
	$self->option_toggle($i - 1);
    }
}

sub run_game {
    @_ == 0 || @_ == 1 || badinvo;
    my $num_players = shift;

    my $g = Game::ScepterOfZavandor::Game->new;
    my $ui = $g->new_ui;

    $ui->out("The Scepter of Zavandor\n");
    # XXX set up web site
    # XXX add this link to help
    #$ui->out("more info at http://www.argon.org/zavandor/\n");

    if (!defined $num_players) {
	$ui->out("\n");
	$num_players = $ui->prompt("How may players? (1-6) ", [1..6]);
	$g->prompt_for_options($ui);
    }

    my @p;
    for (1 .. $num_players) {
    	my $this_ui;
	if ($_ == 1) {
	    $this_ui = $ui;
	}
	else {
	    $this_ui = $g->new_ui;
	    $this_ui->a_suppress_global_messages(1);
	}

    	push @p,
	    Game::ScepterOfZavandor::Player->new($g, $this_ui);
	$g->add_player($p[-1]);
    }
    $g->init;

    if (0 && @p == 1) {
    	my $p = $p[0];
	for (1..4) {
	    $p[0]->add_items(Game::ScepterOfZavandor::Item::Gem->new(
    	    	    	    	$p, GEM_RUBY));
	}
	$p->auto_activate_gems;
    }

    $g->play;
}


#------------------------------------------------------------------------------

1
