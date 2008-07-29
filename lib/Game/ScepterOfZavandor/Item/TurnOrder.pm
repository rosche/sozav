# $Id: TurnOrder.pm,v 1.1 2008-07-29 15:30:06 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::TurnOrder;

use base qw(Game::ScepterOfZavandor::Item);

use Game::Util	qw($Debug add_array_index debug make_ro_accessor make_rw_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);
use Scalar::Util qw(looks_like_number weaken);

use Game::ScepterOfZavandor::Constant qw(
);

sub new {
    @_ == 2 || badinvo;
    my ($class, $n) = @_;

    my $self = $class->SUPER::new(ITEM_TYPE_TURN_ORDER);
    return $self;
}

#make_ro_accessor (
#    a_type  => ITEM_KNOW_TYPE,
#);

#sub as_string_fields {
#    @_ || badinvo;
#    my $self = shift;
#
#}

1
