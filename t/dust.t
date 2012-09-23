#!perl -w
use strict;
BEGIN { $SIG{__WARN__} = sub { die @_ } }

# $Id: dust.t,v 1.1 2012-09-23 01:14:25 roderick Exp $

use Game::ScepterOfZavandor::Test;
use Game::Util				qw($Debug);
use RS::Handy				qw(subcall_info);

create_standard_test_game;

# XXX test 1 dust

for ([10 => 3], [5 => 2], [2 => 1]) {
    my ($val, $hc) = @$_;
    my @d = create_dust $val;
    ok @d == 1;
    my $d = shift @d;
    ok $d->energy       == $val;
    ok $d->a_hand_count == $hc;
}

# ->make_dust_with_hand_limit -------------------------------------------------

sub mdwhl_and_test {
    my ($frames, $max_hand_count, $tot_value, @expected_value) = @_;
    my @d = map { $_->energy } Game::ScepterOfZavandor::Item::Energy::Dust
    	->make_dust_with_hand_limit($Player, $tot_value, $max_hand_count);
    # XXX desc too verbose for successes
    # XXX subcall_info useless for call in loop
    is_deeply \@d, \@expected_value,
    	"tot_value=$tot_value max_hand_count=$max_hand_count "
	    . "want [@expected_value] got [@d] "
	    . subcall_info $frames;
}

$Debug = 3;
for (   [5,  1 => ()],
	[5,  2 => 2],
	[5,  3 => 2],
	[5,  4 => 2, 2],
	[5,  5 => 5],
	[5,  6 => 2, 2, 2],
	[5,  7 => 5, 2],
	[5,  8 => 2, 2, 2, 2],
	[5,  9 => 5, 2, 2],
	[5, 10 => 10],
	) {
    mdwhl_and_test 0, @$_;
}

# ->consolidate_dust ----------------------------------------------------------

# XXX args for exactly what dust you should have?

sub consolidate_and_test {
    my ($frames, $new_energy, $new_hand_count) = @_;
    $Player->consolidate_dust;
    test_energy_and_count $frames + 1, $new_energy, $new_hand_count;
}

discard_all_energy;
add_dust 12, 6 => 2, 2, 2, 2, 2, 2;
consolidate_and_test 0, 12, 4;

# 2 2 2 shouldn't consolidate into a 5, losing 1 dust (when the 1 dust
# option isn't on)

discard_all_energy;
add_dust 6, 3 => 2, 2, 2;
consolidate_and_test 0, undef, 3;
TODO: {
    local $TODO = "don't consolidate 2 2 2 -> 5 (without 1)";
    is $Player->current_energy_liquid, 6;
}
discard_all_energy;
add_dust 11, 5 => 5, 2, 2, 2;
consolidate_and_test 0, undef, 5;
TODO: {
    local $TODO = "don't consolidate 5 2 2 2 -> 10 (without 1)";
    is $Player->current_energy_liquid, 11;
}

discard_all_energy;
add_dust 36, 13 => 2, 5, 10, 2, 5, 10, 2;
consolidate_and_test 0, 36, 12;

