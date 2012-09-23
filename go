#!/usr/bin/perl -w
use strict;

use lib '/usr/local/src/zavandor/lib';

use RS::Handy;
use Carp ();

BEGIN {
    if (@ARGV && $ARGV[0] eq '-d') {
	shift @ARGV;
	$Game::Util::Debug = 1;
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
