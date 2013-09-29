#!/usr/bin/perl -w
use strict;
use warnings;

use Test::Most;
use Email::Stuffer;

# Verify subject() always returns $self

my $stuffer = Email::Stuffer->new;
is($stuffer->subject('Subject goes here'), $stuffer, 'subject returned $self');

# verify subject header added
like(
  $stuffer->as_string,
  qr/^Subject:\sSubject\sgoes\shere\x0d?\x0a/mx,
  'matching subject header',
);

is($stuffer->subject(q{}), $stuffer, 'subject returned $self');

like(
  $stuffer->as_string,
  qr/^Subject:\s\x0d?\x0a/mx,
  'matching subject header',
);
#print $stuffer->as_string;
done_testing();
