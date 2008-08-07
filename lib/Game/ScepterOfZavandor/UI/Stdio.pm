# $Id: Stdio.pm,v 1.15 2008-08-07 11:08:16 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Stdio;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 		qw(add_array_index debug eval_block valid_ix_plus_1);
use List::Util		qw(first);
use List::MoreUtils	qw(natatime);
use RS::Handy		qw(badinvo data_dump dstr xconfess);
use Scalar::Util	qw(looks_like_number);
use Symbol		qw(qualify_to_ref);
use Term::ANSIColor	qw(color);

use Game::ScepterOfZavandor::Constant qw(
    /^CHAR_/
    /^CUR_ENERGY_/
    /^KNOW_DATA_/
    @Energy_estimate
    @Gem
    %Gem
    @Knowledge
    %Knowledge
    @Knowledge_data
);

BEGIN {
    add_array_index 'UI', $_ for map { "STDIO_$_" } qw(IN_FH OUT_FH);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $in_fh, $out_fh) = @_;

    my $self = $class->SUPER::new;
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
    chomp $s;
    return $s;
}

sub out {
    @_ || badinvo;
    my $self = shift;

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

sub action_names {
    @_ == 1 || badinvo;
    my $class = shift;

    my @name;
    my $rstash = do { no strict 'refs'; \%{ __PACKAGE__ . "::" } };
    for (grep { $class->can($_) } grep { /^action_/ } keys %$rstash ) {
	s/^action_// or die;
	tr/_/-/;
    	push @name, $_;
    }
    @name or xconfess;

    return @name;
}

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
    $cmd =~ tr/-/_/;
    my $method = "action_$cmd";
    if (!$self->can($method)) {
	$self->out_char("invalid action ", dstr $cmd, "\n");
	return 1;
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

    $self->out("\n");

    $self->out("Turn ", $self->a_player->a_game->a_turn_num,
	       ", on auction:\n");
    if (my @a = grep { !$_->is_sentinel } $self->a_player->a_game->auction_all) {
	for (0..$#a) {
	    my $a = $a[$_];
	    my $n = $_ + 1;
	    my $mod = $self->a_player->auctionable_cost_mod($a);
	    $self->out(sprintf "  %2d %s%s\n", $n, $a,
	    	    	$mod == 0 ? "" : sprintf " (%+d)", $mod);
	}
    }
    else {
	$self->out("  nothing\n");
    }

    my $knowledge_title = "";
    for (@Knowledge_data) {
	$knowledge_title .= $_->[KNOW_DATA_ALIAS];
    }

    $self->out(sprintf "%-10s %61s %s\n", "Players:", "", $knowledge_title);
    my $il = 2;
    for my $p ($self->a_player->a_game->players) {
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
*action_a = \&action_advance_knowledge;

sub action_buy_auctionable {
    @_ == 2 || @_ == 3 || badinvo;
    my $self  = shift;
    my $aix   = shift;
    my $price = shift;

    my @a = $self->a_player->a_game->auction_all;
    $aix >= 1 && $aix <= @a
    	or die "invalid auction index ", dstr $aix, "\n";

    my $auc = $a[$aix - 1];
    $price = $auc->get_min_bid
    	if !defined $price;
    $self->a_player->buy_auctionable($auc, $price);
    return 1;
}
*action_b = \&action_buy_auctionable;

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
*action_k = \&action_buy_knowledge_chip;

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

sub action_gem_info {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->out_char("gem info:\n");
    # XXX show gem knowledge level
    for my $gtype (0..$#Gem) {
    	my $cost = $self->a_player->gem_cost($gtype);
    	my $val  = $self->a_player->gem_value($gtype);
	$self->out(sprintf "  %8s  cost %2d  value %2d\n",
			    $Gem[$gtype], $cost, $val);
	# XXX min, max, average value
    }
    return 1;
}

sub action_help {
    @_ == 1 || badinvo;
    my $self = shift;

    $self->out("actions/commands:\n");
    for (sort $self->action_names) {
	$self->out("  $_\n");
	# XXX note aliases
    }
    return 1;
}
*action_h = \&action_help;

sub action_items {
    @_ == 1 || badinvo;
    my $self = shift;

    my $player = $self->a_player;

    # XXX how many of each kind of card left
    $self->out("on auction:\n");
    if (my @a = $player->a_game->auction_all) {
	for (0..$#a) {
	    my $a = $a[$_];
	    my $n = $_ + 1;
	    my $mod = $player->auctionable_cost_mod($a);
	    $self->out(sprintf "  %2d %s%s\n", $n, $a,
	    	    	$mod == 0 ? "" : sprintf " (%+d)", $mod);
	}
    }
    else {
	$self->out("  nothing\n");
    }

    $self->out_char("score: ", $player->score, "\n");

    # XXX hand limit, gem slots

    my @e = $player->current_energy;
    $self->out_char(sprintf "energy: %d total %d liquid (%d + %d) %d active\n",
		    @e[CUR_ENERGY_TOTAL,
			CUR_ENERGY_LIQUID,
			CUR_ENERGY_CARDS_DUST,
			CUR_ENERGY_INACTIVE_GEMS,
			CUR_ENERGY_ACTIVE_GEMS]);
    if ($player->a_char == CHAR_DRUID) {
	$self->out_char(sprintf "%s enchanted a ruby\n",
			    $player->a_enchanted_ruby ? "has" : "has not");
    }
    $self->out_char("items:\n");
    for (sort { $a->a_item_type <=> $b->a_item_type
    	    	    or $a <=> $b } $player->items) {
	$self->out("  $_\n")
    }
    return 1;
}
*action_i = \&action_items;

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
*action_e = \&action_enchant_gem;

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

#------------------------------------------------------------------------------

1

# XXX better completion (gem names, etc)
