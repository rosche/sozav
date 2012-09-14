# $Id: Human.pm,v 1.1 2012-09-14 01:16:54 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Human;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 	qw(add_array_indices debug
		    make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr process_arg_pairs xconfess);
use List::Util	qw(max);

use Game::ScepterOfZavandor::Constant	qw(
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
    my @g = sort { $Gem_data[$a->a_gem_type][GEM_DATA_COST]
		    <=> $Gem_data[$b->a_gem_type][GEM_DATA_COST] }
		grep { !$num_active{$_->a_gem_type}++ }
		    $self->a_player->active_gems;

    if (!@g || @g == 1) {
	return $g[0];
    }

    my (@kv, %abbrev_to_gem);
    for (@g) {
	my $gtype  = $_->a_gem_type;
	my $abbrev = $Gem_data[$gtype][GEM_DATA_ABBREV];
	$abbrev_to_gem{$abbrev} = $_;
	my $desc = $Gem[$gtype];
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

    my $cur_player = $self->a_player;
    # XXX note your discounts/penalties
    $self->out("Current bid on ", $auc->a_data_name,
		" is $cur_bid by $cur_winner.\n");
    return $self->in("$cur_player:  Your bid (0 to pass)? ");
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
#    	unless $self->a_player && $player == $self->a_player;
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
    	unless $self->a_player && $player == $self->a_player;
    $self->info($player->name, " started auction for ",
		$auc->a_data_name, " with bid of $bid\n");

    # A sentinel won't have been in the standard display of
    # auctionables, so show the details.

    if ($auc->is_sentinel) {
    	$self->info("$auc\n");
    }
}

sub ui_note_auction_bid {
    @_ == 4 || badinvo;
    my ($self, $player, $auc, $bid) = @_;
    $self->info($player->name, " bid $bid for ", $auc->a_data_name, "\n");
}

sub ui_note_auction_won {
    @_ == 4 || badinvo;
    my ($self, $player, $auc, $bid) = @_;
    $self->info($player->name, " won ", $auc->a_data_name, " for $bid\n");
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

sub ui_note_not_using_best_gems {
    @_ == 3 || badinvo;
    my ($self, $ractivate, $rdeactivate) = @_;
    $self->info($self->a_player, " not using best gems, suggest ",
		join ", ",
		    (@$rdeactivate ? "dropping @$rdeactivate" : ()),
		    (@$ractivate   ? "adding @$ractivate" : ()));
}

sub ui_note_invalid_bid {
    @_ == 4 || badinvo;
    my ($self, $auc, $cur_bid, $new_bid) = @_;
    $self->info($self->a_player,
	" made an invalid bid (current bid $cur_bid, your bid $new_bid)\n");
}

#------------------------------------------------------------------------------

1
