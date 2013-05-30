#!/usr/bin/perl -w

# Load test the Email::Stuffer module

use strict;
use lib ();
use File::Spec::Functions ':ALL';
BEGIN {
	$| = 1;
	unless ( $ENV{HARNESS_ACTIVE} ) {
		require FindBin;
		chdir ($FindBin::Bin = $FindBin::Bin); # Avoid a warning
		lib->import( catdir( updir(), 'lib') );
	}
}

use Test::More tests => 35;
use Email::Stuffer;

my $TEST_GIF = $ENV{HARNESS_ACTIVE}
	? catfile( 't', 'data', 'paypal.gif' )
	: catfile( 'data', 'paypal.gif' );
ok( -f $TEST_GIF, 'Found test image' );

sub string_ok {
	my $string = shift;
	$string = !! (defined $string and ! ref $string and $string ne '');
	ok( $string, $_[0] || 'Got a normal string' );
}

sub stuff_ok {
	my $stuff = shift;
	isa_ok( $stuff,        'Email::Stuffer' );
	isa_ok( $stuff->email, 'Email::MIME' );
	string_ok( $stuff->as_string, 'Got a non-null string for Email::Stuffer->as_string' );
}





#####################################################################
# Main Tests

# Create a new Email::Stuffer object
my $Stuffer = Email::Stuffer->new;
stuff_ok( $Stuffer );
my @headers = $Stuffer->headers;
ok( scalar(@headers), 'Even the default object has headers' );

# Set a To name
my $rv = $Stuffer->to('adam@ali.as');
stuff_ok( $Stuffer );
stuff_ok( $rv    );
is( $Stuffer->as_string, $rv->as_string, '->To returns the same object' );
is( $Stuffer->email->header('To'), 'adam@ali.as', '->To sets To header' );

# Set a From name
$rv = $Stuffer->from('bob@ali.as');
stuff_ok( $Stuffer );
stuff_ok( $rv    );
is( $Stuffer->as_string, $rv->as_string, '->From returns the same object' );
is( $Stuffer->email->header('From'), 'bob@ali.as', '->From sets From header' );

# More complex one
use Email::Send::Test ();
my $rv2 = Email::Stuffer->from       ( 'Adam Kennedy<adam@phase-n.com>')
                      ->to         ( 'adam@phase-n.com'              )
                      ->subject    ( 'Hello To:!'                    )
                      ->text_body  ( 'I am an email'                 )
                      ->attach_file( $TEST_GIF                       )
                      ->using      ( 'Test'                          )
                      ->send;
ok( $rv2, 'Email sent ok' );
is( scalar(Email::Send::Test->emails), 1, 'Sent one email' );
my $email = (Email::Send::Test->emails)[0]->as_string;
like( $email, qr/Adam Kennedy/,  'Email contains from name' );
like( $email, qr/phase-n/,       'Email contains to string' );
like( $email, qr/Hello/,         'Email contains subject string' );
like( $email, qr/I am an email/, 'Email contains text_body' );
like( $email, qr/paypal/,        'Email contains file name' );

# attach_file content_type
use Email::Send::Test ();
$rv2 = Email::Stuffer->from       ( 'Adam Kennedy<adam@phase-n.com>'        )
                   ->to         ( 'adam@phase-n.com'                      )
                   ->subject    ( 'Hello To:!'                            )
                   ->text_body  ( 'I am an email'                         )
                   ->attach_file( 'README', content_type => 'text/plain'  )
                   ->using      ( 'Test'                                  )
                   ->send;
ok( $rv2, 'Email sent ok' );
is( scalar(Email::Send::Test->emails), 2, 'Sent one email' );
$email = (Email::Send::Test->emails)[1]->as_string;
like( $email, qr/Adam Kennedy/,  'Email contains from name' );
like( $email, qr/phase-n/,       'Email contains to string' );
like( $email, qr/Hello/,         'Email contains subject string' );
like( $email, qr/I am an email/, 'Email contains text_body' );
like( $email, qr{Content-Type: text/plain; name="README"}, 'Email contains attachment content-Type' );
1;
