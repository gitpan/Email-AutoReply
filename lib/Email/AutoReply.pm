package Email::AutoReply;
our $rcsid = '$Id: AutoReply.pm,v 1.7 2004/08/25 22:41:06 adamm Exp $';

use strict;
use warnings;

our $VERSION = '0.04';

=head1 NAME

Email::AutoReply - Perl extension for writing email autoresponders

=head1 SYNOPSIS

  use Email::AutoReply;
  my $auto = Email::AutoReply->new;
  $auto->reply;

=head1 DESCRIPTION

This module may be useful in writing autoresponders. The example code above
will try to respond (using Sendmail) to an email message given as standard
input.

The module will reply once to each email address it sees, storing
sent-to addresses in a database. This database class is
Email::AutoReply::DB::BerkeleyDB by default, but any class that
implements L<Email::AutoReply::DB> may be used.

=cut

use Spiffy '-Base';

use Carp qw(confess);
use Email::Address;
use Email::AutoReply::DB::BerkeleyDB;
use Email::Send ();
use Email::Simple;
use File::Path ();
use Mail::ListDetector;

=head2 ATTRIBUTES

All attributes are set and get using code similar to the following:

  $auto = new Email::AutoReply;

  # get debug status
  $dbg = $auto->debug;

  # set debug status to "on"
  $auto->debug(1);

=over 4

=item B<cachedb_type>

Set/get the class to use for the cache DB.

Default: 'Email::AutoReply::DB::BerkeleyDB'

=cut

field 'cachedb_type' => 'Email::AutoReply::DB::BerkeleyDB';

=item B<debug>

Set/get weather debugging is enabled. 0 means off, 1 means on.

Default: 0

=cut

field 'debug' => 0;

=item B<hostname>

Set/get the hostname where this package will be executed. This is used
when constructing a 'from' address for the autoreply and for adding an
X-Mail-AutoReply header to the autoreply.

Default: (the addressed-to domain in input_email)

=cut

field 'hostname' => 'localhost';

=item B<input_email>

Set/get the email to parse and reply to.

=cut

field 'input_email';

=item B<response_text>

Set/get the string which will serve as the body of the autoreply.

=cut

field response_text => <<'AutomatedResponse';
Sorry, the person you're trying to reach is unavailable.
This is an automated response from Mail::AutoReply. See
http://search.cpan.org/perldoc?Mail-AutoReply for more info.
AutomatedResponse

=item B<settings_dir>

Set/get the directory to in which to store Email::AutoReply settings.

Default: /home/$ENV{HOME}/.email-autoreply

=cut

field 'settings_dir' => "$ENV{HOME}/.email-autoreply";

=item B<send_method>

Set/get the Email::Send class used to send the autoreply.

Default: 'Sendmail'

=cut

field 'send_method' => 'Sendmail';

=item B<subject>

Set/get the subject to be used in the autoreply.

Default: 'Out Of Office Automated Response'

=cut

field 'subject' => 'Out Of Office Automated Response';

=item B<user>

Set/get the user who is executing this code. This is used when
constructing a 'from' address for the autoreply and for adding an
X-Mail-AutoReply header to the autoreply.

Default: (the addressed-to user in input_email)

=cut

field 'user';

### private fields
field '_cache_db';

=back

=head2 METHODS

=over 4

=item B<new>

Takes any attributes as arguments, or none:

  # set the debug and response_text attributes
  my $auto = Email::AutoReply->new(
    debug => 1, response_text => "I'm on vacation, ttyl."
  );

  # no arguments
  my $auto = Email::AutoReply->new;

Returns a new Email::AutoReply object.

=cut

sub new {
  $self = super;
  $self->_create_settings_dir();
  $self->_init_db();
  return $self;
}

sub _create_settings_dir {
  my $dir = $self->settings_dir;
  return if -d $dir;
  warn "making $dir" if $self->debug;
  eval {
    File::Path::mkpath($dir);
  };
  confess $@ if $@;
}

sub _init_db {
  my $db_class = $self->cachedb_type();
  my $db = $db_class->new(
    email_autoreply_settings_dir => $self->settings_dir()
  );
  $self->_cache_db($db);
}

sub _create_autoreply_from_address {
  my %args = (input_to => undef, @_);
  ref $args{input_to} eq 'Email::Address'
    or confess 'input_to must be an Email::Address object';
  my $rv;
  if ($self->user) {
    $self->hostname or confess "hostname not set!";
    $rv = $self->user . '@' . $self->hostname;
    $rv = new Email::Address->new(undef, $rv);
  } else {
    $rv = $args{input_to};
  }
  return $rv;
}

=item B<dbdump>

Takes no arguments.

Returns a list of emails in the "already sent to" database.

=cut

sub dbdump {
  return $self->_cache_db->fetch_all;
}

=item B<reply>

Takes no arguments. If the 'input_email' attribute is set, this class
will read that as the email to (possibly) autoreply to. If the
'input_email' attribute is not set, an email message will be extracted
from standard input.

No return value.

=cut

sub reply {
  my $input = $self->input_email;
  if (!$input) {
    local $/;
    $input = <STDIN>;
  }
  my $mail = new Email::Simple($input);
  my ($from) = Email::Address->parse($mail->header("From"));
  confess "couldn't parse a From address" if not $from;
  my ($from_address) = $from->address;
  my ($to) = Email::Address->parse($mail->header("To"));
  confess "couldn't parse a To address" if not $to;

  if (not $self->in_cache(email=>$from_address) and
      not $self->is_maillist_msg(mailobj=>$mail) and
      not $self->we_touched_it(mailobj=>$mail)) {

    my $bot_from_obj = $self->_create_autoreply_from_address(input_to => $to);
    my $bot_from = $bot_from_obj->address;
    my $bot_from_formatted = $bot_from_obj->format;

    my $autoreply_hdr =
      "version=$VERSION,host=" . $self->hostname . ",from=".$bot_from;
    my $reply = Email::Simple->new(''); # init w/empty string or it complains
    warn "sending autoreply to $from_address from $bot_from" if $self->debug;

    $reply->header_set('Subject', $self->subject);
    $reply->header_set('From', $bot_from_formatted);
    $reply->header_set('To', $from->format);
    $reply->header_set('X-Mail-AutoReply', $autoreply_hdr);
    $reply->body_set($self->response_text);
    # XXX -f adds envelope sender for sendmail only! This may break with
    # other Email::Send sending methods.
    Email::Send::send($self->send_method, $reply, "-f $bot_from");

    # cache the email address we just sent to
    # XXX what if email sending failed?
    my $recipient = Email::AutoReply::Recipient->new(
      email => $from_address, timestamp => time,
    );
    $self->_cache_db->store($recipient);
  
    # we replied, so keep track.
    # XXX doesn't matter unless we save this, so we should do that...
    $mail->header_set('X-Mail-AutoReply', $autoreply_hdr);
  } else {
    warn "NOT SENDING" if $self->debug;
  }
}

sub in_cache {
  my %args = (email => undef, @_);
  my $found =  $self->_cache_db->fetch($args{email}) ? 1 : 0;
  warn "$args{email} in cache? ... '$found' " if $self->debug;
  return $found ? 1 : 0;
}

sub is_maillist_msg {
  my %args = (mailobj => undef, @_);
  ref $args{mailobj} eq 'Email::Simple'
    or confess 'mailobj must be an Email::Simple object';
  defined($args{mailobj}) or confess "Must pass in mailobj";
  my $listobj = Mail::ListDetector->new($args{mailobj});
  warn "Is this a mailing list message? ".defined($listobj) if $self->debug;
  return defined $listobj;
}

sub we_touched_it {
  my %args = (mailobj => undef, @_);
  ref $args{mailobj} eq 'Email::Simple'
    or confess 'mailobj must be an Email::Simple object';
  defined($args{mailobj}) or confess 'Must pass in mailobj';
  return $args{mailobj}->header('X-Mail-AutoReply');
}

1;

__END__

=back

=head1 AUTHOR

Adam Monsen, <adamm@wazamatta.com>

=head1 BUGS

To report bugs, go to

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Email-AutoReply>

or send mail to <bug-Email-AutoReply@rt.cpan.org>

=head1 SEE ALSO

L<Email::Send>, L<Mail::Vacation>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Adam Monsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
