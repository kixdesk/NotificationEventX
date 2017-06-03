# --
# Kernel/Language/de_NotificationEventX.pm - provides german language
# translation for NotificationEventX
# Copyright (C) 2006-2015 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Mario(dot)Illinger(at)cape(dash)it(dot)de
# --
# $Id$
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Language::de_NotificationEventX;

use strict;
use warnings;
use utf8;

sub Data {
    my $Self = shift;
    my $Lang = $Self->{Translation};

    return if ref $Lang ne 'HASH';

    # $$START$$

    # general translation...
    $Lang->{'if possible'}          = 'Wenn möglich';
    $Lang->{'mandatory'}            = 'Zwingend';
    $Lang->{'With Ticketnumber'}    = 'Mit Ticketnummer';
    $Lang->{'Without Ticketnumber'} = 'Ohne Ticketnummer';

    # Agent Overlay
    $Lang->{'Agent Notifications'}                  = 'Agentenbenachrichtungen';
    $Lang->{'Agent Notification (Popup/Dashboard)'} = 'Agentenbenachrichtung (Popup/Dashboard)';
    $Lang->{'Decay'}                                = 'Verfallszeit';
    $Lang->{'BusinessTime'}                         = 'Geschäftszeit';

    return 0;

    # $$STOP$$
}

1;
