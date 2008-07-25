# $Id: Auctionable.pm,v 1.2 2008-07-25 01:05:45 roderick Exp $

use strict;

package Game::ScepterOfZavandor::Item::Auctionable;

use base qw(Exporter Game::ScepterOfZavandor::Item);

use Carp	qw(confess);
use Game::Util	qw(add_array_index debug make_ro_accessor);
use RS::Handy	qw(badinvo data_dump dstr xconfess);

use Game::ScepterOfZavandor::Constant qw(
    /^ITEM_/
    /^AUC_/
);

use vars qw($VERSION @EXPORT @EXPORT_OK);
BEGIN {
    $VERSION = q$Revision: 1.2 $ =~ /(\d\S+)/ ? $1 : '?';
    @EXPORT_OK = qw(
	auc_type_is_artifact
	auc_type_is_sentinel
    );
}
use subs grep { /^[a-z]/    } @EXPORT, @EXPORT_OK;
use vars grep { /^[\$\@\%]/ } @EXPORT, @EXPORT_OK;

BEGIN {
    add_array_index 'ITEM', $_ for map { "AUC_$_" } qw(TYPE MIN_BID);
}

#sub auc_type_is_artifact {
#    @_ == 1 || badinvo;
#    my ($auc_type) = @_;
#    return !auc_type_is_sentinel $auc_type;
#}

#sub auc_type_is_sentinel {
#    @_ == 1 || badinvo;
#    my ($auc_type) = @_;
#    defined $auc_type or xconfess;
#    return $Auctionable_data[$auc_type][AUC_DATA_DECK_LETTER] eq 'S';
#}

sub new {
    @_ == 4 || badinvo;
    my ($class, $itype, $auc_type, $rauc_data) = @_;

    # XXX validate $auc_type

    my $self = $class->SUPER::new($itype);
    $self->[ITEM_AUC_TYPE] = $auc_type;
    $self->[ITEM_AUC_MIN_BID] = $rauc_data->[$auc_type][AUC_DATA_MIN_BID];
    $self->a_vp($rauc_data->[$auc_type][AUC_DATA_VP]);

    return $self;
}

make_ro_accessor (
    a_auc_type => ITEM_AUC_TYPE,
    a_min_bid  => ITEM_AUC_MIN_BID,
);

sub as_string_fields {
    @_ || badinvo;
    my $self = shift;
    my @r = $self->SUPER::as_string_fields(@_);
    push @r,
    	# XXX name
	sprintf("min=%3d", $self->a_min_bid);
    return @r;
}

1
