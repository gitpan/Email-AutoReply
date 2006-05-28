package Email::AutoReply::Recipient;
our $rcsid = '$Id: Recipient.pm 843 2004-08-25 22:31:04Z adamm $';

use strict;
use warnings;

use Spiffy '-Base';

=head1 NAME

Email::AutoReply::Recipient - recipient of an autoreply

=head1 DESCRIPTION

This simple object wraps a recipient of an L<Email::AutoReply> autoresponse.

=head2 ATTRIBUTES

=over 4

=item B<email>

Set/get the email address of this recipient. Expect the value to be something
like C<adamm@example.com>, ie: an email address without any decorations.

=cut

field 'email';

=item B<timestamp>

Set/get the timestamp for this recipient. This is a UNIX timestamp
(seconds since the epoch) representing when this person received an
autoresponse.

=cut

field 'timestamp';

return 1;

__END__

=back

=head1 AUTHOR

Adam Monsen, <adamm@wazamatta.com>

=head1 SEE ALSO

L<Email::AutoReply>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2004 by Adam Monsen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.3 or,
at your option, any later version of Perl 5 you may have available.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
