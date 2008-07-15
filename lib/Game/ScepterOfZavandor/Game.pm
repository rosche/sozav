# $Id: Game.pm,v 1.1 2008-07-15 17:20:56 roderick Exp $

=head1 NAME

Game::ScepterOfZavandor::Game - XXX

=head1 SYNOPSIS

XXX

=head1 DESCRIPTION

XXX

=cut

package Game::ScepterOfZavandor::Game;

use strict;

use base qw(Exporter);

use RS::Handy	qw(badinvo data_dump dstr xcroak);

use vars qw($VERSION @EXPORT);

$VERSION = q$Revision: 1.1 $ =~ /(\d\S+)/ ? $1 : '?';

BEGIN {
    @EXPORT = qw(
    );
}

use subs grep { /^[a-z]/    } @EXPORT;
use vars grep { /^[\$\@\%]/ } @EXPORT;

=head1 IMPORTABLES

=over 4

XXX

=back

=cut

1
