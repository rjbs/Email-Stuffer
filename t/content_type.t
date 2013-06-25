use strict;
use warnings;
use utf8;
use Test::More tests => 11;
use File::Spec::Functions ':ALL';
use Email::Stuffer;

my $TEST_GIF = catfile( 't', 'data', 'paypal.gif' );
ok( -f $TEST_GIF, "Found test image: $TEST_GIF" );

my $TEST_JPG = catfile( 't', 'data', 'paypal.jpg' );
ok( -f $TEST_JPG, "Found test image: $TEST_JPG" );

my $TEST_PNG = catfile( 't', 'data', 'paypal.png' );
ok( -f $TEST_PNG, "Found test image: $TEST_PNG" );

my $mail = Email::Stuffer->from       ('cpan@example.com'                      )
				->to       ('santa@example.com'              )
				->text_body("YAY")
				->attach_file($TEST_GIF)
				->attach(slurp($TEST_GIF))
				->attach_file($TEST_JPG)
				->attach(slurp($TEST_JPG))
				->attach_file($TEST_PNG)
				->attach(slurp($TEST_PNG))
				->email;
is(0+$mail->parts, 7);
like([$mail->parts]->[0]->content_type, qr(^text/plain));
like([$mail->parts]->[1]->content_type, qr(^image/gif));
like([$mail->parts]->[2]->content_type, qr(^image/gif));
like([$mail->parts]->[3]->content_type, qr(^image/jpeg));
like([$mail->parts]->[4]->content_type, qr(^image/jpeg));
like([$mail->parts]->[5]->content_type, qr(^image/png));
like([$mail->parts]->[6]->content_type, qr(^image/png));

sub slurp {
	my $fname = shift;
	open my $fh, '<', $fname
		or Carp::croak("Can't open '$fname' for reading: '$!'");
	scalar(do { local $/; <$fh> })
}
