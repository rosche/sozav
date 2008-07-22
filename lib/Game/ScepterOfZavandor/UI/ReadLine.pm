# $Id: ReadLine.pm,v 1.2 2008-07-22 20:57:11 roderick Exp $

use strict;

package Game::ScepterOfZavandor::UI::ReadLine;

use base qw(Game::ScepterOfZavandor::UI::Stdio);

use Term::ReadLine	();
use Game::Util 		qw(add_array_index debug);
use RS::Handy		qw(badinvo data_dump dstr xcroak);
use Symbol		qw(qualify_to_ref);

BEGIN {
    add_array_index 'UI', $_ for map { "READLINE_$_" } qw(OBJ);
}

sub new {
    @_ == 3 || badinvo;
    my ($class, $in_fh, $out_fh) = @_;

    $in_fh  = qualify_to_ref $in_fh , scalar caller;
    $out_fh = qualify_to_ref $out_fh, scalar caller;

    my $self = $class->SUPER::new($in_fh, $out_fh);
    $self->[UI_READLINE_OBJ] = Term::ReadLine->new('zavandor', $in_fh, $out_fh)
	or xcroak "can't initialize Term::ReadLine";

    # XXX completion

    return $self;
}

sub in {
    @_ == 1 || badinvo;
    my $self = shift;

    return $self->[UI_READLINE_OBJ]->readline;
}

1
