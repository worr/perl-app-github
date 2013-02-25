package App::GitHub::Test;

use strict;
use warnings;

use v5.10;

use Test::MockObject;
require Exporter "import";
@EXPORT_OK( qw/init_app_github/ );

use lib "../../lib";

use App::GitHub;

sub init_app_github {
	my $mock_ngh = Test::MockObject->new;
	$mock_ngh->set_isa( "Net::GitHub" );

	return App::GitHub->new( github => $mock_ngh, term => \*STDOUT );
}

1;