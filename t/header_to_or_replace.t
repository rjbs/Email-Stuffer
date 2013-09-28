#!/usr/bin/perl -w
use strict;
use warnings;

use Test::Most;
use Email::Stuffer;

# verify that calling Email::Stuffer->header
# actually replaces said header, rather than adds
# a new one.

my $stuffer = Email::Stuffer->new;
$stuffer->header(to => 'foo@bar.net');

# verify to header added
like(
    $stuffer->as_string,
    qr/^To:\sfoo\@bar\.net$/mx,
    'matching to header',
);

$stuffer->header(to => 'somewhere@else.net');

# verify old to header gone
unlike(
    $stuffer->as_string,
    qr/^To:\sfoo\@bar\.net$/mx,
    'old to header no longer present',
);

# verify new to header present
like(
    $stuffer->as_string,
    qr/^To:\ssomewhere\@else\.net$/mx,
    'new to header present',
);
#print $stuffer->as_string;

done_testing();
