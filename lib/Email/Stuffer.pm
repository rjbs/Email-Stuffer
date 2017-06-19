use strict;
use warnings;
package Email::Stuffer;
# ABSTRACT: A more casual approach to creating and sending Email:: emails

=head1 SYNOPSIS

  # Prepare the message
  my $body = <<'AMBUSH_READY';
  Dear Santa
  
  I have killed Bun Bun.
  
  Yes, I know what you are thinking... but it was actually a total accident.
  
  I was in a crowded line at a BayWatch signing, and I tripped, and stood on
  his head.
  
  I know. Oops! :/
  
  So anyways, I am willing to sell you the body for $1 million dollars.
  
  Be near the pinhole to the Dimension of Pain at midnight.
  
  Alias

  AMBUSH_READY
  
  # Create and send the email in one shot
  Email::Stuffer->from     ('cpan@ali.as'             )
                ->to       ('santa@northpole.org'     )
                ->bcc      ('bunbun@sluggy.com'       )
                ->text_body($body                     )
                ->attach_file('dead_bunbun_faked.gif' )
                ->send;

=head1 DESCRIPTION

B<The basics should all work, but this module is still subject to
name and/or API changes>

Email::Stuffer, as its name suggests, is a fairly casual module used
to stuff things into an email and send them. It is a high-level module
designed for ease of use when doing a very specific common task, but
implemented on top of the light and tolerable Email:: modules.

Email::Stuffer is typically used to build emails and send them in a single
statement, as seen in the synopsis. And it is certain only for use when
creating and sending emails. As such, it contains no email parsing
capability, and little to no modification support.

To re-iterate, this is very much a module for those "slap it together and
fire it off" situations, but that still has enough grunt behind the scenes
to do things properly.

=head2 Default Transport

Although it cannot be relied upon to work, the default behaviour is to
use C<sendmail> to send mail, if you don't provide the mail send channel
with either the C<transport> method, or as an argument to C<send>.

(Actually, the choice of default is delegated to
L<Email::Sender::Simple>, which makes its own choices.  But usually, it
uses C<sendmail>.)

=head2 Why use this?

Why not just use L<Email::Simple> or L<Email::MIME>? After all, this just adds
another layer of stuff around those. Wouldn't using them directly be better?

Certainly, if you know EXACTLY what you are doing. The docs are clear enough,
but you really do need to have an understanding of the structure of MIME
emails. This structure is going to be different depending on whether you have
text body, HTML, both, with or without an attachment etc.

Then there's brevity... compare the following roughly equivalent code.

First, the Email::Stuffer way.

  Email::Stuffer->to('Simon Cozens<simon@somewhere.jp>')
                ->from('Santa@northpole.org')
                ->text_body("You've been good this year. No coal for you.")
                ->attach_file('choochoo.gif')
                ->send;

And now doing it directly with a knowledge of what your attachment is, and
what the correct MIME structure is.

  use Email::MIME;
  use Email::Sender::Simple;
  use IO::All;
  
  Email::Sender::Simple->try_to_send(
    Email::MIME->create(
      header => [
          To => 'simon@somewhere.jp',
          From => 'santa@northpole.org',
      ],
      parts => [
          Email::MIME->create(
            body => "You've been a good boy this year. No coal for you."
          ),
          Email::MIME->create(
            body => io('choochoo.gif'),
            attributes => {
                filename => 'choochoo.gif',
                content_type => 'image/gif',
            },
         ),
      ],
    );
  );

Again, if you know MIME well, and have the patience to manually code up
the L<Email::MIME> structure, go do that, if you really want to.

Email::Stuffer as the name suggests, solves one case and one case only:
generate some stuff, and email it to somewhere, as conveniently as
possible. DWIM, but do it as thinly as possible and use the solid
Email:: modules underneath.

=head1 COOKBOOK

Here is another example (maybe plural later) of how you can use
Email::Stuffer's brevity to your advantage.

=head2 Custom Alerts

  package SMS::Alert;
  use base 'Email::Stuffer';
  
  sub new {
    shift()->SUPER::new(@_)
           ->from('monitor@my.website')
           # Of course, we could have pulled these from
           # $MyConfig->{support_tech} or something similar.
           ->to('0416181595@sms.gateway')
           ->transport('SMTP', { host => '123.123.123.123' });
  }

Z<>

  package My::Code;

  unless ( $Server->restart ) {
          # Notify the admin on call that a server went down and failed
          # to restart.
          SMS::Alert->subject("Server $Server failed to restart cleanly")
                    ->send;
  }

=head1 METHODS

As you can see from the synopsis, all methods that B<modify> the
Email::Stuffer object returns the object, and thus most normal calls are
chainable.

However, please note that C<send>, and the group of methods that do not
change the Email::Stuffer object B<do not> return the object, and thus
B<are not> chainable.

=cut

use 5.005;
use strict;
use Carp                   qw(croak);
use File::Basename         ();
use Params::Util 1.05      qw(_INSTANCE _INSTANCEDOES);
use Email::MIME 1.920      ();
use Email::MIME::Creator   ();
use Email::Sender::Simple  ();
use Module::Runtime        qw(require_module);

#####################################################################
# Constructor and Accessors

=method new

Creates a new, empty, Email::Stuffer object.

You can pass a hashref of properties to set, including:

=for :list
* to
* from
* cc
* bcc
* subject
* text_body
* html_body
* transport

=cut

my %IS_INIT_ARG = map {; $_ => 1 } qw(
  to from cc bcc subject text_body html_body transport
);

sub new {
    Carp::croak("new method called on Email::Stuffer instance") if ref $_[0];

    my ( $class, $arg ) = @_;

    my $self = bless {
        text_parts   => [],
        attach_parts => [],
        email        => Email::MIME->create(
            header => [],
            parts  => [],
        ),
    }, $class;

    my @init_args = keys %{ $arg || {} };
    if ( my @bogus = grep { ; !$IS_INIT_ARG{$_} } @init_args ) {
        Carp::croak("illegal arguments to Email::Stuffer->new: @bogus");
    }

    for my $init_arg (@init_args) {
        $self->$init_arg( $arg->{$init_arg} );
    }

    $self;
}

sub _self {
	my $either = shift;
	ref($either) ? $either : $either->new;
}

=method header_names

Returns, as a list, all of the headers currently set for the Email
For backwards compatibility, this method can also be called as B[headers].

=cut

sub header_names {
	shift()->{email}->header_names;
}

sub headers {
	shift()->{email}->header_names; ## This is now header_names, headers is depreciated
}

=method text_parts

Returns, as a list, the L<Email::MIME> parts for the Email to text.

=cut

sub text_parts {
	grep { defined $_ } @{shift()->{text_parts}};
}

=method attach_parts

Returns, as a list, the L<Email::MIME> parts for the Email relating to
attachments.

=cut

sub attach_parts {
	grep { defined $_ } @{shift()->{attach_parts}};
}

#####################################################################
# Header Methods

=method header $header => $value

Sets a named header in the email. Multiple calls with the same $header
will overwrite previous calls $value.

=cut

sub header {
	my $self = shift()->_self;
	return unless @_;
	$self->{email}->header_str_set(ucfirst shift, shift);
	return $self;
}

=method to $address

Sets the To: header in the email

=cut

sub to {
	my $self = shift()->_self;
	Carp::croak("to is a required field") unless defined $_[0];
	$self->{email}->header_str_set(To => join(q{, }, @_));
	return $self;
}

=method from $address

Sets the From: header in the email

=cut

sub from {
	my $self = shift()->_self;
	Carp::croak("from is a required field") unless defined $_[0];
	$self->{email}->header_str_set(From => shift);
	return $self;
}

=method cc $address

Sets the Cc: header in the email

=cut

sub cc {
	my $self = shift()->_self;
	$self->{email}->header_str_set(Cc => join(q{, }, @_));
	return $self;
}

=method bcc $address

Sets the Bcc: header in the email

=cut

sub bcc {
	my $self = shift()->_self;
	$self->{email}->header_str_set(Bcc => join(q{, }, @_));
	return $self;
}

=method subject $text

Sets the Subject: header in the email

=cut

sub subject {
	my $self = shift()->_self;
	Carp::croak("subject is a required field") unless defined $_[0];
	$self->{email}->header_str_set(Subject => shift);
	return $self;
}

#####################################################################
# Body and Attachments

=method text_body $body [, $header => $value, ... ]

Sets the text body of the email. Unless specified, all the appropriate
headers are set for you. You may override any as needed. See
L<Email::MIME> for the actual headers to use.

If C<$body> is undefined, this method will do nothing.

=cut

sub text_body {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return $self;
	my %attr = (
		# Defaults
		content_type => 'text/plain',
		charset      => 'utf-8',
		encoding     => 'quoted-printable',
		format       => 'flowed',
		# Params overwrite them
		@_,
		);

	# Create the part in the text slot
	$self->{text_parts}->[0] = Email::MIME->create(
		attributes => \%attr,
		body_str   => $body,
		);

	$self;
}

=method html_body $body [, $header => $value, ... ]

Set the HTML body of the email. Unless specified, all the appropriate
headers are set for you. You may override any as needed. See
L<Email::MIME> for the actual headers to use.

If C<$body> is undefined, this method will do nothing.

=cut

sub html_body {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return $self;
	my %attr = (
		# Defaults
		content_type => 'text/html',
		charset      => 'utf-8',
		encoding     => 'quoted-printable',
		# Params overwrite them
		@_,
		);

	# Create the part in the HTML slot
	$self->{text_parts}->[1] = Email::MIME->create(
		attributes => \%attr,
		body_str   => $body,
		);

	$self;
}

=method attach $contents [, $header => $value, ... ]

Adds an attachment to the email. The first argument is the file contents
followed by (as for text_body and html_body) the list of headers to use.
Email::Stuffer should TRY to guess the headers right, but you may wish
to provide them anyway to be sure. Encoding is Base64 by default.

=cut

sub _detect_content_type {
	my ($filename, $body) = @_;

	if (defined($filename)) {
		if ($filename =~ /\.([a-zA-Z]{3,4})\z/) {
			my $content_type = {
				'gif'  => 'image/gif',
				'png'  => 'image/png',
				'jpg'  => 'image/jpeg',
				'jpeg' => 'image/jpeg',
				'txt'  => 'text/plain',
				'htm'  => 'text/html',
				'html' => 'text/html',
				'css'  => 'text/css',
				'pdf'  => 'application/pdf',
				'wav'  => 'audio/wav',
			}->{lc($1)};
			return $content_type if defined $content_type;
		}
	}
	if ($body =~ /
		\A(?:
		    (GIF8)          # gif
		  | (\xff\xd8)      # jpeg
		  | (\x89PNG)       # png
		  | (%PDF-)         # pdf
		)
	/x) {
		return 'image/gif'  if $1;
		return 'image/jpeg' if $2;
		return 'image/png'  if $3;
		return 'application/pdf' if $4;
	}
	return 'application/octet-stream';
}

sub attach {
	my $self = shift()->_self;
	my $body = defined $_[0] ? shift : return undef;
	my %attr = (
		# Cheap defaults
		encoding => 'base64',
		# Params overwrite them
		@_,
		);

	# The more expensive defaults if needed
	unless ( $attr{content_type} ) {
		$attr{content_type} = _detect_content_type($attr{filename}, $body);
	}

	### MORE?

	# Create the part in the attachment slot
	push @{$self->{attach_parts}}, Email::MIME->create(
		attributes => \%attr,
		body       => $body,
		);

	$self;
}

=method attach_file $file [, $header => $value, ... ]

Attachs a file that already exists on the filesystem to the email. 
C<attach_file> will auto-detect the MIME type, and use the file's
current name when attaching.

=cut

sub attach_file {
	my $self = shift;
	my $body_arg = shift;
	my $name = undef;
	my $body = undef;

	# Support IO::All::File arguments
	if ( Params::Util::_INSTANCE($body_arg, 'IO::All::File') ) {
		$body_arg->binmode;
		$name = $body_arg->name;
		$body = $body_arg->all;

	# Support file names
	} elsif ( defined $body_arg and Params::Util::_STRING($body_arg) ) {
		croak "No such file '$body_arg'" unless -f $body_arg;
		$name = $body_arg;
		$body = _slurp( $body_arg );

	# That's it
	} else {
		my $type = ref($body_arg) || "<$body_arg>";
		croak "Expected a file name or an IO::All::File derivative, got $type";
	}

	# Clean the file name
	$name = File::Basename::basename($name);

	croak("basename somehow returned undef") unless defined $name;

	# Now attach as normal
	$self->attach( $body, name => $name, filename => $name, @_ );
}

# Provide a simple _slurp implementation
sub _slurp {
	my $file = shift;
	local $/ = undef;

	open my $slurp, '<:raw', $file or croak("error opening $file: $!");
	my $source = <$slurp>;
	close( $slurp ) or croak "error after slurping $file: $!";
	\$source;
}

=method transport

  $stuffer->transport( $moniker, @options )

or

  $stuffer->transport( $transport_obj )

The C<transport> method specifies the L<Email::Sender> transport that
you want to use to send the email, and any options that need to be
used to instantiate the transport.  C<$moniker> is used as the transport
name; if it starts with an equals sign (C<=>) then the text after the
sign is used as the class.  Otherwise, the text is prepended by
C<Email::Sender::Transport::>.  In neither case will a module be
automatically loaded.

Alternatively, you can pass a complete transport object (which must be
an L<Email::Sender::Transport> object) and it will be used as is.

=cut

sub transport {
	my $self = shift;

	if ( @_ ) {
		# Change the transport
		if ( _INSTANCEDOES($_[0], 'Email::Sender::Transport') ) {
			$self->{transport} = shift;
		} else {
		  my ($moniker, @arg) = @_;
		  my $class = $moniker =~ s/\A=//
		            ? $moniker
		            : "Email::Sender::Transport::$moniker";
		  require_module($class);
			my $transport = $class->new(@arg);
			$self->{transport} = $transport;
		}
	}

	$self;
}

#####################################################################
# Output Methods

=method email

Creates and returns the full L<Email::MIME> object for the email.

=cut

sub email {
    my $self       = shift;
    my @text_parts = $self->text_parts;
    my @parts      = $self->attach_parts;

    if ( scalar(@text_parts) > 1 ) {
        my $text_mime =
          Email::MIME->create(
            header => [ 'Content-Type' => 'multipart/alternative' ] );
        $text_mime->parts_set( \@text_parts );
        unshift @parts, $text_mime;
    }
    elsif ( scalar(@text_parts) == 1 ) {
        ## As @text_parts is $self->text_parts without the blanks, we only need check
        ## $parts[0]
        ## single part text/plain OR text/html
        unshift @parts, $text_parts[0];
    }

    if ( scalar(@parts) > 1 ) {
        ## More than one part, so use multipart/mixed
        $self->{email}->header_set( 'Content-Type' => 'multipart/mixed' );
        $self->{email}->parts_set( \@parts );
    }
    else {
        # Just one part: text, html or attachment
        _transfer_headers( $self->{email}, $parts[0] );
        $self->{email} = $parts[0];
    }

    return $self->{email};
}

# Support coercion to an Email::MIME
sub __as_Email_MIME { shift()->email }

# Quick any routine
sub _any (&@) {
        my $f = shift;
        return if ! @_;
        for (@_) {
                return 1 if $f->();
        }
        return 0;
}

# header transfer from one object to another
sub _transfer_headers {
        # $_[0] = from, $_[1] = to
        my @headers_move = $_[0]->header_names;
        my @headers_skip = $_[1]->header_names;
        foreach my $header_name (@headers_move) {
                next if _any { $_ eq $header_name } @headers_skip;
                my @values = $_[0]->header($header_name);
                $_[1]->header_str_set( $header_name, @values );
        }
}

=method as_string

Returns the string form of the email. Identical to (and uses behind the
scenes) Email::MIME-E<gt>as_string.

=cut

sub as_string {
	shift()->email->as_string;
}

=method send

Sends the email via L<Email::Sender::Simple>.

On failure, returns false.

=cut

sub send {
	my $self = shift;
	my $arg  = shift;
	my $email = $self->email or return undef;

	my $transport = $self->{transport};

	Email::Sender::Simple->try_to_send(
	  $email,
	  {
      ($transport ? (transport => $transport) : ()),
      $arg ? %$arg : (),
    },
  );
}

=method send_or_die

Sends the email via L<Email::Sender::Simple>.

On failure, throws an exception.

=cut

sub send_or_die {
	my $self = shift;
	my $arg  = shift;
	my $email = $self->email or return undef;

	my $transport = $self->{transport};

	Email::Sender::Simple->send(
	  $email,
	  {
      ($transport ? (transport => $transport) : ()),
      $arg ? %$arg : (),
    },
  );
}

1;

=head1 TO DO

=for :list
* Fix a number of bugs still likely to exist
* Write more tests.
* Add any additional small bit of automation that isn't too expensive

=head1 SEE ALSO

L<Email::MIME>, L<Email::Sender>, L<http://ali.as/>

=cut
