#!/usr/bin/perl
use strict;
use warnings;

use Test::More qw[no_plan];
use Email::Stuffer;
use Email::Sender::Transport::Test ();
use File::Spec::Functions ':ALL';

my $TEST_GIF = catfile( 't', 'data', 'paypal.gif' );
ok( -f $TEST_GIF, "Found test image: $TEST_GIF" );

#####################################################################
# Multipart/Alternate tests

my $test = Email::Sender::Transport::Test->new;
my $rv = Email::Stuffer->from       ( 'Adam Kennedy<adam@phase-n.com>')
                       ->to         ( 'adam@phase-n.com'              )
                       ->subject    ( 'Hello To:!'                    )
                       ->text_body  ( 'I am an emáil'                 )
                       ->html_body  ( '<b>I am a html emáil</b>'      )
                       ->transport  ( $test                           )
                       ->send;
ok( $rv, 'Email sent ok' );
is( $test->delivery_count, 1, 'Sent one email' );
my $email  = $test->shift_deliveries->{email};
my $string = $email->as_string;

like( $string, qr/Adam Kennedy/,  'Email contains from name' );
like( $string, qr/phase-n/,       'Email contains to string' );
like( $string, qr/Hello/,         'Email contains subject string' );
like( $string, qr/Content-Type: multipart\/alternative/,   'Email content type' );
like( $string, qr/Content-Type: text\/plain/,   'Email content type' );
like( $string, qr/Content-Type: text\/html/,   'Email content type' );

my $mime = $email->object;
like( ($mime->subparts)[0]->body_str, qr/I am an emáil/, 'Email contains text_body' );
like( ($mime->subparts)[1]->body_str, qr/<b>I am a html emáil<\/b>/, 'Email contains text_body' );

#####################################################################
# Multipart/Alternate tests with attachment

my $rv2 = Email::Stuffer->from       ( 'Adam Kennedy<adam@phase-n.com>')
                       ->to         ( 'adam@phase-n.com'              )
                       ->subject    ( 'Hello To:!'                    )
                       ->text_body  ( 'I am an emáil'                 )
                       ->html_body  ( '<b>I am a html emáil</b>'      )
                       ->attach_file( $TEST_GIF                       )
                       ->transport  ( $test                           )
                       ->send;
ok( $rv2, 'Email sent ok' );
is( $test->delivery_count, 1, 'Sent one email' );
$email  = $test->shift_deliveries->{email};
$string = $email->as_string;

like( $string, qr/Adam Kennedy/,  'Email contains from name' );
like( $string, qr/phase-n/,       'Email contains to string' );
like( $string, qr/Hello/,         'Email contains subject string' );
like( $string, qr/Content-Type: multipart\/alternative/,   'Email content type' );
like( $string, qr/Content-Type: text\/plain/,   'Email content type' );
like( $string, qr/Content-Type: text\/html/,   'Email content type' );

$mime = $email->object;
like( (($mime->subparts)[0]->subparts)[0]->body_str, qr/I am an emáil/, 'Email contains text_body' );
like( (($mime->subparts)[0]->subparts)[1]->body_str, qr/<b>I am a html emáil<\/b>/, 'Email contains text_body' );
like( ($mime->subparts)[0]->content_type, qr{^multipart/alternative}, 'First part is multipart/alternative');
like( ($mime->subparts)[1]->content_type, qr{^image/gif}, 'Second part is image/gif');
like( (($mime->subparts)[0]->subparts)[0]->content_type, qr{text/plain}, 'First text sub part is text/plain' );
like( (($mime->subparts)[0]->subparts)[1]->content_type, qr{text/html}, 'Second text sub part is text/html' );

1;
