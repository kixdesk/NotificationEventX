# --
# NotificationEventX.pm - code run during package de-/installation
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

package var::packagesetup::NotificationEventX;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::NotificationEvent',
    'Kernel::System::Package',
    'Kernel::System::SysConfig',
);

=head1 NAME

NotificationEventX.pm - code to excecute during package installation

=head1 SYNOPSIS

All functions

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CodeObject = $Kernel::OM->Get('var::packagesetup::NotificationEventX');

=cut

sub new {
    my ( $Type, %Param ) = @_;
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects...
    $Self->{ConfigObject}            = $Kernel::OM->Get('Kernel::Config');
    $Self->{DBObject}                = $Kernel::OM->Get('Kernel::System::DB');
    $Self->{DynamicFieldObject}      = $Kernel::OM->Get('Kernel::System::DynamicField');
    $Self->{NotificationEventObject} = $Kernel::OM->Get('Kernel::System::NotificationEvent');
    $Self->{PackageObject}           = $Kernel::OM->Get('Kernel::System::Package');

    # rebuild ZZZ* files
    $Kernel::OM->Get('Kernel::System::SysConfig')->WriteDefault();

    # define the ZZZ files
    my @ZZZFiles = (
        'ZZZAAuto.pm',
        'ZZZAuto.pm',
    );

    # reload the ZZZ files (mod_perl workaround)
    for my $ZZZFile (@ZZZFiles) {

        PREFIX:
        for my $Prefix (@INC) {
            my $File = $Prefix . '/Kernel/Config/Files/' . $ZZZFile;
            next PREFIX if !-f $File;

            do $File;
            last PREFIX;
        }
    }
    return $Self;
}

=item CodeInstall()

run the code install part

    my $Result = $CodeObject->CodeInstall();

=cut

sub CodeInstall {
    my ( $Self, %Param ) = @_;

    # run integrated migration from EventbasedNotificationDFContacts...
    $Self->_MigrateFromEventbasedNotificationDFContacts();

    return 1;
}

=item CodeReinstall()

run the code reinstall part

    my $Result = $CodeObject->CodeReinstall();

=cut

sub CodeReinstall {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item CodeUpgrade()

run the code upgrade part

    my $Result = $CodeObject->CodeUpgrade();

=cut

sub CodeUpgrade {
    my ( $Self, %Param ) = @_;

    return 1;
}

=item CodeUpgrade_5()

run the code upgrade part for versions before framework 5

    my $Result = $CodeObject->CodeUpgrade_5();

=cut

sub CodeUpgrade_5 {
    my ( $Self, %Param ) = @_;

    # migrate old params
    $Self->_MigrateParamsBefore5();

    return 1;
}

=item CodeUpgrade_5_1()

run the code upgrade part for versions before version 5.1

    my $Result = $CodeObject->CodeUpgrade_5_1();

=cut

sub CodeUpgrade_5_0_3 {
    my ( $Self, %Param ) = @_;

    # migrate old params
    $Self->_MigrateParamsBefore5_0_3();
    return 1;
}
=item CodeUninstall()

run the code uninstall part

    my $Result = $CodeObject->CodeUninstall();

=cut

sub CodeUninstall {
    my ( $Self, %Param ) = @_;

    # clean up special params from notifications...
    $Self->_RemoveNotificationXParams();

    return 1;

}

#-------------------------------------------------------------------------------
# Internal functions
sub _MigrateFromEventbasedNotificationDFContacts {
    my ( $Self, %Param ) = @_;

    if ( $Self->{PackageObject}->PackageIsInstalled( Name => 'EventbasedNotificationDFContacts' ) ) {
        # get data from database
        my %Notifications = ();
        my $SQL = 'SELECT notification_name, df_section, df_selection, article_type'
            . ' FROM notification_event_df_rcpt';

        my $Success = $Self->{DBObject}->Prepare(
            SQL   => $SQL,
        );
        if ( !$Success ) {
            return;
        }

        while (my @Row = $Self->{DBObject}->FetchrowArray()) {
            $Notifications{$Row[0]}->{$Row[1]}->{Selection}   = $Row[2];
            $Notifications{$Row[0]}->{$Row[1]}->{ArticleType} = $Row[3];
        }

        # get dynamic fields
        my $DynamicFieldList = $Self->{DynamicFieldObject}->DynamicFieldListGet(
            Valid      => 1,
            ObjectType => ['Ticket'],
        );

        # create a dynamic field config lookup table
        my %DynamicFieldConfigLookup;
        for my $DynamicFieldConfig ( @{ $DynamicFieldList } ) {
            $DynamicFieldConfigLookup{ $DynamicFieldConfig->{Name} } = $DynamicFieldConfig->{ID};
        }

        # get notification list
        my %NotificationList = $Self->{NotificationEventObject}->NotificationList();

        # process notifications
        for my $Notification ( keys( %Notifications ) ) {
            my $NotificationID;
            for my $ID ( keys( %NotificationList ) ) {
                if ( $NotificationList{$ID} eq $Notification ) {
                    $NotificationID = $ID;
                    last;
                }
            }
            my %NotificationData = $Self->{NotificationEventObject}->NotificationGet(
                ID => $NotificationID,
            );

            # process sections
            for my $Section ( keys( %{ $Notifications{$Notification} } ) ) {
                my $Type = 'XRecipientCustomerDF';
                if ($Notifications{$Notification}->{$Section}->{ArticleType} eq 'Agent') {
                    $Type = 'XRecipientAgentDF';
                }

                my @DynamicFields = split(/,/, $Notifications{$Notification}->{$Section}->{Selection});
                for my $Field ( @DynamicFields ) {
                    next if (!$DynamicFieldConfigLookup{$Field});

                    # add field
                    push(@{$NotificationData{Data}->{$Type}}, $DynamicFieldConfigLookup{$Field});
                }
            }

            # update notification
            $Self->{NotificationEventObject}->NotificationUpdate(
                %NotificationData,
                UserID => 1,
            );
        }

        # uninstall Packages...
        my @RepositoryList = $Self->{PackageObject}->RepositoryList();
        my @ReversePackageList = reverse @RepositoryList;
        my @RemovePackages = ( "EventbasedNotificationDFContacts" );
        for my $Package (@ReversePackageList) {
            for my $RemovePackage (@RemovePackages) {
                if ( $Package->{Name}->{Content} eq $RemovePackage ) {

                    # get package content from repository for uninstall
                    my $PackageContent = $Self->{PackageObject}->RepositoryGet(
                        Name    => $Package->{Name}->{Content},
                        Version => $Package->{Version}->{Content},
                    );

                    # uninstall the package
                    $Self->{PackageObject}->PackageUninstall(
                        String => $PackageContent,
                    );
                }
            }
        }
    }

    return 1;
}

sub _RemoveNotificationXParams {
    my ( $Self, %Param ) = @_;

    # get notifications
    my %List = $Self->{NotificationEventObject}->NotificationList();

    # process notifications
    for my $NotificationID ( keys( %List ) ) {
        # get notification
        my %Notification = $Self->{NotificationEventObject}->NotificationGet(
            ID => $NotificationID
        );

        # remember changes
        my $Changed = 0;

        # process possible params
        for (
            qw(
            RecipientAgentDF RecipientCustomerDF
            RecipientSubject
            )
        ) {
            if ( defined($Notification{Data}->{$_}) ) {
                $Changed = 1;
                delete($Notification{Data}->{$_});
            }
        }

        # update notification if needed
        if ( $Changed ) {
            $Self->{NotificationEventObject}->NotificationUpdate(
                %Notification,
                UserID => 1,
            );
        }
    }

    return 1;
}

sub _MigrateParamsBefore5 {
    my ( $Self, %Param ) = @_;

    # get notifications
    my %List = $Self->{NotificationEventObject}->NotificationList();

    # process notifications
    for my $NotificationID ( keys( %List ) ) {
        # get notification
        my %Notification = $Self->{NotificationEventObject}->NotificationGet(
            ID => $NotificationID
        );

        # remember changes
        my $Changed = 0;

        # process params
        if ( defined($Notification{Data}->{XCrypt}) ) {
            $Changed = 1;
            $Notification{Data}->{RecipientCrypt} = $Notification{Data}->{XCrypt};
            delete($Notification{Data}->{XCrypt});
        }
        if ( defined($Notification{Data}->{XSign}) ) {
            $Changed = 1;
            $Notification{Data}->{RecipientSign} = $Notification{Data}->{XSign};
            delete($Notification{Data}->{XSign});
        }
        if ( defined($Notification{Data}->{XRecipientAgentDF}) ) {
            $Changed = 1;
            $Notification{Data}->{RecipientAgentDF} = $Notification{Data}->{XRecipientAgentDF};
            delete($Notification{Data}->{XRecipientAgentDF});
        }
        if ( defined($Notification{Data}->{XRecipientCustomerDF}) ) {
            $Changed = 1;
            $Notification{Data}->{RecipientCustomerDF} = $Notification{Data}->{XRecipientCustomerDF};
            delete($Notification{Data}->{XRecipientCustomerDF});
        }

        # update notification if needed
        if ( $Changed ) {
            $Self->{NotificationEventObject}->NotificationUpdate(
                %Notification,
                UserID => 1,
            );
        }
    }

    return 1;
}

sub _MigrateParamsBefore5_0_3 {
    my ( $Self, %Param ) = @_;

    my $CryptType;
    if ($Self->{ConfigObject}->Get('PGP')) {
        $CryptType = 'PGP';
    } elsif ($Self->{ConfigObject}->Get('SMIME')) {
        $CryptType = 'SMIME';
    }

    # get notifications
    my %List = $Self->{NotificationEventObject}->NotificationList();

    # process notifications
    for my $NotificationID ( keys( %List ) ) {
        # get notification
        my %Notification = $Self->{NotificationEventObject}->NotificationGet(
            ID => $NotificationID
        );

        # remember changes
        my $Changed = 0;
        my $Crypt   = '';
        my $CryptX  = 'Send';
        my $Sign    = '';
        my $SignX   = 'Send';

        # process params

        if ($CryptType) {
            if (
                defined($Notification{Data}->{RecipientCrypt})
                && defined($Notification{Data}->{RecipientCrypt}->[0])
                && $Notification{Data}->{RecipientCrypt}->[0]
            ) {
                $Changed = 1;
                $Crypt = 'Crypt';
                if ($Notification{Data}->{RecipientCrypt}->[0] == 2) {
                    $CryptX = 'Skip';
                }
                delete($Notification{Data}->{RecipientCrypt});
            }
            if (
                defined($Notification{Data}->{RecipientSign})
                && defined($Notification{Data}->{RecipientSign}->[0])
                && $Notification{Data}->{RecipientSign}->[0]
            ) {
                $Changed = 1;
                $Sign = 'Sign';
                if ($Notification{Data}->{RecipientSign}->[0] == 2) {
                    $SignX = 'Skip';
                }
                delete($Notification{Data}->{RecipientSign});
            }
            if ( $Changed ) {
                push (@{$Notification{Data}->{EmailSecuritySettings}}, '1');
                push (@{$Notification{Data}->{EmailSigningCrypting}}, $CryptType . $Sign . $Crypt);
                push (@{$Notification{Data}->{EmailMissingCryptingKeys}}, $CryptX);
                push (@{$Notification{Data}->{EmailMissingSigningKeys}}, $SignX);
            }
        }

        # update notification if needed
        if ( $Changed ) {
            $Self->{NotificationEventObject}->NotificationUpdate(
                %Notification,
                UserID => 1,
            );
        }
    }

    return 1;
}
# EO Internal functions
#-------------------------------------------------------------------------------

1;

=back

=head1 TERMS AND CONDITIONS

This Software is part of the OTRS project (http://otrs.org/).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (GPL). If you
did not receive this file, see http://www.gnu.org/licenses/agpl.txt.

=cut

#-------------------------------------------------------------------------------

=head1 VERSION
$Revision$ $Date$
=cut
