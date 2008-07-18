# $Id: Stdio.pm,v 1.1 2008-07-18 20:10:30 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI;

use base qw(Game::ScepterOfZavandor::UI);

use Game::Util 	qw(add_array_index debug make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xcroak);
use Symbol	qw(qualify_to_ref);

BEGIN {
    add_array_index 'UI', $_ for map { "STDIO_$_" } qw(IN_FH OUT_FH);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $in_fh, $out_fh) = @_;

    my $self = $class->SUPER::new($itype);
    $self->[UI_STDIO_IN_FH ] = qualify_to_ref $in_fh , scalar caller;
    $self->[UI_STDIO_OUT_FH] = qualify_to_ref $out_fh, scalar caller;

    return $self;
}

1
