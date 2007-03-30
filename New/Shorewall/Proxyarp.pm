#
# Shorewall-perl 3.9 -- /usr/share/shorewall-perl/Shorewall/Proxyarp.pm
#
#     This program is under GPL [http://www.gnu.org/copyleft/gpl.htm]
#
#     (c) 2007 - Tom Eastep (teastep@shorewall.net)
#
#       Complete documentation is available at http://shorewall.net
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of Version 2 of the GNU General Public License
#       as published by the Free Software Foundation.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA
#
#
package Shorewall::Proxyarp;
require Exporter;
use Shorewall::Common;
use Shorewall::Config;
use Shorewall::Interfaces;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( 
		  setup_proxy_arp
		  dump_proxy_arp
		  );

our @EXPORT_OK = qw( );
our @VERSION = 1.00;

my @proxyarp;

sub setup_one_proxy_arp( $$$$$ ) {
    my ( $address, $interface, $external, $haveroute, $persistent) = @_;

    if ( "\L$haveroute" eq 'no' || $haveroute eq '-' ) {
	$haveroute = '';
    } elsif ( "\L$haveroute" eq 'yes' ) {
	$haveroute = 'yes';
    } else {
	fatal_error "Invalid value ($haveroute) for HAVEROUTE";
    }

    if ( "\L$persistent" eq 'no' || $persistent eq '-' ) {
	$persistent = '';
    } elsif ( "\L$persistent" eq 'yes' ) {
	$persistent = 'yes';
    } else {
	fatal_error "Invalid value ($persistent) for PERSISTENT";
    }

    unless ( $haveroute ) {
	emit "[ -n \"\$NOROUTES\" ] || run_ip route replace $address dev $interface";
	$haveroute = 1 if $persistent;
    }

    emit "if ! arp -i $external -Ds $address $external pub; then
    fatal_error \"Command 'arp -i $external -Ds $address $external pub' failed\"
fi

progress_message \"   Host $address connected to $interface added to ARP on $external\"\n";

    push @proxyarp, "$address $interface $external $haveroute";

    progress_message "   Host $address connected to $interface added to ARP on $external";
}

#
# Setup Proxy ARP
#
sub setup_proxy_arp() {

    my $interfaces= find_interfaces_by_option 'proxyarp';

    if ( @$interfaces || open_file 'proxyarp' ) {

	save_progress_message "Setting up Proxy ARP...";

	my ( %set, %reset );

	while ( read_a_line ) {

	    my ( $address, $interface, $external, $haveroute, $persistent ) = split_line 5, 'proxyarp file';

	    $set{$interface}  = 1;
	    $reset{$external} = 1 unless $set{$external};

	    setup_one_proxy_arp( $address, $interface, $external, $haveroute, $persistent );
	}

	for my $interface ( keys %reset ) {
	    emit "echo 0 > /proc/sys/net/ipv4/conf/$interface/proxy_arp" unless $set{interface};
	}

	for my $interface ( keys %set ) {
	    emit "echo 1 > /proc/sys/net/ipv4/conf/$interface/proxy_arp";
	}

	for my $interface ( @$interfaces ) {
	    emit "if [ -f /proc/sys/net/ipv4/conf/$interface/proxy_arp ] ; then
    echo 1 > /proc/sys/net/ipv4/conf/$interface/proxy_arp
else
    error_message \"WARNING: Unable to enable proxy ARP on $interface\"
fi\n";
	}
    }
}

sub dump_proxy_arp() {
    for $line ( @proxyarp ) {
	emit_unindented $line;
    }
}

1;
