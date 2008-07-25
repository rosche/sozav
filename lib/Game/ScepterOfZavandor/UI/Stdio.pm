# $Id: Stdio.pm,v 1.5 2008-07-25 17:39:00 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::Stdio;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 	qw(add_array_index debug);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Symbol	qw(qualify_to_ref);

use Game::ScepterOfZavandor::Constant qw(
    /^CUR_ENERGY_/
    @Gem
    %Gem
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

    my $liquid = $self->a_player->current_energy_liquid;
    my $hc = $self->a_player->current_hand_count;
    my $hl = $self->a_player->hand_limit;
    $self->out_char("action? ($liquid liquid, $hc/$hl hand limit) ");
    my $s = $self->in;
    return unless defined $s && $s ne '';
    my ($cmd, @arg) = split ' ', $s;
    $cmd =~ tr/-/_/;
    my $method = "action_$cmd";
    if (!$self->can($method)) {
	$self->out_char("invalid action ", dstr $cmd, "\n");
	return 1;
    }

    my $ret = eval { $self->$method(@arg) };
    if ($@) {
	$self->out("ERROR: $@");
	$ret = 1;
    }

    return $ret;
}

sub action_buy_auctionable {
    @_ == 2 || badinvo;
    my $self = shift;
    my $aix  = shift;

    my @a = $self->a_player->a_game->auction_all;
    $aix >= 1 && $aix <= @a
    	or die "invalid auction index ", dstr $aix;

    my $auc = $a[$aix - 1];
    $self->a_player->buy_auctionable($auc, $auc->get_min_bid);
    return 1;
}
*action_b = \&action_buy_auctionable;

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
    for my $gtype (0..$#Gem) {
    	my $cost = $self->a_player->gem_cost($gtype);
    	my $val  = $self->a_player->gem_value($gtype);
	$self->out(sprintf "  %8s  cost %2d  value %2d  avg income %4.2f\n",
			    $Gem[$gtype], $cost, $val);
    }
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

    $self->out("on auction:\n");
    if (my @a = $self->a_player->a_game->auction_all) {
	for (0..$#a) {
	    my $n = $_ + 1;
	    $self->out("  $n $a[$_]\n");
	}
    }
    else {
	$self->out("  none\n");
    }

    $self->out_char("score: ", $self->a_player->score, "\n");

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

1
