# $Id: Game.pm,v 1.19 2012-09-18 13:51:27 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Game;

# XXY class::makemethods

use Game::Util	qw($Debug add_array_indices debug debug_var
		    make_ro_accessor make_rw_accessor valid_ix);
use List::MoreUtils qw(minmax);
use List::Util	qw(sum);
use RS::Handy	qw(badinvo create_constant_subs data_dump dstr
		    safe_tmp shuffle xconfess);

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
    $Max_players
    @Option
    %Option
    @Sentinel_real_ix_xxx
);

use Game::ScepterOfZavandor::Item::Artifact	();
use Game::ScepterOfZavandor::Item::Sentinel	();
use Game::ScepterOfZavandor::Item::TurnOrder	();
use Game::ScepterOfZavandor::Deck		();
use Game::ScepterOfZavandor::Player		();
use Game::ScepterOfZavandor::Undo		();

BEGIN {
    add_array_indices 'GAME', (
	'INITIALIZED',
	'OPTION',
	'PLAYER_TABLE_ORDER',
	'PLAYER_TURN_ORDER',
	'KIBITZER',
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
    $self->[GAME_KIBITZER]             = [];
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

sub _add_object_to_array {
    @_ == 4 || badinvo;
    my ($self, $otype, $ix, $obj) = @_;

    $obj->isa($otype)
	or xconfess "wrong object type ", dstr $obj;
    push @{ $self->[$ix] }, $obj;
}

sub add_kibitzer {
    @_ == 2 || badinvo;
    my ($self, $kibitzer) = @_;

    require Game::ScepterOfZavandor::UI::Kibitzer; # squelch warning
    $self->_add_object_to_array(
    	    	Game::ScepterOfZavandor::UI::Kibitzer::,
		GAME_KIBITZER,
		$kibitzer);
}

sub add_player {
    @_ == 2 || badinvo;
    my ($self, $player) = @_;

    $self->_add_object_to_array(
    	    	Game::ScepterOfZavandor::Player::,
		GAME_PLAYER_TABLE_ORDER,
		$player);
}

sub new_ui {
    @_ >= 2 || badinvo;
    my ($self, $type, @arg) = @_;

    my $ui_class = "Game::ScepterOfZavandor::$type";
    eval "require $ui_class";
    die if $@;

    my $ui = $ui_class->new($self, @arg);
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

    my %all_c = map { $_ => 1 } 0..$#Character;
    if ($self->option(OPT_NO_DRUID)
	    && ($self->option(OPT_DUPLICATE_CHARACTERS)
    	    	    || $self->num_players < keys %all_c)) {
	delete $all_c{+CHAR_DRUID};
    }

    # assign characters already chosen

    my %avail_c = %all_c;
    for my $player ($self->players_in_table_order) {
    	my $c = $player->a_char_preference;
	if (defined $c) {
	    $player->init($c);
	    delete $avail_c{$c};
	}
    }

    # assign other characters

    if ($self->option(OPT_CHOOSE_CHARACTER)) {
    	my $player_num = 0;
	for my $player (shuffle $self->players_in_table_order) {
	    $player_num++;
	    next if defined $player->a_char;
	    %avail_c = %all_c
		if $self->option(OPT_DUPLICATE_CHARACTERS);
	    my $c = $player->a_ui->choose_character($player_num,
					sort { $a <=> $b } keys %avail_c);
	    if (!defined $c) {
	    	my @c = keys %avail_c;
		$c = $c[rand @c];
	    }
	    if (!delete $avail_c{$c}) {
		xconfess "player $player_num chose bad character ", dstr $c;
	    }
	    # XXX borked
	    $self->note_to_players(NOTE_CHOSE_CHARACTER, $player_num, $c);
	    $player->init($c);
	}
    }
    else {
	my @c = shuffle keys %avail_c;
	for my $player ($self->players_in_table_order) {
	    next if defined $player->a_char;
	    @c = shuffle keys %all_c
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

    for ($self->kibitzers, map { $_->a_ui } $self->players_in_table_order) {
	$_->ui_note_global(@rest);
    }
}

#------------------------------------------------------------------------------

sub play {
    @_ == 1 || badinvo;
    my ($self) = @_;

    $self->note_to_players(NOTE_GAME_START);
    while (1) {
	# XXX
	#$Storable::forgive_me = 1;
	#Game::ScepterOfZavandor::Undo::store $self, 't.storable';

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

    if (!$start_player->allowed_to_start_auction($auc)) {
    	die "$start_player isn't currently allowed to start an auction for $auc";
    }

    if (!$start_player->allowed_to_own_auctionable($auc)) {
    	die "$start_player isn't allowed to own $auc";
    }

    $self->note_to_players(NOTE_AUCTION_START, $start_player, $auc, $start_bid);

    my $cur_bid    = $start_bid;
    my $cur_winner = $start_player;

    my @bidder = $self->players_in_turn_order;

    @bidder = grep { $_->allowed_to_own_auctionable($auc) } @bidder;

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

sub kibitzers {
    @_ == 1 || badinvo;
    my ($self) = @_;

    return @{ $self->[GAME_KIBITZER] };
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

sub prompt_for_players {
    @_ == 2 || badinvo;
    my $self = shift;
    my $ui   = shift;

    my $none   = 'none';
    my $human  = 'human';
    my $random = 'random';
    my $ai     = 'AI::Naive';

    my @ui_choices = ('none', $human, $ai);
    my @ui         = ($none) x $Max_players;
    my @char       = (undef) x $Max_players;

    $ui[0] = $human;
    $ui[1] = 'AI::Naive';
    while (1) {
	my $w = 20;
	$ui->out("\n");
	$ui->out("Players:\n");
	$ui->out("\n");
	$ui->out(" 1-$Max_players. configure for N player game with 1 human\n");
	$ui->out("\n");
	$ui->out(sprintf "      %-${w}s     %-${w}s\n", 'player type', 'character');
	$ui->out(sprintf "      %-${w}s     %-${w}s\n", '-----------', '---------');
	for my $ix (0..$Max_players - 1) {
	    $ui->out(sprintf "  %2d. %-${w}s %2d. %s\n",
	    	    	$ix+1+$Max_players, $ui[$ix],
			$ix+1+$Max_players*2,
			    $ui[$ix] eq $none
				? $none
				: defined $char[$ix]
				    ? $Character[$char[$ix]]
				    : $random);
	}

	my $i = $ui->prompt("Type the number of the item to change, "
				. "or Enter to continue: ",
			    ["", 1..$Max_players * 3]);
	last unless defined $i && $i ne '';

	if ($i <= $Max_players) {
	    my $pl = $i;
	    $ui[0] = $human;
	    for (2..$Max_players) {
	    	$ui[$_-1] = $_ <= $pl ? $ai : $none;
	    }
	}

	elsif ($i <= 2*$Max_players) {
	    my $pl = $i - $Max_players;
	    # XXX use prompt_for_index
	    $ui->out("\n");
	    $ui->out("Player types:\n");
	    for (0..$#ui_choices) {
		$ui->out(sprintf "    %d. %s\n", $_+1, $ui_choices[$_]);
	    }
	    my $i = $ui->prompt("Type the number type for player $pl, "
				. "or Enter to leave unchanged: ",
				    ["", 1..@ui_choices]);
    	    if ($i ne '') {
	    	$ui[$pl-1] = $ui_choices[$i-1];
	    }
	}

	else {
	    my $pl = $i - 2*$Max_players;
	    $char[$pl-1] = $ui->choose_character($pl, 0..$#Character);
	}
    }

    for (0..$#ui) {
    	my $ui_name = $ui[$_];
    	next if $ui_name eq $none;
	my @arg = ($ui_name eq $human)
		    ? ("UI::ReadLine", *STDIN, *STDOUT)
		    : ($ui_name);
	my $ui = $self->new_ui(@arg);
	if ($ui->can('a_suppress_global_messages')) {
	    $ui->a_suppress_global_messages(1);
	}
	$self->add_player(
		Game::ScepterOfZavandor::Player->new($self, $ui, $char[$_]));
    }
}

sub run_game_prompt_for_info {
    @_ == 2 || badinvo;
    my ($self, $ui) = @_;

    $ui->out("The Scepter of Zavandor\n");
    # XXX set up web site
    # XXX add this link to help
    #$ui->out("more info at http://www.argon.org/zavandor/\n");

    # XXX take options and user choices as an arg, store last time's in
    # a cookie or from command line

    $self->prompt_for_players($ui);
    $self->prompt_for_options($ui);
}

sub run_game {
    my @ui = @_;

    my $g = Game::ScepterOfZavandor::Game->new;

    my $ui = $g->new_ui("UI::Kibitzer", *STDIN, *STDOUT);
    $g->add_kibitzer($ui);

    $g->run_game_prompt_for_info($ui);
    $g->init;
    $g->play;
}


#------------------------------------------------------------------------------

1
