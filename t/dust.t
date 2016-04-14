#!perl -w
use strict;
BEGIN { $SIG{__WARN__} = sub { die @_ } }

# $Id: dust.t,v 1.1 2012-09-23 01:14:25 roderick Exp $

use Game::ScepterOfZavandor::Test;
use Game::ScepterOfZavandor::Constant	qw(/^OPT_/);
use Game::Util				qw($Debug);
use RS::Handy				qw(subcall_info);

*TODO = \$Test::More::TODO;

create_standard_test_game OPT_1_DUST, 1;

for ([10 => 3], [5 => 2], [2 => 1], [1 => 1]) {
    my ($val, $hc) = @$_;
    my @d = create_dust $val;
    ok @d == 1;
    my $d = shift @d;
    ok $d->energy       == $val;
    ok $d->a_hand_count == $hc;
}

create_standard_test_game;

# ->make_dust -----------------------------------------------------------------

sub md_and_test {
    my ($tot_value, @expected_value) = @_;
    my @d = map { $_->energy } Game::ScepterOfZavandor::Item::Energy::Dust
	->make_dust($Player, $tot_value);
    is_deeply \@d, \@expected_value,
	"tot_value=$tot_value "
	    . "want [@expected_value] got [@d] "
	    . subcall_info 0;
}

md_and_test  1;
md_and_test  2, 2;
md_and_test  3, 2;
md_and_test  4, 2, 2;
md_and_test  5, 5;
md_and_test  6, 2, 2, 2;
md_and_test  7, 5, 2;
md_and_test  8, 2, 2, 2, 2;
md_and_test  9, 5, 2, 2;
md_and_test 10, 10;
md_and_test 11, 5, 2, 2, 2;
md_and_test 12, 10, 2;
md_and_test 13, 5, 2, 2, 2, 2;
md_and_test 14, 10, 2, 2;
md_and_test 15, 10, 5;
md_and_test 16, 10, 2, 2, 2;
md_and_test 17, 10, 5, 2;
md_and_test 18, 10, 2, 2, 2, 2;
md_and_test 19, 10, 5, 2, 2;
md_and_test 20, 10, 10;

# ->make_dust_with_hand_limit -------------------------------------------------

sub mdwhl_and_test {
    my ($max_hand_count, $tot_value, @expected_value) = @_;
    my @d = map { $_->energy } Game::ScepterOfZavandor::Item::Energy::Dust
	->make_dust_with_hand_limit($Player, $tot_value, $max_hand_count);
    is_deeply \@d, \@expected_value,
	"tot_value=$tot_value max_hand_count=$max_hand_count "
	    . "want [@expected_value] got [@d] "
	    . subcall_info 0;
}

# XXX test with & without 1 dust

mdwhl_and_test 5,  1 => ();
mdwhl_and_test 5,  2 => 2;
mdwhl_and_test 5,  3 => 2;
mdwhl_and_test 5,  4 => 2, 2;
mdwhl_and_test 5,  5 => 5;
mdwhl_and_test 5,  6 => 2, 2, 2;
mdwhl_and_test 5,  7 => 5, 2;
mdwhl_and_test 5,  8 => 2, 2, 2, 2;
mdwhl_and_test 5,  9 => 5, 2, 2;
mdwhl_and_test 5, 10 => 10;

mdwhl_and_test 2,  1 => ();
mdwhl_and_test 2,  2 => 2;
mdwhl_and_test 2,  3 => 2;
mdwhl_and_test 2,  4 => 2, 2;
mdwhl_and_test 2,  5 => 5;
mdwhl_and_test 2,  6 => 5;
mdwhl_and_test 2,  7 => 5;
mdwhl_and_test 2,  8 => 5;
mdwhl_and_test 2,  9 => 5;
mdwhl_and_test 2, 10 => 5;

mdwhl_and_test 1,  6 => 2;
mdwhl_and_test 2,  6 => 5;
mdwhl_and_test 3,  6 => 2, 2, 2;

mdwhl_and_test 1,  8 => 2;
mdwhl_and_test 2,  8 => 5;
mdwhl_and_test 3,  8 => 5, 2;
mdwhl_and_test 4,  8 => 2, 2, 2, 2;

mdwhl_and_test 2, 11 => 5;
mdwhl_and_test 3, 11 => 10;
mdwhl_and_test 4, 11 => 10;
mdwhl_and_test 5, 11 => 5, 2, 2, 2;

mdwhl_and_test 2, 13 => 5;
mdwhl_and_test 3, 13 => 10;
mdwhl_and_test 4, 13 => 10, 2;
mdwhl_and_test 5, 13 => 10, 2;
mdwhl_and_test 6, 13 => 5, 2, 2, 2, 2;

mdwhl_and_test 2, 15 => 5;
mdwhl_and_test 3, 15 => 10;
mdwhl_and_test 4, 15 => 10, 2;
mdwhl_and_test 5, 15 => 10, 5;

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
is $Player->current_energy_liquid, 6;

# 5 2 2 2 => 11 don't consolidate to 10

discard_all_energy;
add_dust 11, 5 => 5, 2, 2, 2;
consolidate_and_test 0, undef, 5;
is $Player->current_energy_liquid, 11;

discard_all_energy;
add_dust 36, 13 => 2, 5, 10, 2, 5, 10, 2;
consolidate_and_test 0, 36, 12;

