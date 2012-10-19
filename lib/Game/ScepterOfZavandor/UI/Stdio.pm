# XXX some of the code here should likely be shared with non-Stdio UIs.

use strict;

package Game::ScepterOfZavandor::UI::Stdio;

use base qw(Game::ScepterOfZavandor::UI::Human);

use Game::Util		qw(add_array_indices add_array_indices
			    debug eval_block same_referent valid_ix_plus_1);
use List::Util		qw(first);
use RS::Handy		qw(badinvo data_dump dstr plural subname xconfess);
use Scalar::Util	qw(looks_like_number);
use Symbol		qw(qualify_to_ref);
use Term::ANSIColor	qw(color);

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^ENERGY_EST_/
    /^GAME_GEM_DATA_/
    /^GEM_/
    /^GEM_DATA_/
    /^KNOW_DATA_/
    /^OPT_/
    @Energy_estimate
    $Game_end_sentinels_sold_count
    @Gem
    %Gem
    @Gem_data
    @Knowledge
    %Knowledge
    @Knowledge_data
    @Sentinel_real_ix_xxx
);

our $Indent = "  ";
our %Action;
our %Action_abbrev;
our @Action_group;

BEGIN {
    add_array_indices 'UI', map { "STDIO_$_" } qw(IN_FH OUT_FH);

    add_array_indices 'ACTION', qw(
	ABBREV
	GROUP
	ARG
	DESC
    );

    @Action_group = qw(
	gem
	knowledge
	auction
	other
    );
    add_array_indices 'ACTION_GROUP', @Action_group;
}

sub new {
    @_ == 4 || badinvo;
    my ($class, $game, $in_fh, $out_fh) = @_;

    my $self = $class->SUPER::new($game);
    $self->[UI_STDIO_IN_FH ] = qualify_to_ref $in_fh , scalar caller;
    $self->[UI_STDIO_OUT_FH] = qualify_to_ref $out_fh, scalar caller;

    my $old = select $out_fh;
    $| = 1;
    select $old;

    return $self;
}

sub in {
    @_ == 1 || @_ == 2 || badinvo;
    my $self   = shift;
    my $prompt = shift;

    $self->out($prompt)
	if defined $prompt;
    my $s = readline $self->[UI_STDIO_IN_FH];
    if (!defined $s) {
	die "eof";
    }
    $self->log_out($s);
    chomp $s;
    return $s;
}

sub out {
    @_ || badinvo;
    my $self = shift;

    $self->log_out(@_);
    print { $self->[UI_STDIO_OUT_FH] } @_
	or die "error writing: $!";
}

sub out_error {
    @_ || badinvo;
    my $self = shift;
    $self->out(color('red'), 'ERROR: ', @_, color('reset'));
}

sub out_notice {
    @_ || badinvo;
    my $self = shift;
    $self->out(color('bold'), 'NOTICE: ', @_, color('reset'));
}

sub out_char {
    @_ || badinvo;
    my $self = shift;

    $self->out($self->a_player->name, " ", @_);
}

sub munge_action_name {
    my $s = shift;
    $s =~ tr/-/_/;
    return $s;
}

sub unmunge_action_name {
    my $s = shift;
    $s =~ tr/_/-/;
    return $s;
}

sub underline {
    @_ == 2 || badinvo;
    my $self = shift;
    my $s    = shift;

    # underline doesn't show in Window's telnet
    return color('bold') . $s . color('reset');
}

#------------------------------------------------------------------------------

sub add_action {
    @_ == 5 || badinvo;
    my ($name, $abbrev, $group, $rarg, $rdesc) = @_;

    if ($Action{$name}) {
	xconfess "duplicate action $name";
    }

    my $r = $Action{$name} = [];
    $r->[ACTION_ABBREV] = $abbrev;
    $r->[ACTION_GROUP]  = $group;
    $r->[ACTION_ARG]    = $rarg;
    $r->[ACTION_DESC]   = $rdesc;

    if (defined $abbrev) {
	if (exists $Action_abbrev{$abbrev}) {
	    xconfess "abbrev collision for $abbrev";
	}
	$Action_abbrev{$abbrev} = $name;
    }
}

sub bad_action_invo {
    my ($self, $cmd, @arg) = @_;

    die "wrong number of arguments for $cmd\n",
    	color('reset'),
    	$self->_action_help_one_command($cmd, 0);
}

sub get_action_names {
    @_ == 1 || badinvo;
    my $class = shift;

    # sort in separate expression so it can't be in scalar context
    my @a = sort keys %Action;
    return @a;
}

#------------------------------------------------------------------------------

sub show_knowledge_advancement_costs {
    @_ == 1 || badinvo;
    my $self = shift;

    my @c = $self->a_player->knowledge_advancement_costs;
    my @s = map { sprintf "\$%2d %s",
		    $c[$_], $Knowledge_data[$_][KNOW_DATA_NAME] }
		grep { defined $c[$_] } 0..$#c;
    my $label = "Knowledge advancement:";
    for (@s) {
	$self->out($label, " $_\n");
	$label = ' ' x length $label;
    }
}

sub one_action {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->status_short;

    if (!$self->a_player->a_advanced_knowledge_this_turn) {
	$self->show_knowledge_advancement_costs;
    }

    my $s = $self->in;
    return unless defined $s && $s ne '';
    my ($cmd, @arg) = split ' ', $s;

    if (defined(my $c = $Action_abbrev{$cmd})) {
	$cmd = $c;
    }

    if (!$Action{$cmd}) {
	$self->out_char("invalid action ", dstr $cmd, "\n");
	return 1;
    }

    my $mcmd = munge_action_name $cmd;
    my $method = "action_$mcmd";
    if (!$self->can($method)) {
	xconfess "no method defined for action $mcmd";
    }

    my $ret = eval_block { $self->$method($cmd, @arg) };
    if ($@) {
	$self->out("\n", $self->a_player, ": ");
	$self->out_error($@);
	$ret = 1;
    }

    return $ret;
}

sub status_short {
    @_ == 1 || badinvo;
    my $self  = shift;

    $self->out("\n");

    $self->out("Turn ", $self->a_game->a_turn_num,
	       ", on auction:\n");
    if (my @a = $self->a_game->auctionable_artifacts) {
	for (0..$#a) {
	    my $a = $a[$_];
	    my $n = $_ + 1;
	    $self->out(sprintf "${Indent}%2d %s\n", $n, $a);
	}
    }
    else {
	$self->out("  nothing\n");
    }

    $self->out("Status:             | know   |\n");

    my $knowledge_title = "";
    for (@Knowledge_data) {
	$knowledge_title .= $_->[KNOW_DATA_ABBREV];
    }

    my $header = '';
    for my $p ($self->a_game->players_in_table_order) {
	my $rel = sub {
	    my ($cur, $max) = @_;
	    my $fmt = "%2d";
	    my @arg = ($cur);
	    $fmt .= sprintf "%-5s",
			$cur == $max
			    ? ""
			    : sprintf "(%+d)", $cur - $max;
	    return $fmt, @arg;
	};

	my $do_highlight = same_referent $p, $self->a_player;
	my @spec = (
	    [""        => "", "%1s", $do_highlight ? ">" : " "],
	    [name      => "", "%-10.10s",
			    $p->name],
	    [vp        => " | ", "%2d(%d)",
			    $p->score, $p->user_turn_order],
	    [$knowledge_title => " | ", "%s",
			    $self->status_short_knowledge($p)],
	    [gems      => " | ", "%-11s",
			    $self->status_short_gems($p)],
	    [income    => " | ", join("/", ("%3.0f") x @Energy_estimate),
			    $p->income_estimate],
	    [cash      => " | ", "%-11s",
			    $self->status_short_cash($p)],
	    # XXX more useful to show how much energy you'd lose to your
	    # hand limit when you're over
	    [hand      => " | ", $rel->($p->current_hand_count, $p->hand_limit)],
	);

	my $s = '';
	for (@spec) {
	    my ($title, $sep, $this_fmt, @arg) = @$_;

	    my $formatted = sprintf $this_fmt, @arg;
	    $s .= $sep . $formatted;

	    if (defined $header) {
		my $l = length $formatted;
		#$title .= '-' while length($title) < length($formatted);
		$header .= $sep . sprintf "%-${l}s", $title;
	    }
	}
	$s .= "\n";
	if (defined $header) {
	    $self->out($header, "\n");
	    $header = undef;
	}
	if ($do_highlight) {
	    $self->out(color('bold'), $s, color 'reset');
	}
	else {
	    $self->out($s);
	}
    }
}

sub status_short_cash {
    @_ == 2 || badinvo;
    my $self = shift;
    my $p    = shift;

    if (same_referent $p, $self->a_player) {
	my @ed = $p->current_energy_detail;
	my $cash = $ed[CUR_ENERGY_CARDS_DUST];
	if (my $iag = $ed[CUR_ENERGY_INACTIVE_GEMS]) {
	    return sprintf "%3d+%3d=%3d", $iag, $cash, $cash+$iag;
	}
	else {
	    return sprintf "   \$%3d", $cash;
	}
    }

    my $visible_e;
    if ($p->player_can_see_my_cash($self->a_player)) {
	$visible_e = $p->current_energy_liquid;
    }
    else {
	my @ep = $p->current_energy_liquid_public;
	# show as exact if the value is actually visible
	if (!defined $ep[ENERGY_EST_MIN]) {
	    $visible_e = $ep[ENERGY_EST_AVG];
	}
	else {
	    return sprintf "" . join("/", ("%3.0f") x @Energy_estimate), @ep;
	}
    }

    return sprintf "   \$%3d", $visible_e;
}

sub status_short_gems {
    @_ == 2 || badinvo;
    my $self = shift;
    my $p    = shift;

    my $s = '';
    my @g = grep { $_->is_active } reverse $p->gems_by_cost;
    for (@g) {
	$s .= $_->abbrev;
    }
    for (@g+1 .. $p->num_gem_slots) {
	$s .= "-";
    }
    return $s;
}

sub status_short_knowledge {
    @_ == 2 || badinvo;
    my $self = shift;
    my $p    = shift;

    my $s = '';
    for my $ktype (0..$#Knowledge) {
	my $k = first { $_->ktype_is($ktype) } $p->knowledge_chips;
	$s .= !$k
		? '-'
		: $k->maxed_out
		    ? '*'
		    : $k->user_level;
    }
    return $s;
}

#------------------------------------------------------------------------------

sub _action_gem_backend {
    @_ >= 3 || badinvo;
    my $self  = shift;
    my $gname = shift;
    my $code  = shift;
    my @gem   = @_;

    my $gtype = $Gem{$gname};
    if (!defined $gtype) {
	die "invalid gem name ", dstr $gname, "\n";
    }

    my ($gem) = grep { $_->a_gem_type == $gtype } @gem;
    if (!$gem) {
	die "no appropriate $gname found\n";
    }

    $code->($gem);
}

add_action (
    'activate-gem',
    undef,
    ACTION_GROUP_GEM,
    ["gem-name"],
    [
	"- activate an inactive gem from your pentagon",
	"- you don't ordinarily have to do this, it's only necessary",
	"  if you've used the deactivate-gem command",
    ],
);

sub action_activate_gem {
    @_ == 3 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    my $gname = shift;

    $self->a_player->num_free_gem_slots
	or die "no free gem slots\n";

    $self->_action_gem_backend($gname, sub {
	    my $gem = shift;
	    $self->a_player->a_auto_activate_gems(0);
	    $gem->activate;
	}, $self->a_player->inactive_gems);

    return 1;
}

add_action (
    'advance-knowledge',
    'k',
    ACTION_GROUP_KNOWLEDGE,
    ["[knowledge-track]"],
    [
	"- advance the given knowledge track",
	"- no need to specify the track if you have only one to advance",
    ],
);

sub action_advance_knowledge {
    @_ == 2 || @_ == 3 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    my $kname_or_type = shift;

    my $ktype;
    if (!defined $kname_or_type) {
	$ktype = $self->choose_knowledge_type_to_advance;
	if (!defined $ktype) {
	    die "no advancable knowledge chips\n";
	}
    }
    else {
	$ktype = $Knowledge{$kname_or_type};
	if (!defined $ktype) {
	    valid_ix_plus_1 $kname_or_type, \@Knowledge
		or die "invalid knowledge track ", dstr $kname_or_type, "\n";
	    $ktype = $kname_or_type - 1;
	}
    }

    $self->a_player->advance_knowledge($ktype, 0);
    return 1;
}

add_action (
    'auto-activate-gems',
    undef,
    ACTION_GROUP_GEM,
    [],
    [
	"- automatically activate your best gems, now and later as necessary",
	"- you don't ordinarily have to do this, it's only necessary",
	"  if you've used the activate-gem or deactivate-gem commands",
    ],
);

sub action_auto_activate_gems {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;

    $self->a_player->a_auto_activate_gems(1);
    $self->a_player->auto_activate_gems;
    return 1;
}

add_action (
    'auction',
    "a",
    ACTION_GROUP_AUCTION,
    ["item-number", "[starting-bid]"],
    [
	"- start an auction for the given item",
	"- if the price isn't given the minimum bid is used",
	"- the item-number can be either an artifact or a sentinel",
    ],
);
sub action_auction {
    @_ == 3 || @_ == 4 || shift->bad_action_invo(@_);
    my $self      = shift;
    my $cmd       = shift;
    my $aix       = shift;
    my $start_bid = shift;

    my @a = $self->a_game->auctionable_items;
    $aix >= 1 && $aix <= @a
	or die "invalid auction index ", dstr $aix, "\n";
    my $auc = $a[$aix - 1];
    $start_bid = $auc->a_data_min_bid
	if !defined $start_bid;

    if (!defined $self->vet_bid($auc, $start_bid)) {
	return 1;
    }
    $self->a_game->auction_item($self->a_player, $auc, $start_bid);
    return 1;
}

add_action (
    'buy-knowledge-chip',
    "c",
    ACTION_GROUP_KNOWLEDGE,
    ["[cost]"],
    [
	"- buy the knowledge chip with the given cost",
	"- if the cost isn't given you buy your cheapest one",
    ],
);

sub action_buy_knowledge_chip {
    @_ == 2 || @_ == 3 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    my $cost = shift;

    my $kchip;
    if (defined $cost) {
	looks_like_number $cost
	    or die "invalid-looking knowledge chip cost ", dstr $cost, "\n";
	$kchip = first { $_->a_cost == $cost }
		$self->a_player->knowledge_chips_unbought_by_cost
	    or die "no unbought chip with cost $cost\n";
    }
    else {
	($kchip) = $self->a_player->knowledge_chips_unbought_by_cost
	    or die "no unbought chips\n";
    }
    $self->a_player->buy_knowledge_chip($kchip, 0);
    return 1;
}

add_action (
    'deactivate-gem',
    undef,
    ACTION_GROUP_GEM,
    ["gem-type"],
    [
	"- move a gem to your pentagon (making it available as liquid energy)",
	"- once you deactivate a gem you have to manage activating and",
	"  deactivating gems yourself from then on (but the game will give",
	"  you a notice when you aren't using your best gems)",
    ],
);

sub action_deactivate_gem {
    @_ == 3 || shift->bad_action_invo(@_);
    my $self  = shift;
    my $cmd   = shift;
    my $gname = shift;

    $self->_action_gem_backend($gname, sub {
	    my $gem = shift;
	    $self->a_player->a_auto_activate_gems(0);
	    $gem->deactivate;
	}, $self->a_player->active_gems);

    return 1;
}

#sub action_done {
#    @_ == 1 || shift->bad_action_invo(@_);
#    my $self = shift;
#
#    return 0;
#}
#*action_d = \&action_done;

add_action (
    'gem-info',
    undef,
    ACTION_GROUP_GEM,
    [],
    [
	"- list your gem purchase and sale prices, plus gem energy stats",
    ],
);

sub action_gem_info {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;

    $self->out_char("gem info:\n");
    # XXX show gem knowledge level
    for my $gtype (0..$#Gem) {
	$self->out(sprintf "  %8s  cost %2d  value %2d  energy %s\n",
			    $Gem[$gtype],
			    $self->a_player->gem_cost($gtype),
			    $self->a_player->gem_value($gtype),
			    $self->a_game->gem_energy_desc($gtype));
    }
    return 1;
}

# XXX quit/exit command

sub _action_help_one_command {
    @_ == 3 || badinvo;
    my $self  = shift;
    my $name  = shift;
    my $brief = shift;

    my $ra = $Action{$name};
    my $out = '';

    my $abbrev = $ra->[ACTION_ABBREV];
    if (defined $abbrev) {
	# XXX lousy solution for ?
	$name .= " (or $abbrev)" if $abbrev eq "?";
	$out .= $self->tag_abbrev($name, $abbrev);
    }
    else {
	$out .= $name;
    }

    my $rarg = $ra->[ACTION_ARG];
    for (@$rarg) {
	$out .= " $_";
    }
    $out .= "\n";

    if (!$brief) {
	for (@{ $ra->[ACTION_DESC] }) {
	    $out .= "$Indent$_\n";
	}
    }

    return $out;
}

sub _action_help_backend {
    @_ == 2 || badinvo;
    my $self  = shift;
    my $brief = shift;

    my $i = $Indent;

    $self->out("Actions/commands:\n");
    for my $group (0..$#Action_group) {
	$self->out("${i}$Action_group[$group]:\n");
	for my $name (grep { $Action{$_}[ACTION_GROUP] == $group }
			sort $self->get_action_names) {
	    my $out = $self->_action_help_one_command($name, $brief);
	    $out =~ s/^/$i$i/mg;
	    $self->out($out);
	}
    }

    $self->out("${i}<Enter> on a blank line ends this player's turn.\n");

    if ($brief) {
	$self->out("${i}Type \"$Action{help}[ACTION_ABBREV]\" for more detailed help.\n");
    }

    if (!$brief) {
	$self->out("\n");
	$self->out("${i}You can use the Tab key to complete command names.\n");
	$self->out(qq(${i}Eg, type "d" then Tab for "deactivate-gem".\n));
    }


    $self->out("\n");
    $self->out("${i}            Gem names: ",
	join(" ", map {
	    # XXX sub for this
	    $self->tag_abbrev($Gem[$_], $Gem_data[$_][GEM_DATA_ABBREV])
	} 0..$#Gem), "\n");
    $self->out("${i}Knowledge track names: ",
	join(" ", map {
	    # XXX sub for this
	    $self->tag_abbrev($Knowledge[$_],
				$Knowledge_data[$_][KNOW_DATA_ABBREV])
	} 0..$#Knowledge), "\n");

    my $fmt = ${i} x 3 . "%4s %-31s %6s %s\n";
    $self->out("${i} Player status legend:\n");
    $self->out(sprintf $fmt,
		"vp",     "= victory points(turn order)",
		"income", "= min/average/max",
	    );
    $self->out(sprintf $fmt,
		"know", "= knowledge levels",
		"cash", "= min/average/max, \$exact,",
	    );
    $self->out(sprintf $fmt,
		"gems",  "= active gem/empty slot list",
		"    ",  "  or inactive gems+cash=total",
	    );
    $self->out(sprintf $fmt,
		"    ",  "",
		"hand",  "= hand size(vs limit)",
	    );

    if ($self->can_underline && !$brief) {
	$self->out("\n");
	$self->out("${i}You can use abbreviations which are noted ", $self->underline("like this"), ".\n");
	$self->out(qq(${i}Eg, "b o" will buy an opal.\n));
    }


    return 1;
}

add_action (
    'help',
    "h",
    ACTION_GROUP_OTHER,
    [],
    [
	"- list commands with descriptions",
    ],
);

sub action_help {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    return $self->_action_help_backend(0);
}

add_action (
    'help-brief',
    "?",
    ACTION_GROUP_OTHER,
    [],
    [
	"- list commands briefly",
    ],
);

sub action_help_brief {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    return $self->_action_help_backend(1);
}

add_action (
    'items',
    "i",
    ACTION_GROUP_OTHER,
    ["[player-number]"],
    [
	"- list a player's items and some other info",
	"- shows your own stuff if no player-number is given",
	"- first player in status list is 1, second is 2, etc.",
    ],
);

sub action_items {
    @_ == 2 || @_ == 3 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    my $pnum = shift;

    my $player;
    if (!defined $pnum) {
	$player = $self->a_player;
    }
    else {
	my @p = $self->a_game->players_in_table_order;
	my $pix = $pnum - 1;
	if (!looks_like_number $pnum || $pix < 0 || $pix > $#p) {
	    die "invalid player number ", dstr $pnum,
		" (valid values are 1-", 0+@p, ")\n";
	}
	$player = $p[$pix];
    }

    my $game   = $self->a_game;
    my $name   = $player->name;
    my $indent = "  ";
    my $fmt    = "$indent%10s:";

    # XXX How many of each kind of card left in the decks?  This would
    # be the only non-player output in this display.  A similar item is
    # how many sentinels have been bought.

    $self->out(sprintf "$fmt %s (number %d in table order)\n",
			"player",
			$name,
			$player->a_table_ordinal);

    $self->out(sprintf "$fmt %d (%d from gems, position #%d)\n",
			"score",
			$player->score,
			$player->score_from_gems,
			$player->user_turn_order);

    $self->out(sprintf "$fmt %s\n",
			"gems",
			$self->status_short_gems($player));

    $self->out(sprintf "$fmt %d (%d used)\n",
			"hand limit",
			$player->hand_limit,
			$player->current_hand_count);

    if ($player->player_can_see_my_cash($self->a_player)) {
	my @e = $player->current_energy_detail;
	$self->out(sprintf "$fmt %d liquid (%d cash + %d from inactive gems)\n",
			    "energy",
			    @e[CUR_ENERGY_LIQUID,
				CUR_ENERGY_CARDS_DUST,
				CUR_ENERGY_INACTIVE_GEMS]);
	$self->out(sprintf "$fmt %d including active gems\n",
			    "energy",
			    $e[CUR_ENERGY_TOTAL]);
    }
    else {
	$self->out(sprintf "$fmt %s liquid visible\n",
			    "energy",
			    $self->status_short_cash($player));
	# XXX count from gems
    }

    if ($game->option(OPT_ANYBODY_LEVEL_3_RUBY)
	    || ($player->a_char == CHAR_DRUID
		&& $game->option(OPT_DRUID_LEVEL_3_RUBY))) {
	$self->out(sprintf "$fmt %s bought a ruby\n",
			    "ruby",
			    $player->a_bought_ruby ? "has" : "has not");
    }

    #$self->out("\n");
    $self->out("items:\n");
    for (sort { $a <=> $b } $player->items) {
	# XXX hide non-public info for other players
	$self->out(sprintf "%s%s\n", $indent,
		    same_referent($player, $self->a_player)
			? "$_"
			: $_->as_string_public_info);
    }
    return 1;
}

add_action (
    'buy-gem',
    "b",
    ACTION_GROUP_GEM,
    ["gem-type"],
    [
	"- buy a gem",
    ],
);

sub action_buy_gem {
    @_ == 3 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;
    my $gname = shift;

    my $gtype = $Gem{$gname};
    if (!defined $gtype) {
	die "invalid gem name ", dstr $gname, "\n";
    }

    $self->a_player->buy_gem($gtype);
    return 1;
}

add_action (
    'sell-gem',
    undef,
    ACTION_GROUP_GEM,
    ["gem-type"],
    [
	"- sell a gem for magic dust",
	"- you don't normally have to do this, your inactive gems will be",
	"  sold automatically as necessary",
    ],
);

sub action_sell_gem {
    @_ == 3 || shift->bad_action_invo(@_);
    my $self  = shift;
    my $cmd  = shift;
    my $gname = shift;

    my $gtype = $Gem{$gname};
    if (!defined $gtype) {
	die "invalid gem name ", dstr $gname, "\n";
    }

    # XXX let user pick
    #
    # XXX or at least prefer inactive ones (though the auto-activate
    # makes this non-critical)

    my ($gem)
	# XXX test
	= sort { !!$a->is_active <=> !!$b->is_active }
	    grep { $_->a_gem_type == $gtype } $self->a_player->gems;
    if (!$gem) {
	die "you don't own a $gname\n"; # XXX grammar
    }

    $self->a_player->add_items(
	Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
	    $self->a_player, $self->a_player->spend($gem)));
    $self->a_player->auto_activate_gems;

    return 1;
}

add_action (
    'sentinels',
    "s",
    ACTION_GROUP_AUCTION,
    [],
    [
	"- list the sentinels available for auction",
    ],
);

sub action_sentinels {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;

    my $player = $self->a_player;

    $self->out("Sentinels available for auction:\n");

    my @a = $player->a_game->auctionable_items;
    my $s_available = 0;

    for (0..$#a) {
	my $a = $a[$_];
	next unless $a->is_sentinel;
	$s_available++;
	my $n = $_ + 1;
	$self->out(sprintf "${Indent}%2d %s\n", $n, $a);
    }
    if (!$s_available) {
	$self->out("${Indent}none!\n");
    }

    my $s_purchased = @Sentinel_real_ix_xxx - $s_available;
    my $s_to_go     = $Game_end_sentinels_sold_count - $s_purchased;
    # XXX negative $s_to_go
    $self->out($s_purchased, " sentinel", plural($s_purchased),
		" have been purchased ($s_to_go more to end the game)\n");

    return 1;
}

add_action (
    'test',
    undef,
    ACTION_GROUP_OTHER,
    [],
    [
	"- ignore, used during development",
    ],
);

sub action_test {
    @_ == 2 || shift->bad_action_invo(@_);
    my $self = shift;
    my $cmd  = shift;

    $self->out(sprintf "You %s have unbought knowledge chips.\n",
		$self->a_player->knowledge_chips_unbought_by_cost
		    ? "do" : "do not");
    return 1;
}

#------------------------------------------------------------------------------

1

# XXX better completion (gem names, etc)
