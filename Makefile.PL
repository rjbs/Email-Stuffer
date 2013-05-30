use strict;
use warnings;
use ExtUtils::MakeMaker;

use 5.008;

WriteMakefile(
  NAME          => 'Email::Stuffer',
  VERSION_FROM  => 'lib/Email/Stuffer.pm',
  LICENSE       => 'perl',
  PREREQ_PM => {
    'Carp'           => 0,
    'File::Basename' => 0,
    'prefork'        => '1.01',
    'Params::Util'   => '0.23',
    'Email::Simple'  => '1.998',
    'Email::MIME'    => '1.901',
    'Email::Sender'  => '1.300000',
    'File::Type'     => '0.22',
  },
  TEST_REQUIRES => {
    'Test::More' => '0.47',
    'File::Spec' => '0.80',
  }
);

