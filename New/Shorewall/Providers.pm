#
# Shorewall-pl 3.9 -- /usr/share/shorewall-pl/Shorewall/Providers.pm
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
package Shorewall::Providers;
require Exporter;
use Shorewall::Common;
use Shorewall::Config;
use Shorewall::Zones;
use Shorewall::Chains;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( setup_providers @routemarked_interfaces);
our @EXPORT_OK = ( );
our @VERSION = 1.00;

use constant { LOCAL_NUMBER   => 255,
	       MAIN_NUMBER    => 254,
	       DEFAULT_NUMBER => 253,
	       UNSPEC_NUMBER  => 0
	       };

our %routemarked_interfaces;
our @routemarked_interfaces;

my $balance             = 0;
my $first_default_route = 1;


my %providers  = ( 'local' => { number => LOCAL_NUMBER   , mark => 0 } ,
		   main    => { number => MAIN_NUMBER    , mark => 0 } ,
		   default => { number => DEFAULT_NUMBER , mark => 0 } ,
		   unspec  => { number => UNSPEC_NUMBER  , mark => 0 } );

my @providers;

#
# Set up marking for 'tracked' interfaces. Unline in Shorewall 3.x, we add these rules inconditionally, even if the associated interface isn't up.
#
sub setup_route_marking() {
    my $mask    = $config{HIGH_ROUTE_MARKS} ? '0xFFFF' : '0xFF';
    my $mark_op = $config{HIGH_ROUTE_MARKS} ? '--or-mark' : '--set-mark';

    add_rule $mangle_table->{PREROUTING} , "-m connmark ! --mark 0/$mask -j CONNMARK --restore-mark --mask $mask";
    add_rule $mangle_table->{OUTPUT} , " -m connmark ! --mark 0/$mask -j CONNMARK --restore-mark --mask $mask";

    my $chainref = new_chain 'mangle', 'routemark';

    while ( my ( $interface, $mark ) = ( each %routemarked_interfaces ) ) {
	add_rule $mangle_table->{PREROUTING} , "-i $interface -m mark --mark 0/$mask -j routemark";
	add_rule $chainref, " -i $interface -j MARK $mark_op $mark";
    }

    add_rule $chainref, "-m mark ! --mark 0/$mask -j CONNMARK --save-mark --mask $mask";
}

sub setup_providers() {
    my $fn = find_file 'providers';
    my $providers = 0;

    sub copy_table( $$ ) {
	my ( $duplicate, $number ) = @_;

	emitj( "ip route show table $duplicate | while read net route; do",
	       '    case $net in',
	       '        default|nexthop)',
	       '            ;;',
	       '        *)',
	       "            run_ip route add table $number \$net \$route",
	       '            ;;',
	       '    esac',
	       "done\n"
	       );
    }

    sub copy_and_edit_table( $$$ ) {
	my ( $duplicate, $number, $copy ) = @_;

	my $match = $copy;

	$match =~ s/ /\|/g;

	emitj ( "ip route show table $duplicate | while read net route; do",
		'    case $net in',
		'        default|nexthop)',
		'            ;;',
		'        *)',
		"            run_ip route add table $number \$net \$route",
		'            case $(find_device $route) in',
		"                $match)",
		"                    run_ip route add table $number \$net \$route",
		'                    ;;',
		'            esac',
		'            ;;',
		'    esac',
		"done\n" );
    }

    sub balance_default_route( $$$ ) {
	my ( $weight, $gateway, $interface ) = @_;

	$balance = 1;

	emit '';

	if ( $first_default_route ) {
	    if ( $gateway ) {
		emit "DEFAULT_ROUTE=\"nexthop via $gateway dev $interface weight $weight\"";
	    } else {
		emit "DEFAULT_ROUTE=\"nexthop dev $interface weight $weight\"";
	    }

	    $first_default_route = 0;
	} else {
	    if ( $gateway ) {
		emit "DEFAULT_ROUTE=\"\$DEFAULT_ROUTE nexthop via $gateway dev $interface weight $weight\"";
	    } else {
		emit "DEFAULT_ROUTE=\"\$DEFAULT_ROUTE nexthop dev $interface weight $weight\"";
	    }
	}
    }

    sub add_a_provider( $$$$$$$$ ) {

	my ($table, $number, $mark, $duplicate, $interface, $gateway,  $options, $copy) = @_;

	fatal_error 'Providers require mangle support in your kernel and iptables' unless $capabilities{MANGLE_ENABLED};

	fatal_error "Duplicate provider ( $table )" if $providers{$table};

	for my $provider ( keys %providers  ) {
	    fatal_error "Duplicate provider number ( $number )" if $providers{$provider}{number} == $number;
	}

	emit "#\n# Add Provider $table ($number)\n#";

	emit "if interface_is_usable $interface; then";
	push_indent;
	my $iface = chain_base $interface;

	emit "${iface}_up=Yes";
	emit "qt ip route flush table $number";
	emit "echo \"qt ip route flush table $number\" >> \${VARDIR}/undo_routing";

	$duplicate = '-' unless $duplicate;
	$copy      = '-' unless $copy;

	if ( $duplicate ne '-' ) {
	    if ( $copy ne '-' ) {
		if ( $copy eq 'none' ) {
		    $copy = $interface;
		} else {
		    my @c = ( split /,/, $copy );
		    $copy = "@c";
		}

		copy_and_edit_table( $duplicate, $number ,$copy );
	    } else {
		copy_table ( $duplicate, $number );
	    }
	} else {
	    fatal_error 'A non-empty COPY column requires that a routing table be specified in the DUPLICATE column' if $copy ne '-';
	}

	$gateway = '-' unless $gateway;

	if ( $gateway eq 'detect' ) {
	    emitj ( "gateway=\$(detect_gateway $interface)\n",
		    'if [ -n "$gateway" ]; then',
		    "    run_ip route replace \$gateway src \$(find_first_interface_address $interface) dev $interface table $number",
		    "    run_ip route add default via \$gateway dev $interface table $number",
		    'else',
		    "    fatal_error \"Unable to detect the gateway through interface $interface\"",
		    "fi\n" );
	} elsif ( $gateway && $gateway ne '-' ) {
	    emit "run_ip route replace $gateway src \$(find_first_interface_address $interface) dev $interface table $number";
	    emit "run_ip route add default via $gateway dev $interface table $number";
	} else {
	    $gateway = '';
	    emit "run_ip route add default dev $interface table $number";
	}

	$mark = '-' unless $mark;

	my $val = 0;

	if ( $mark ne '-' ) {

	    $val = numeric_value $mark;

	    verify_mark $mark;

	    if ( $val < 256) {
		fatal_error "Invalid Mark Value ($mark) with HIGH_ROUTE_MARKS=Yes" if $config{HIGH_ROUTE_MARKS};
	    } else {
		fatal_error "Invalid Mark Value ($mark) with HIGH_ROUTE_MARKS=No" if ! $config{HIGH_ROUTE_MARKS};
	    }

	    for my $provider ( keys %providers  ) {
		my $num = $providers{$provider}{mark};
		fatal_error "Duplicate mark value ( $mark )" if $num == $val;
	    }

	    my $pref = 10000 + $val;

	    emitj( "qt ip rule del fwmark $mark",
		   "run_ip rule add fwmark $mark pref $pref table $number",
		   "echo \"qt ip rule del fwmark $mark\" >> \${VARDIR}/undo_routing"
		   );
	}

	$providers{$table}         = {};
	$providers{$table}{number} = $number;
	$providers{$table}{mark}   = $val;

	my ( $loose, $optional ) = (0,0);

	unless ( $options eq '-' ) {
	    for my $option ( split /,/, $options ) {
		if ( $option eq 'track' ) {
		    fatal_error "Interface $interface is tracked through an earlier provider" if $routemarked_interfaces{$interface};
		    fatal_error "The 'track' option requires a numeric value in the MARK column - Provider \"$line\"" if $mark eq '-';
		    $routemarked_interfaces{$interface} = $mark;
		    push @routemarked_interfaces, $interface;
		} elsif ( $option =~ /^balance=(\d+)/ ) {
		    balance_default_route $1 , $gateway, $interface;
		} elsif ( $option eq 'balance' ) {
		    balance_default_route 1 , $gateway, $interface;
		} elsif ( $option eq 'loose' ) {
		    $loose = 1;
		} elsif ( $option eq 'optional' ) {
		    $optional = 1;
		} else {
		    fatal_error "Invalid option ($option) in provider \"$line\"";
		}
	    }
	}

	if ( $loose ) {
	    my $rulebase = 20000 + ( 256 * ( $number - 1 ) );

	    emit "\nrulenum=0\n";

	    emitj ( "find_interface_addresses $interface | while read address; do",
		    '    qt ip rule del from $address',
		    "    run_ip rule add from \$address pref \$(( $rulebase + \$rulenum )) table $number",
		    "    echo \"qt ip rule del from \$address\" >> \${VARDIR}/undo_routing",
		    '    rulenum=$(($rulenum + 1))',
		    'done'
		    );
	} else {
	    emitj( "\nfind_interface_addresses $interface | while read address; do",
		   '    qt ip rule del from $address',
		   'done'
		   );
	}

	emit "\nprogress_message \"   Provider $table ($number) Added\"\n";

	pop_indent;
	emit 'else';

	if ( $optional ) {
	    emitj( "    error_message \"WARNING: Interface $interface is not configured -- Provider $table ($number) not Added\"",
		   "    ${iface}_up="
		   );
	} else {
	    emit "    fatal_error \"ERROR: Interface $interface is not configured -- Provider $table ($number) Cannot be Added\"";
	}

	emit "fi\n";
    }

    sub add_an_rtrule( $$$$ ) {
	my ( $source, $dest, $provider, $priority ) = @_;

	unless ( $providers{$provider} ) {
	    my $found = 0;

	    if ( "\L$provider" =~ /^(0x[a-f0-9]+|0[0-7]*|[0-9]*)$/ ) {
		my $provider_number = numeric_value $provider;

		for my $provider ( keys %providers ) {
		    if ( $providers{$provider}{number} == $provider_number ) {
			$found = 1;
			last;
		    }
		}
	    }

	    fatal_error "Unknown provider $provider in route rule \"$line\"" unless $found;
	}

	$source = '-' unless $source;
	$dest   = '-' unless $dest;

	fatal_error "You must specify either the source or destination in an rt rule: \"$line\"" if $source eq '-' && $dest eq '-';

	$dest = $dest eq '-' ? '' : "to $dest";

	if ( $source eq '-' ) {
	    $source = '';
	} elsif ( $source =~ /:/ ) { 
	    ( my $interface, $source ) = split /:/, $source;
	    $source = "iif $interface from $source";
	} elsif ( $source =~ /\..*\..*/ ) {
	    $source = "from $source";
	} else {
	    $source = "iif $source";
	}

	fatal_error "Invalid priority ($priority) in rule \"$line\"" unless $priority && $priority =~ /^\d{1,5}$/;

	$priority = "priority $priority";

	emitj( "qt ip rule del $source $dest $priority",
	       "run_ip rule add $source $dest $priority table $provider",
	       "echo \"qt ip rule del $source $dest $priority\" >> \${VARDIR}/undo_routing"
	       );
	progress_message "   Routing rule \"$line\" $done";
    }
    #
    #   Setup_Providers() Starts Here....
    # 
    progress_message2 "$doing $fn ...";

    emit "\nif [ -z \"\$NOROUTES\" ]; then";

    push_indent;

    emitj ( '#',
	    '# Undo any changes made since the last time that we [re]started -- this will not restore the default route',
	    '#',
	    'undo_routing',
	    '#',
	    '# Save current routing table database so that it can be restored later',
	    '#',
	    'cp /etc/iproute2/rt_tables ${VARDIR}/',
	    '#',
	    '# Capture the default route(s) if we don\'t have it (them) already.',
	    '#',
	    '[ -f ${VARDIR}/default_route ] || ip route ls | grep -E \'^\s*(default |nexthop )\' > ${VARDIR}/default_route',
	    '#',
	    '# Initialize the file that holds \'undo\' commands',
	    '#',
	    '> ${VARDIR}/undo_routing' );

    save_progress_message 'Adding Providers...';

    emit 'DEFAULT_ROUTE=';

    open PV, "$ENV{TMP_DIR}/providers" or fatal_error "Unable to open stripped providers file: $!";

    while ( $line = <PV> ) {

	my ( $table, $number, $mark, $duplicate, $interface, $gateway,  $options, $copy ) = split_line 8, 'providers file';

	add_a_provider(  $table, $number, $mark, $duplicate, $interface, $gateway,  $options, $copy );

	push @providers, $table;

	$providers++;

	progress_message "   Provider \"$line\" $done";

    }

    close PV;

    if ( $providers ) {
	if ( $balance ) {
	    emitj ( 'if [ -n "$DEFAULT_ROUTE" ]; then',
		    '    run_ip route replace default scope global $DEFAULT_ROUTE',
		    "    progress_message \"Default route '\$(echo \$DEFAULT_ROUTE | sed 's/\$\\s*//')' Added\"",
		    'else',
		    '    error_message "WARNING: No Default route added (all \'balance\' providers are down)"',
		    '    restore_default_route',
		    'fi',
		    '' );
	} else {
	    emitj( '#',
		   '# We don\'t have any \'balance\' providers so we restore any default route that we\'ve saved',
		   '#',
		   'restore_default_route' );
	}

	emit 'cat > /etc/iproute2/rt_tables <<EOF';

	emit_unindented join( "\n",
			      '#',
			      '# reserved values',
			      '#',
			      "255\tlocal",
			      "254\tmain",
			      "253\tdefault",
			      "0\tunspec",
			      '#',
			      '# local',
			      '#',
			      "EOF\n" );

	emit "echocommand=\$(find_echo)\n";

	for my $table ( @providers ) {
	    emit "\$echocommand \"$providers{$table}{number}\\t$table\" >>  /etc/iproute2/rt_tables";
	}

	if ( -s "$ENV{TMP_DIR}/route_rules" ) {
	    my $fn = find_file 'route_rules';
	    progress_message2 "$doing $fn...";

	    emit '';

	    open RR, "$ENV{TMP_DIR}/route_rules" or fatal_error "Unable to open stripped route rules file: $!";

	    while ( $line = <RR> ) {
		my ( $source, $dest, $provider, $priority ) = split_line 4, 'route_rules file';

		add_an_rtrule( $source, $dest, $provider , $priority );
	    }

	    close RR;
	}
    }

    emit "\nrun_ip route flush cache";
    pop_indent;
    emit "fi\n";

    setup_route_marking if @routemarked_interfaces;

}

1;
