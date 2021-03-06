use strict;

package Game::ScepterOfZavandor::UI::Human;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util	qw(add_array_indices debug
		    make_ro_accessor make_rw_accessor same_referent);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);
use List::Util	qw(max);

use Game::ScepterOfZavandor::Constant	qw(
    /^CUR_ENERGY_/
    /^GEM_DATA_/
    /^KNOW_DATA_/
    @Character
    @Gem
    @Gem_data
    @Knowledge_data
    @Option
);

BEGIN {
    add_array_indices 'UI', qw(SUPPRESS_GLOBAL_MESSAGES);
}

make_rw_accessor (
    a_suppress_global_messages => UI_SUPPRESS_GLOBAL_MESSAGES,
);

# Abstract methods:
#    in
#    out
#    out_error
#    out_notice

sub info {
    my $self = shift;
    #$self->out($self->a_id, ": ", @_);
    $self->out("- ", @_);
}

sub can_underline {
    @_ == 1 || badinvo;
    return $_[0]->underline("hi mom") ne "hi mom";
}

sub underline {
    @_ == 2 || badinvo;
    return $_[1];
}

# semi-generic methods --------------------------------------------------------

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

# Prompt for a key, giving a the user an ordered list of key/value pairs
# to choose from.

sub prompt_for_key {
    @_ >= 3 || badinvo;
    my $self     = shift;
    my $prompt   = shift;
    my $rkvlist  = shift;
    my @opt      = @_;

    process_arg_pairs \@opt, (
	allow_empty => \(my $allow_empty),
	header      => \(my $header),
	indent      => \(my $indent = ""),
	sep         => \(my $sep = ":"),
    );

    $self->out($header)
	if defined $header;

    my $width = max map { length $_->[0] } @$rkvlist;
    my @key;
    for (@$rkvlist) {
	push @key, $_->[0];
	$self->out(sprintf "%s%${width}s%s %s\n",
			    $indent, $key[-1], $sep, $_->[1]);
    }

    return $self->prompt($prompt, [@key, $allow_empty ? "" : ()]);
}

sub prompt_for_index {
    @_ >= 3 || badinvo;
    my $self   = shift;
    my $prompt = shift;
    my $rlist  = shift;
    my @opt    = @_;

    my $resp
	= $self->prompt_for_key($prompt,
				 [map { [$_+1 => $rlist->[$_]] } 0..$#$rlist],
				 sep => ".",
				 @opt);
    return $resp eq '' ? undef : $resp - 1;
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

# game-specific methods -----------------------------------------------------

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
    return defined $c ? $c[$c] : undef;
}

sub choose_active_gem {
    @_ == 2 || badinvo;
    my $self = shift;
    my $verb = shift;

    my %num_active;
    my $p = $self->a_player;
    my @g = sort { $Gem_data[$a->a_gem_type][GEM_DATA_COST]
		    <=> $Gem_data[$b->a_gem_type][GEM_DATA_COST] }
		grep { !$num_active{$_->a_gem_type}++ }
		    $p->active_gems;

    if (!@g || @g == 1) {
	return $g[0];
    }

    my (@kv, %abbrev_to_gem);
    for (@g) {
	my $gtype  = $_->a_gem_type;
	my $abbrev = $Gem_data[$gtype][GEM_DATA_ABBREV];
	$abbrev_to_gem{$abbrev} = $_;
	my $desc = $Gem[$gtype];
	$desc .= sprintf " (\$%d/\$%d)",
		    $p->gem_cost($gtype), $p->gem_value($gtype);
	if ((my $n = $num_active{$gtype}) > 1) {
	    $desc .= " x$n";
	}
	push @kv, [$abbrev => $desc];
    }
    my $abbrev = $self->prompt_for_key(
		    "Choose active gem to $verb: ",
		    \@kv,
		    header => "Active gems:\n",
		    indent => "  ");
    return $abbrev_to_gem{$abbrev};
}

sub choose_active_gem_to_destroy {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->choose_active_gem("destroy");
}

sub choose_active_gem_to_sell {
    @_ == 2 || badinvo;
    my $self         = shift;
    my $amount_short = shift;

    $self->out("You need an extra \$$amount_short.\n");
    return $self->choose_active_gem("sell");
}

# XXX @Knowledge_data[] could use a simplified object-based interface

sub choose_knowledge_type_to_advance {
    @_ == 1 || badinvo;
    my $self = shift;

    my @cost              = $self->a_player->knowledge_advancement_costs;
    my @ktype_advanceable = grep { defined $cost[$_] } 0..$#cost;

    if (!@ktype_advanceable) {
	return;
    }

    if (@ktype_advanceable == 1) {
	return $ktype_advanceable[0];
    }

    my @kv = map { [$Knowledge_data[$_][KNOW_DATA_ABBREV]
			=> sprintf "\$%2d %s",
				$cost[$_],
				$Knowledge_data[$_][KNOW_DATA_NAME]]
		    } @ktype_advanceable;

    my $abbrev = $self->prompt_for_key(
		    "Choose knowledge type to advance: ",
		    \@kv,
		    header => "Advanceable knowledge types:\n",
		    indent => "  ");

    for (0..$#ktype_advanceable) {
	if ($kv[$_][0] eq $abbrev) {
	    return $ktype_advanceable[$_];
	}
    }
    die;
}

sub player_score_summary {
    @_ == 3 || badinvo;
    my ($self, $place, $player) = @_;

    my @r;
    push @r, sprintf "  %s. %3d %s\n",
		$place,
		$player->score,
		$player->name;
    for my $item (sort { $a <=> $b } grep { $_->vp } $player->items) {
	push @r, sprintf "%11s%s\n", "", $item;
    }

    return @r;
}

sub solicit_bid {
    @_ == 4 || badinvo;
    my ($self, $auc, $cur_bid, $cur_winner) = @_;

    my $p = $self->a_player;

    if ($cur_bid >= $p->auctionable_max_bid($auc)) {
	$self->out("You can't afford to bid.\n");
	return 0;
    }

    $self->out("Current bid on ", $auc->a_data_name,
		" is \$$cur_bid by $cur_winner.\n");
    my $mod = $p->auctionable_cost_mod($auc);
    if ($mod) {
	$self->out(sprintf "You have a net %s of \$%d on this item.  "
			    . "Your maximum (liquid) bid is \$%d.\n",
		    $mod < 0 ? ("discount", -$mod) : ("penalty", $mod),
		    $p->auctionable_max_bid_from_liquid($auc));
    }

    my $bid = undef;
    while (!defined $bid) {
	$bid = $self->in("$p:  Your bid (0 to pass)? ");
	$bid = $self->vet_bid($auc, $bid);
    }
    return $bid;
}

sub vet_bid {
    @_ == 3 || badinvo;
    my ($self, $auc, $bid) = @_;

    if ($bid !~ /^\d*$/) {
	$self->out("Invalid bid\n");
	return undef;
    }

    if ($bid eq '' || $bid == 0) {
	return 0;
    }

    my $p = $self->a_player;
    my $max_tot = $p->auctionable_max_bid($auc);
    if ($bid > $max_tot) {
	$self->out("You can't afford to bid over $max_tot.\n");
	return undef;
    }

    if (!$self->maybe_confirm_payment($bid + $p->auctionable_cost_mod($auc))) {
	return undef;
    }

    return $bid;
}

sub maybe_confirm_payment {
    @_ == 2 || badinvo;
    my ($self, $full_payment) = @_;

    if (!$self->SUPER::maybe_confirm_payment($full_payment)) {
	return 0;
    }

    my $to_pay = $full_payment;
    my @ed     = $self->a_player->current_energy_detail;

    $to_pay -= $ed[CUR_ENERGY_CARDS_DUST];
    if ($to_pay <= 0) {
	return 1;
    }

    my $to_sell_desc;
    for ([CUR_ENERGY_INACTIVE_GEMS, "\$%d worth of inactive gems"],
	 [CUR_ENERGY_ACTIVE_GEMS,   "\$%d worth of ACTIVE gems"]) {
	my ($ix, $fmt) = @$_;
	my $this = $ed[$ix];
	if ($to_pay <= $this) {
	    $to_sell_desc = sprintf $fmt, $to_pay;
	    last;
	}
	$to_pay -= $this;
    }
    if (!defined $to_sell_desc) {
	die; # can't happen
    }

    # XXX only require confirmation once when buying anything?  could
     # track based on the object being purchased

    my $conf = $self->in("This will require you to sell $to_sell_desc, "
			    . "type Y to confirm: ");
    return defined $conf && $conf =~ /^[Yy]$/;
}

#------------------------------------------------------------------------------

sub ui_note_global {
    my $self = shift;

    if ($self->a_suppress_global_messages) {
	return;
    }
    $self->SUPER::ui_note_global(@_);
}

sub ui_note_game_start {
    @_ || badinvo;
    my $self = shift;

    my $g = $self->a_game;
    $self->info("Game starting with ", 0+$g->players_in_table_order, " players\n");
    $self->info("\n");
    $self->info("Active options:\n");
    $self->info("  $Option[$_]\n")
	for grep { $g->option($_) } 0..$#Option;
    $self->info("\n");
    $self->info("Players:\n");
    $self->info(sprintf "  %s\n", $_->name)
	for $g->players_in_table_order;
}

sub ui_note_game_end {
    @_ || badinvo;
    my $self = shift;

    my $g = $self->a_game;

    $self->info("Game over after ", $self->a_game->a_turn_num, " turns\n");
    $self->info("\n");
    for ($g->players_by_rank) {
	$self->info($self->player_score_summary(@$_));
    }
    $self->in("Type Enter to exit game: ");
}

# XXX drop this
sub ui_note_info {
    my $self = shift;
    $self->info(@_);
}

sub ui_note_turn_start {
    @_ == 1 || badinvo;
    my $self = shift;

    my $g = $self->a_game;
    $self->info("-" x 77, "\n");
    $self->info(sprintf "Turn %s starting, player order: %s\n",
		    $g->a_turn_num,
		    join " ", $g->players_in_turn_order);
}

sub ui_note_actions_start {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $player = shift;

# XXX it'd be good to short this status only to kibitzers, but with my current
# interface I'm always a kibitizer
#    $self->status_short
#	unless same_referent $player, $self->a_player;
    $self->info($player->name, " starting actions\n");
}

sub ui_note_actions_end {
    @_ == 2 || badinvo;
    my $self   = shift;
    my $player = shift;
    $self->info($player->name, " done with actions\n");
}

sub ui_note_auction_start {
    @_ == 4 || badinvo;
    my ($self, $player, $auc, $bid) = @_;

    $self->status_short
	unless same_referent $player, $self->a_player;
    $self->info($player->name, " started auction for ",
		$auc->a_data_name, " with bid of \$$bid\n");

    # A sentinel won't have been in the standard display of
    # auctionables, so show the details.

    if ($auc->is_sentinel) {
	$self->info("$auc\n");
    }
}

sub ui_note_auction_bid {
    @_ == 4 || badinvo;
    my ($self, $player, $auc, $bid) = @_;
    $self->info($player->name,
		    $bid ? " bid \$$bid for " : " passed on ",
		    $auc->a_data_name, "\n");
}

sub ui_note_auction_won {
    @_ == 4 || badinvo;
    my ($self, $player, $auc, $bid) = @_;
    $self->info($player->name, " won ", $auc->a_data_name, " for \$$bid\n");
}

sub ui_note_chose_character {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $player_num = shift;
    my $char   = shift;
    $self->info("player $player_num chose character $Character[$char]\n");
}

sub ui_note_item_gone {
    @_ == 4 || badinvo;
    my $self   = shift;
    my $player = shift;
    my $item   = shift;
    my $cost   = shift;
    $self->info(sprintf "%s %s %s%s\n",
		$player,
		$cost
		    ? ("sold",  $item, " for \$$cost")
		    : ("lost",  $item, ""));
}

sub ui_note_item_got {
    @_ == 4 || badinvo;
    my $self   = shift;
    my $player = shift;
    my $item   = shift;
    my $cost   = shift;
    $self->info(sprintf "%s %s %s%s\n",
		$player,
		$cost
		    ? ("bought",   $item, " for \$$cost")
		    : ("received", $item, ""));
}

sub ui_note_gem_activate {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $player = shift;
    my $g      = shift;
    $self->info($player->name, " activated a $g\n");
}

sub ui_note_gem_deactivate {
    @_ == 3 || badinvo;
    my $self   = shift;
    my $player = shift;
    my $g      = shift;
    $self->info($player->name, " deactivated a $g\n");
}

sub ui_note_knowledge_advance {
    @_ == 4 || badinvo;
    my $self   = shift;
    my $player = shift;
    my $k      = shift;
    my $cost   = shift;
    $self->info($player->name, " advanced ",
		$k->name, " to level ", $k->user_level, " for \$$cost\n");
}

# single player ---------------------------------------------------------------

sub ui_note_cant_afford {
    @_ == 2 || badinvo;
    my ($self, $payment) = @_;
    $self->info("You can't afford a payment of \$$payment\n");
}

sub ui_note_not_using_best_gems {
    @_ == 3 || badinvo;
    my ($self, $ractivate, $rdeactivate) = @_;
    $self->info("You aren't using your best gems, suggest ",
		join ", ",
		    (@$rdeactivate ? "dropping @$rdeactivate" : ()),
		    (@$ractivate   ? "adding @$ractivate" : ()));
}

sub ui_note_invalid_bid {
    @_ == 4 || badinvo;
    my ($self, $auc, $cur_bid, $new_bid) = @_;
    $self->info("Your bid of $new_bid is invalid (current bid $cur_bid)\n");
}

#------------------------------------------------------------------------------

1
