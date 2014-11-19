use strict;
use warnings;
use utf8;
use Test::More tests => 3;
use File::Spec::Functions ':ALL';
use IO::All; # should skip test if not found
use Email::Stuffer;

# sadly this is only a windows test
my $true_data = "\r\n\n\n\r\n";

my $TEST_ACID = catfile( 't', 'data', 'acid.bin' );
open my $fh, '>', $TEST_ACID;
binmode $fh;
print {$fh} $true_data;
close $fh;
ok( -f $TEST_ACID, "Found test acid: $TEST_ACID" );

my $mail = Email::Stuffer->from('cpan@example.com')
   ->to('santa@example.com')
   ->text_body("YAY")
   ->attach_file(io->file($TEST_ACID))
   ->email;
is(0+$mail->parts, 2, 'all parts found');
ok([$mail->parts]->[1]->body eq $true_data, 'not corrupt');
