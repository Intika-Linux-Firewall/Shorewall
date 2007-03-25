#
# Shorewall 3.9 -- /usr/share/shorewall-pl/Shorewall/Proc.pm
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
package Shorewall::Proc;
require Exporter;
use Shorewall::Common;
use Shorewall::Config;
use Shorewall::Zones;
use Shorewall::Chains;
use Shorewall::Interfaces;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(
		 setup_arp_filtering
		 setup_route_filtering
		 setup_martian_logging
		 setup_source_routing
		 setup_forwarding
		 );
our @EXPORT_OK = qw( );
our @VERSION = 1.00;


our %macros;

#
# ARP Filtering
#
sub setup_arp_filtering() {
    save_progress_message "Setting up ARP filtering...";

    emit "for f in /proc/sys/net/ipv4/conf/*; do
    [ -f \$f/arp_filter ] && echo 0 > \$f/arp_filter
    [ -f \$f/arp_ignore ] && echo 0 > \$f/arp_ignore
done
";

    emit '';

    my $interfaces  = find_interfaces_by_option 'arp_filter';
    my $interfaces1 = find_interfaces_by_option 'arp_ignore';

    if ( @$interfaces || @$interfaces1 ) {
	progress_message2 "$doing ARP Filtering...";

	for my $interface ( @$interfaces ) {
	    my $file = "/proc/sys/net/ipv4/conf/$interface/arp_filter";
	    emit "
if [ -f $file ]; then
    echo 1 > $file
else
    error_message \"WARNING: Cannot set ARP filtering on $interface\"
fi
";
	}

	for my $interface ( @$interfaces1 ) {
	    my $file  = "/proc/sys/net/ipv4/conf/$interface/arp_ignore";
	    my $value = get_interface_option $interface, 'arp_ignore';
	    
	    fatal_error "Internal Error in setup_arp_filtering()" unless defined $value;

	    emit "if [ -f $file ]; then
    echo $value > $file
else
    error_message \"WARNING: Cannot set ARP filtering on $interface\"
fi
";
	}
    }
}

#
# Route Filtering
#
sub setup_route_filtering() {

    my $interfaces = find_interfaces_by_option 'routefilter';

    if ( @$interfaces || $config{ROUTE_FILTER} ) {
	
	progress_message2 "$doing Kernel Route Filtering...";

	save_progress_message "Setting up Route Filtering...";

	emit "for f in /proc/sys/net/ipv4/conf/*; do
    [ -f \$f/log_martians ] && echo 0 > \$f/rp_filter
done
";

	for my $interface ( @$interfaces ) {
	    my $file = "/proc/sys/net/ipv4/conf/$interface/rp_filter";

	    emit "if [ -f $file ]; then
    echo 1 > $file
else
    error_message \"WARNING: Cannot set route filtering on $interface\"
fi
";
	}
	
	emit 'echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter';

	if ( $config{ROUTE_FILTER} ) {
	    emit 'echo 1 > /proc/sys/net/ipv4/conf/default/rp_filter';
	    emit 'echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter';
	}

	emit "[ -n \"\$NOROUTES\" ] || ip route flush cache";
    }
}

#
# Martian Logging
#

sub setup_martian_logging() {
    my $interfaces = find_interfaces_by_option 'logmartians';

    if ( @$interfaces || $config{LOG_MARTIANS} ) {
	
	progress_message2 "$doing Martian Logging...";

	save_progress_message "Setting up Martian Logging...";

	emit "for f in /proc/sys/net/ipv4/conf/*; do
    [ -f \$f/log_martians ] && echo 0 > \$f/log_martians
done
";

	for my $interface ( @$interfaces ) {
	    my $file = "/proc/sys/net/ipv4/conf/$interface/log_martians";

	    emit "if [ -f $file ]; then
    echo 1 > $file
else
    error_message \"WARNING: Cannot set Martian logging on $interface\"
fi
";
	}
	
	emit 'echo 1 > /proc/sys/net/ipv4/conf/all/log_martians';

	if ( $config{LOG_MARTIANS} ) {
	    emit 'echo 1 > /proc/sys/net/ipv4/conf/default/log_martians';
	    emit 'echo 1 > /proc/sys/net/ipv4/conf/all/log_martians';
	}

    }
}
    
#
# Source Routing
#
sub setup_source_routing() {

    save_progress_message 'Setting up Accept Source Routing...';

    emit "for f in /proc/sys/net/ipv4/conf/*; do
    [ -f \$f/accept_source_route ] && echo 0 > \$f/accept_source_route
done
";

    my $interfaces = find_interfaces_by_option 'sourceroute';

    if ( @$interfaces ) {
	progress_message2 "$doing Accept Source Routing...";

	save_progress_message 'Setting up Source Routing...';

	for my $interface ( @$interfaces ) {
	    my $file = "/proc/sys/net/ipv4/conf/$interface/accept_source_route";

	    emit "if [ -f $file ]; then
    echo 1 > $file
else
    error_message \"WARNING: Cannot set Accept Source Routing on $interface\"
fi
";
	}
    }
}

sub setup_forwarding() {
    if ( "\L$config{IP_FORWARDING}" eq 'on' ) {
	emit 'echo 1 > /proc/sys/net/ipv4/ip_forward';
	emit 'progress_message2 IP Forwarding Enabled';
    } elsif ( "\L$config{IP_FORWARDING}" eq 'off' ) {
	emit 'echo 0 > /proc/sys/net/ipv4/ip_forward';
	emit 'progress_message2 IP Forwarding Disabled!';
    }

    emit '';
}

1;
