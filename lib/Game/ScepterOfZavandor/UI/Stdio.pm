# $Id: Stdio.pm,v 1.18 2009-02-15 15:17:01 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Stdio;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 		qw(add_array_index add_array_indices
			    debug eval_block valid_ix_plus_1);
use List::Util		qw(first);
use List::MoreUtils	qw(natatime);
use RS::Handy		qw(badinvo data_dump dstr plural xconfess);
use Scalar::Util	qw(looks_like_number);
use Symbol		qw(qualify_to_ref);
use Term::ANSIColor	qw(color);

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^GAME_GEM_DATA_/
    /^GEM_/
    /^GEM_DATA_/
    /^KNOW_DATA_/
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
    add_array_index 'UI', $_ for map { "STDIO_$_" } qw(IN_FH OUT_FH);

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

sub get_action_names {
    @_ == 1 || badinvo;
    my $class = shift;

    return sort keys %Action;
}

#------------------------------------------------------------------------------

sub start_actions {
    @_ == 1 || badinvo;
    my $self = shift;

    my $player = $self->a_player;

    # Auto-activate gems to deal with losing something to a mirror/cloak,
    # or buying an elixir on somebody else's turn.

    $player->auto_activate_gems;
}

sub one_action {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->status_short;

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

    my $ret = eval_block { $self->$method(@arg) };
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

    # XXX I often want to know the next cost for my knowledge advancements

    $self->out("\n");

    $self->out("Turn ", $self->a_game->a_turn_num,
	       ", on auction:\n");
    if (my @a = grep { !$_->is_sentinel } $self->a_game->auction_all) {
	for (0..$#a) {
	    my $a = $a[$_];
	    my $n = $_ + 1;
	    my $mod = $self->a_player->auctionable_cost_mod($a);
	    $self->out(sprintf "${Indent}%2d %s%s\n", $n, $a,
	    	    	$mod == 0 ? "" : sprintf " (%+d)", $mod);
	}
    }
    else {
	$self->out("  nothing\n");
    }

    my $knowledge_title = "";
    for (@Knowledge_data) {
	$knowledge_title .= $_->[KNOW_DATA_ABBREV];
    }

    $self->out(sprintf "%-72s %s\n", "Player status:", $knowledge_title);
    for my $p ($self->a_game->players) {
    	my $knowledge = '';
	for my $ktype (0..$#Knowledge) {
	    my $k = first { $_->ktype_is($ktype) } $p->knowledge_chips;
	    $knowledge .= !$k
			    ? '-'
			    : $k->maxed_out
				? '*'
				: $k->user_level;
	}

	my $rel = sub {
	    my ($desc, $cur, $max) = @_;
	    my $fmt = " %s %2d";
	    my @arg = ($desc, $cur);
	    $fmt .= sprintf "%-5s",
			$cur == $max
    	    	    	    ? ""
    	    	    	    : sprintf "(%+d)", $cur - $max;
    	    return $fmt => \@arg;
    	};

    	my @spec = (

	    "%s"
		=> [$p == $self->a_player ? color('bold') . ">" : " "],

	    " %-6s"
		=> [$p->name],

	    " vp %2d(%d)"
		=> [$p->score,
		    $p->user_turn_order],

	    "  inc " . join("/", ("%3.0f") x @Energy_estimate)
		=> [$p->income_estimate],

	    "  \$%3d"
		=> [$p->current_energy_liquid],

	    # XXX more useful to show how much energy you'd lose to your
	    # hand limit when you're over
	    $rel->(" hand",
		    $p->current_hand_count,
		    $p->hand_limit),

	    $rel->("gems",
		    0+$p->active_gems,
		    $p->num_gem_slots),

	    " know %s"
		=> [$knowledge],

    	);

    	my $it = natatime 2, @spec;
	my ($fmt, @arg);
	while (my ($this_fmt, $r) = $it->()) {
	    $fmt .= $this_fmt;
	    push @arg, @$r;
	}
    	$self->out(sprintf "$fmt%s\n", @arg, color 'reset');
    }
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
	"- activate an enchanted (but inactive) gem from your pentagon",
	"- you don't ordinarily have to do this, it's only necessary",
    	"  if you've used the deactivate-gem command",
    ],
);

sub action_activate_gem {
    @_ == 2 || badinvo;
    my $self = shift;
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
    'a',
    ACTION_GROUP_KNOWLEDGE,
    ["[knowledge-track]"],
    [
	"- advance the given knowledge track",
	"- no need to specify the track if you have only one to advance",
    ],
);

sub action_advance_knowledge {
    @_ == 1 || @_ == 2 || badinvo;
    my $self  = shift;
    my $kname_or_type = shift;

    my $ktype;
    if (!defined $kname_or_type) {
	my @k = $self->a_player->knowledge_chips_advancable;
	if (@k == 0) {
	    die "no advancable knowledge chips\n";
	}
	elsif (@k > 1) {
	    die "multiple advancable knowledge chips\n";
	}
	$ktype = $k[0]->a_type;
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
    @_ == 1 || badinvo;
    my $self = shift;

    $self->a_player->a_auto_activate_gems(1);
    $self->a_player->auto_activate_gems;
    return 1;
}

add_action (
    'buy-auctionable',
    "b",
    ACTION_GROUP_AUCTION,
    ["item-number", "[price]"],
    [
	"- buy the given item (hold the actual auction in your head)",
	"- if the price isn't given the minimum bid is used",
	"- the item-number can be either an artifact or a sentinel",
    ],
);

sub action_buy_auctionable {
    @_ == 2 || @_ == 3 || badinvo;
    my $self  = shift;
    my $aix   = shift;
    my $price = shift;

    my @a = $self->a_game->auction_all;
    $aix >= 1 && $aix <= @a
    	or die "invalid auction index ", dstr $aix, "\n";

    my $auc = $a[$aix - 1];
    $price = $auc->get_min_bid
    	if !defined $price;
    $self->a_player->buy_auctionable($auc, $price);
    return 1;
}

add_action (
    'buy-knowledge-chip',
    "k",
    ACTION_GROUP_KNOWLEDGE,
    ["[cost]"],
    [
	"- buy the knowledge chip with the given cost",
	"- if the cost isn't given you buy your cheapest one",
    ],
);

sub action_buy_knowledge_chip {
    @_ == 1 || @_ == 2 || badinvo;
    my $self = shift;
    my $cost = shift;

    my $kchip;
    if (defined $cost) {
    	looks_like_number $cost
	    or die "invalid-looking knowledge chip cost ", dstr $cost, "\n";
	$kchip = first { $_->a_cost == $cost }
		$self->a_player->knowledge_chips_unbought
	    or die "no unbought chip with cost $cost\n";
    }
    else {
	($kchip) = $self->a_player->knowledge_chips_unbought
	    or die "no unbought chips\n";
    }
    $self->a_player->buy_knowledge_chip($kchip, 0);
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
    @_ == 2 || badinvo;
    my $self = shift;
    my $gname = shift;

    $self->_action_gem_backend($gname, sub {
	    my $gem = shift;
	    $self->a_player->a_auto_activate_gems(0);
	    $gem->deactivate;
	}, $self->a_player->active_gems);

    return 1;
}

#sub action_done {
#    @_ == 1 || badinvo;
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
    @_ == 1 || badinvo;
    my $self = shift;

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
	    my $ra = $Action{$name};

	    my $out = $i x 2;

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
	    $self->out($out, "\n");

	    if (!$brief) {
		for (@{ $ra->[ACTION_DESC] }) {
		    $self->out($i x 3, $_, "\n");
		}
	    }
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

    my $fmt = ${i} x 3 . "%4s = %-29s %4s = %s\n";
    $self->out("${i} Player status legend:\n");
    $self->out(sprintf $fmt,
    	    	"vp",  "victory points(turn order)",
    	    	"hand",  "hand size(vs limit)",
    	    );
    $self->out(sprintf $fmt,
		"inc",  "income min/average/max",
		"gems",  "active gems(vs slots)",
    	    );
    $self->out(sprintf $fmt,
		"\$",  "liquid energy",
    	    	"know",  "knowledge levels",
    	    );

    if ($self->can_underline && !$brief) {
	$self->out("\n");
	$self->out("${i}You can use abbreviations which are noted ", $self->underline("like this"), ".\n");
	$self->out(qq(${i}Eg, "e o" will enchant an opal.\n));
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
    @_ == 1 || badinvo;
    my $self = shift;
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
    @_ == 1 || badinvo;
    my $self = shift;
    return $self->_action_help_backend(1);
}

add_action (
    'items',
    "i",
    ACTION_GROUP_OTHER,
    [],
    [
	"- list your items and some other info",
    ],
);

sub action_items {
    @_ == 1 || badinvo;
    my $self = shift;

    my $player = $self->a_player;

    # XXX how many of each kind of card left?

    $self->out_char(" score: ", $player->score,
    	    	    " (", $player->score_from_gems, " from gems, ",
		    "position #", $player->user_turn_order, ")\n");

    # XXX hand limit, gem slots

    my @e = $player->current_energy;
    $self->out_char(sprintf "energy: %d total\n", $e[CUR_ENERGY_TOTAL]);
    $self->out_char(sprintf
	"energy: -> %d liquid (%d + %d from inactive gems)\n",
		    @e[CUR_ENERGY_LIQUID,
			CUR_ENERGY_CARDS_DUST,
			CUR_ENERGY_INACTIVE_GEMS]);
    $self->out_char(sprintf
	"energy: -> %d from active gems\n", $e[CUR_ENERGY_ACTIVE_GEMS]);
    # XXX option for anybody
    # XXX option disabled for druid
    if ($player->a_char == CHAR_DRUID) {
	$self->out_char(sprintf "%s enchanted a ruby\n",
			    $player->a_enchanted_ruby ? "has" : "has not");
    }
    $self->out_char("items:\n");
    for (sort { $a <=> $b } $player->items) {
	$self->out("  $_\n")
    }
    return 1;
}

add_action (
    'enchant-gem',
    "e",
    ACTION_GROUP_GEM,
    ["gem-type"],
    [
	"- enchant (buy) a gem",
    ],
);

sub action_enchant_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my $gname = shift;

    my $gtype = $Gem{$gname};
    if (!defined $gtype) {
    	die "invalid gem name ", dstr $gname, "\n";
    }

    $self->a_player->enchant_gem($gtype)
	or die "didn't get a gem back\n";
    $self->a_player->auto_activate_gems;

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
    @_ == 2 || badinvo;
    my $self  = shift;
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
    @_ == 1 || badinvo;
    my $self = shift;

    my $player = $self->a_player;

    $self->out("Sentinels available for auction:\n");

    my @a = $player->a_game->auction_all;
    my $s_available = 0;

    for (0..$#a) {
	my $a = $a[$_];
	next unless $a->is_sentinel;
    	$s_available++;
	my $n = $_ + 1;
	my $mod = $player->auctionable_cost_mod($a);
	$self->out(sprintf "${Indent}%2d %s%s\n", $n, $a,
		    $mod == 0 ? "" : sprintf " (%+d)", $mod);
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

#------------------------------------------------------------------------------

1

# XXX better completion (gem names, etc)
