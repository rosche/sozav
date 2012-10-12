#!/usr/bin/perl -w
use strict;

use FindBin qw($Bin);
use lib "$Bin/lib";

use RS::Handy;
use Carp ();

BEGIN {
    while (@ARGV && $ARGV[0] eq '-d') {
	shift @ARGV;
	$Game::Util::Debug++;
	$SIG{__WARN__} = \&Carp::confess;
    }
}

use Game::ScepterOfZavandor::Game ();

#BEGIN {
#    $SIG{__WARN__} = \&Carp::cluck;
#    $SIG{__DIE__ } = \&Carp::confess;
#}

sub main {
    Game::ScepterOfZavandor::Game::run_game @ARGV;
}
main
