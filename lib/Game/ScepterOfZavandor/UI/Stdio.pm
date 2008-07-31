# $Id: Stdio.pm,v 1.10 2008-07-31 00:52:13 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Stdio;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 		qw(add_array_index debug eval_block);
use List::Util		qw(first);
use List::MoreUtils	qw(natatime);
use RS::Handy		qw(badinvo data_dump dstr xcroak);
use Scalar::Util	qw(looks_like_number);
use Symbol		qw(qualify_to_ref);
use Term::ANSIColor	qw(color);

use Game::ScepterOfZavandor::Constant qw(
    /^CUR_ENERGY_/
    @Energy_estimate
    @Gem
    %Gem
    @Knowledge
    %Knowledge
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
    @_ == 1 || badinvo;
    my $self = shift;

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

sub out_char {
    @_ || badinvo;
    my $self = shift;

    $self->out($self->a_player->name, " ", @_);
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
	$self->out(color('red'), "ERROR: $@", color('reset'));
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

    $self->out(sprintf "%-10s %59s %s\n", "Players:", "", "gef9aa");
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
	    my $fmt = "%s %2d";
	    my @arg = ($desc, $cur);
	    $fmt .= sprintf "%-5s",
			$cur == $max
    	    	    	    ? ""
    	    	    	    : sprintf "(%+d)", $cur - $max;
    	    return $fmt => \@arg;
    	};

    	my @spec = (
	    "%-6s"              => [$p->name],
	    "vp %2d(%d)"        => [$p->score, $p->user_turn_order],
	    "inc " . join("/", ("%.0f") x @Energy_estimate)
    	    	                => [$p->income_estimate],
	    "\$%3d"            => [$p->current_energy_liquid],
	    $rel->("hand", $p->current_hand_count, $p->hand_limit),
	    $rel->("gems", 0+$p->active_gems,      $p->num_gem_slots),
	    "kn %s"             => [$knowledge],
    	);

    	my $it = natatime 2, @spec;
	my ($fmt, @arg);
	while (my ($this_fmt, $r) = $it->()) {
	    if (!defined $fmt) {
		$fmt = ($p == $self->a_player ? color('bold') . ">" : " ")
			. " ";
	    }
	    else {
		$fmt .= "  ";
	    }
	    $fmt .= $this_fmt;
	    push @arg, @$r;
	}
    	$self->out(sprintf "$fmt%s\n", @arg, color 'reset');
    }
}

#------------------------------------------------------------------------------

sub action_advance_knowledge {
    @_ == 1 || @_ == 2 || badinvo;
    my $self  = shift;
    my $kname_or_type = shift;

    my $ktype;
    if (!defined $kname_or_type) {
	my @k = $self->a_player->knowledge_chips_advancable;
	if (@k == 0) {
	    die "no advancable knowledge chips";
	}
	elsif (@k > 1) {
	    die "multiple advancable knowledge chips";
	}
	$ktype = $k[0]->a_type;
    }
    else {
	$ktype = looks_like_number($kname_or_type)
    	    	    ? $kname_or_type - 1
		    : $Knowledge{$kname_or_type};
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
    # XXX allow specifying price

    my @a = $self->a_player->a_game->auction_all;
    $aix >= 1 && $aix <= @a
    	or die "invalid auction index ", dstr $aix;

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
	$kchip = first { $_->a_cost == $cost }
		$self->a_player->knowledge_chips_unbought
	    or die "no unbought chip with cost $cost";
    }
    else {
	($kchip) = $self->a_player->knowledge_chips_unbought
	    or die "no unbought chips";
    }
    $self->a_player->buy_knowledge_chip($kchip, 0);
}
*action_k = \&action_buy_knowledge_chip;

sub action_done {
    @_ == 1 || badinvo;
    my $self = shift;

    return 0;
}
*action_d = \&action_done;

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
    my $class = ref $self;
    my $pkg_hash = do { no strict 'refs'; \%{ "${class}::" } };
    for (sort grep { /^action_/ } keys %$pkg_hash) {
	next unless defined &{ "${class}::${_}" };
	tr/_/-/;
	$self->out("  $_\n");
    }
    return 1;
}
*action_h = \&action_help;

sub action_items {
    @_ == 1 || badinvo;
    my $self = shift;

    # XXX how many of each kind of card left
    $self->out("on auction:\n");
    if (my @a = $self->a_player->a_game->auction_all) {
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

    $self->out_char("score: ", $self->a_player->score, "\n");

    # XXX hand limit, gem slots

    my @e = $self->a_player->current_energy;
    $self->out_char(sprintf "energy: %d total %d liquid (%d + %d) %d active\n",
		    @e[CUR_ENERGY_TOTAL,
			CUR_ENERGY_LIQUID,
			CUR_ENERGY_CARDS_DUST,
			CUR_ENERGY_INACTIVE_GEMS,
			CUR_ENERGY_ACTIVE_GEMS]);
    $self->out_char("items:\n");
    for (sort { $a->a_item_type <=> $b->a_item_type
    	    	    or $a <=> $b } $self->a_player->items) {
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
    	die "invalid gem name ", dstr $gname;
    }

    # XXX can_enchant

    my $g = $self->a_player->enchant_gem($gtype)
	or die "didn't get a gem back";

    # XXX don't automatically activate

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
    	die "invalid gem name ", dstr $gname;
    }

    # XXX let user pick
    #
    # XXX or at least prefer inactive ones (though the auto-activate
    # makes this non-critical)

    my ($gem) = grep { $_->a_gem_type == $gtype } $self->a_player->gems;
    if (!$gem) {
	die "you don't own a $gname"; # XXX grammar
    }

    $self->a_player->add_items(
	Game::ScepterOfZavandor::Item::Energy::Dust->make_dust(
	    $self->a_player->spend($gem)));

    # XXX don't automatically activate

    $self->a_player->auto_activate_gems;

    return 1;
}

#------------------------------------------------------------------------------

1
