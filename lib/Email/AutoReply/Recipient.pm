package Email::AutoReply::Recipient;
our $rcsid = '$Id: Recipient.pm,v 1.1.1.1 2004/08/25 02:23:16 adamm Exp $';

use strict;
use warnings;

use Spiffy '-Base';

field 'email';
field 'timestamp';

return 1;
