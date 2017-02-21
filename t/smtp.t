#!/usr/bin/perl
use strict;
use warnings;

use Test::More qw[no_plan];
use Email::Stuffer;
use Email::Sender::Transport::Test ();


#####################################################################
# Multipart/Alternate tests

my @test = ( 'SMTP', { host => 'smtp.jasonic.dk' });
use Data::Dumper 'Dumper';
warn Dumper [ @test ];
my $rv = Email::Stuffer->from       ( 'Adam Kennedy<adam@phase-n.com>')
                       ->to         ( 'adam@phase-n.com'              )
                       ->subject    ( 'Hello To:!'                    )
                       ->text_body  ( 'I am an emáil'                 )
                       ->html_body  ( '<b>I am a html emáil</b>'      )
                       ->transport  ( @test                           );

my $test = Email::Sender::Transport::Test->new;
$rv->{transport} = $test;
$rv->send;

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

1;
