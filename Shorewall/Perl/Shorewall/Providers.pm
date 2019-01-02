#
# Shorewall 5.2 -- /usr/share/shorewall/Shorewall/Providers.pm
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2007-2017 - Tom Eastep (teastep@shorewall.net)
#
#       Complete documentation is available at http://shorewall.net
#
#       This program is part of Shorewall.
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by the
#       Free Software Foundation, either version 2 of the license or, at your
#       option, any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, see <http://www.gnu.org/licenses/>.
#
#   This module deals with the /etc/shorewall/providers,
#   /etc/shorewall/rtrules and /etc/shorewall/routes files.
#
package Shorewall::Providers;
require Exporter;
use Shorewall::Config qw(:DEFAULT :internal);
use Shorewall::IPAddrs;
use Shorewall::Zones;
use Shorewall::Chains qw(:DEFAULT :internal);
use Shorewall::Proc qw( setup_interface_proc );

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( process_providers
		  setup_providers
		  @routemarked_interfaces
		  handle_stickiness
		  handle_optional_interfaces
		  compile_updown
		  setup_load_distribution
		  have_providers
                  map_provider_to_interface
	       );
our @EXPORT_OK = qw( initialize provider_realm );
our $VERSION = 'MODULEVERSION';

use constant { LOCAL_TABLE   => 255,
	       MAIN_TABLE    => 254,
	       DEFAULT_TABLE => 253,
	       BALANCE_TABLE => 250,
	       UNSPEC_TABLE  => 0
	       };

our @routemarked_providers;
our %routemarked_interfaces;
our @routemarked_interfaces;
our %provider_interfaces;
our @load_providers;

our $balancing;               # True, if there are balanced providers
our $fallback;                # True, if there are fallback providers
our $balanced_providers;      # Count of balanced providers
our $fallback_providers;      # Count of fallback providers
our $metrics;                 # True, if using statistical balancing
our $first_default_route;     # True, until we generate the first 'via' clause for balanced providers
our $first_fallback_route;    # True, until we generate the first 'via' clause for fallback providers
our $maxload;                 # Sum of 'load' values
our $tproxies;                # Count of tproxy providers

our %providers;               # Provider table
#
# %provider_table { <provider> => { provider	      => <provider name>,
#				    number	      => <provider number>,
#				    id		      => <name> or <number> depending on USE_RT_NAMES,
#				    rawmark	      => <specified mark value>,
#				    mark	      => <mark, in hex>,
#				    interface	      => <logical interface>,
#				    physical	      => <physical interface>,
#				    optional	      => {0|1},
#				    wildcard	      => <from interface>,
#				    gateway	      => <gateway>,
#				    gatewaycase	      => { 'detect', 'none', or 'specified' },
#				    shared	      => <true, if multiple providers through this interface>,
#				    copy	      => <contents of the COPY column>,
#				    balance	      => <balance count>,
#				    pref	      => <route rules preference (priority) value>,
#				    mtu		      => <mtu>,
#				    noautosrc	      => {0|1} based on [no]autosrc setting,
#				    track	      => {0|1} based on 'track' setting,
#				    loose	      => {0|1} based on 'loose' setting,
#				    duplicate	      => <contents of the DUPLICATE column>,
#				    address	      => If {shared} above, then the local IP address.
#							 Otherwise, the value of the 'src' option,
#				    mac		      => Mac address of gateway, if {shared} above,
#				    tproxy	      => {0|1},
#				    load	      => <load % for statistical balancing>,
#				    pseudo	      => {0|1}. 1 means this is an optional interface and not
#							 a real provider,
#				    what	      => 'provider' or 'interface' depending on {pseudo} above,
#				    hostroute	      => {0|1} based on [no]hostroute setting,
#				    rules	      => ( <routing rules> ),
#				    persistent_rules  => ( <persistent routing rules> ),
#				    routes	      => ( <routes> ),
#				    persistent_routes => ( <persistent routes> ),
#				    persistent	      => {0|1} depending on 'persistent' setting,
#				    routedests	      => { <subnet> => 1 , ... }, (used for duplicate destination detection),
#				    origin	      => <filename and linenumber where provider/interface defined>
#		   }

our @providers;    # Provider names. Only declared names are included in this array. 

our $family;       # Address family

our $lastmark;     # Highest assigned mark

use constant { ROUTEMARKED_SHARED => 1, ROUTEMARKED_UNSHARED => 2 };

#
# Rather than initializing globals in an INIT block or during declaration,
# we initialize them in a function. This is done for two reasons:
#
#   1. Proper initialization depends on the address family which isn't
#      known until the compiler has started.
#
#   2. The compiler can run multiple times in the same process so it has to be
#      able to re-initialize its dependent modules' state.
#
sub initialize( $ ) {
    $family = shift;

    @routemarked_providers  = ();
    %routemarked_interfaces = ();
    @routemarked_interfaces = ();
    %provider_interfaces    = ();
    @load_providers         = ();
    $balancing              = 0;
    $balanced_providers     = 0;
    $fallback_providers     = 0;
    $fallback               = 0;
    $metrics                = 0;
    $first_default_route    = 1;
    $first_fallback_route   = 1;
    $maxload                = 0;
    $tproxies               = 0;
    #
    # The 'id' member is initialized in process_providers(), after the .conf file has been processed
    #
    %providers  = ( local   => { provider => 'local',   number => LOCAL_TABLE   , mark => 0 , optional => 0 ,routes => [], rules => [] , routedests => {} } ,
		    main    => { provider => 'main',    number => MAIN_TABLE    , mark => 0 , optional => 0 ,routes => [], rules => [] , routedests => {} } ,
		    default => { provider => 'default', number => DEFAULT_TABLE , mark => 0 , optional => 0 ,routes => [], rules => [] , routedests => {} } ,
		    balance => { provider => 'balance', number => BALANCE_TABLE , mark => 0 , optional => 0 ,routes => [], rules => [] , routedests => {} } ,
		    unspec  => { provider => 'unspec',  number => UNSPEC_TABLE  , mark => 0 , optional => 0 ,routes => [], rules => [] , routedests => {} } );
    @providers = ();

}

#
# Set up marking for 'tracked' interfaces.
#
sub setup_route_marking() {
    my $mask   = in_hex( $globals{PROVIDER_MASK} );
    my $exmask = have_capability( 'EXMARK' ) ? "/$mask" : '';

    require_capability( $_ , q(The provider 'track' option) , 's' ) for qw/CONNMARK_MATCH CONNMARK/;
    #
    # Clear the mark -- we have seen cases where the mark is non-zero even in the raw table chains!
    #

    if ( $config{ZERO_MARKS} ) {
	add_ijump( $mangle_table->{$_}, j => 'MARK', targetopts => '--set-mark 0' ) for qw/PREROUTING OUTPUT/;
    }

    if ( $config{RESTORE_ROUTEMARKS} ) {
	add_ijump $mangle_table->{$_} , j => 'CONNMARK', targetopts => "--restore-mark --mask $mask" for qw/PREROUTING OUTPUT/;
    } else {
	add_ijump $mangle_table->{$_} , j => 'CONNMARK', targetopts => "--restore-mark --mask $mask", connmark => "! --mark 0/$mask" for qw/PREROUTING OUTPUT/;
    }

    my $chainref  = new_chain 'mangle', 'routemark';

    if ( @routemarked_providers ) {
	my $chainref1 = new_chain 'mangle', 'setsticky';
	my $chainref2 = new_chain 'mangle', 'setsticko';

	my %marked_interfaces;

	for my $providerref ( @routemarked_providers ) {
	    my $interface = $providerref->{interface};
	    my $physical  = $providerref->{physical};
	    my $mark      = $providerref->{mark};
	    my $origin    = $providerref->{origin};

	    unless ( $marked_interfaces{$interface} ) {
		add_ijump_extended $mangle_table->{PREROUTING} , j => $chainref,  $origin, i => $physical,     mark => "--mark 0/$mask";
		add_ijump_extended $mangle_table->{PREROUTING} , j => $chainref1, $origin, i => "! $physical", mark => "--mark  $mark/$mask";
		add_ijump_extended $mangle_table->{OUTPUT}     , j => $chainref2, $origin,                     mark => "--mark  $mark/$mask";

		if ( have_ipsec ) {
		    if ( have_capability( 'MARK_ANYWHERE' ) && ( my $chainref = $filter_table->{forward_chain($interface)} ) ) {
			add_ijump_extended $chainref, j => 'CONNMARK', $origin, targetopts => "--set-mark 0${exmask}",               , state_imatch('NEW'), policy => '--dir in --pol ipsec';
		    } elsif ( have_capability( 'MANGLE_FORWARD' ) ) {
			add_ijump_extended $mangle_table->{FORWARD},                   j => 'CONNMARK', $origin, targetopts => "--set-mark 0${exmask}", i => $physical, state_imatch('NEW'), policy => '--dir in --pol ipsec';
		    }
		}

		$marked_interfaces{$interface} = 1;
	    }

	    if ( $providerref->{shared} ) {
		add_commands( $chainref, qq(if [ -n "$providerref->{mac}" ]; then) ), incr_cmd_level( $chainref ) if $providerref->{optional};
		add_ijump_extended $chainref, j => 'MARK', $origin, targetopts => "--set-mark $providerref->{mark}${exmask}", imatch_source_dev( $interface ), mac => "--mac-source $providerref->{mac}";
		decr_cmd_level( $chainref ), add_commands( $chainref, "fi\n" ) if $providerref->{optional};
	    } else {
		add_ijump_extended $chainref, j => 'MARK', $origin, targetopts => "--set-mark $providerref->{mark}${exmask}", imatch_source_dev( $interface );
	    }
	}

	add_ijump $chainref, j => 'CONNMARK', targetopts => "--save-mark --mask $mask", mark => "! --mark 0/$mask";
    }

    if ( @load_providers ) {
	my $chainref1 = new_chain 'mangle', 'balance';
	my @match;

	add_ijump $chainref,               g => $chainref1, mark => "--mark 0/$mask";
	add_ijump $mangle_table->{OUTPUT}, j => $chainref1, state_imatch( 'NEW,RELATED' ), mark => "--mark 0/$mask";

	for my $provider ( @load_providers ) {

	    my $chainref2 = new_chain( 'mangle', load_chain( $provider ) );

	    set_optflags( $chainref2, DONT_OPTIMIZE | DONT_MOVE | DONT_DELETE );

  	    add_ijump ( $chainref1,
			j => $chainref2 ,
		        mark => "--mark 0/$mask" );
	}
    }
}

sub copy_table( $$$ ) {
    my ( $duplicate, $number, $realm ) = @_;

    my $filter = $family == F_IPV6 ? q(grep -vF ' cache ' | sed 's/ via :: / /' | ) : '';

    emit '';

    if ( $realm ) {
	emit  ( "\$IP -$family -o route show table $duplicate | sed -r 's/ realm [[:alnum:]_]+//' | ${filter}while read net route; do" )
    } else {
	emit  ( "\$IP -$family -o route show table $duplicate | ${filter}while read net route; do" )
    }

    emit ( '    case $net in',
	   '        default)',
	   '            ;;',
	   '        *)' );

    if ( $family == F_IPV4 ) {
	emit ( '            case $net in',
	       '                255.255.255.255*)',
	       '                    ;;',
	       '                *)',
	       "                    run_ip route add table $number \$net \$route $realm",
	       '                    ;;',
	       '            esac',
	     );
    } else {
	emit ( '            case $net in',
	       '                fe80:*)',
	       '                    ;;',
	       '                *)',
	       "                    run_ip route add table $number \$net \$route $realm",
	       '                    ;;',
	       '            esac',
	     );
    }

    emit ( '            ;;',
	   '    esac',
	   "done\n"
	 );
}

sub copy_and_edit_table( $$$$$ ) {
    my ( $duplicate, $number, $id, $copy, $realm) = @_;

    my $filter = $family == F_IPV6 ? q(grep -vF ' cache ' | sed 's/ via :: / /' | ) : '';
    my %copied;
    my @copy;
    my @bup_copy;
    my $bup_copy;
    #
    # Remove duplicates
    #
    for ( split ',', $copy ) {
	unless ( $copied{$_} ) {
	    if ( known_interface($_) ) {
		push @copy, $_;    
	    } elsif ( $_ =~ /^(?:blackhole|unreachable|prohibit)$/ ) {
		push @bup_copy, $_;
            } else {
		fatal_error "Unknown interface ($_)";
            }
	    $copied{$_} = 1;
	}
    }
    $bup_copy = join( '|' , @bup_copy );
    #
    # Map physical names in $copy to logical names
    #
    $copy = join( '|' , map( physical_name($_) , @copy ) );
    #
    # Shell and iptables use a different wildcard character
    #
    $copy =~ s/\+/*/g;

    emit '';

    if ( $realm ) {
	emit  ( "\$IP -$family -o route show table $duplicate | sed -r 's/ realm [[:alnum:]_]+//' | ${filter}while read net route; do" )
    } else {
	emit  ( "\$IP -$family -o route show table $duplicate | ${filter}while read net route; do" )
    }

    emit (  '    case $net in',
	    '        default)',
	    '            ;;' );
    if ( $bup_copy ) {
      emit ("        $bup_copy)",
	    "            run_ip route add table $id \$net \$route $realm",
	    '            ;;' );
    }
    emit (  '        *)',
	    '            case $(find_device $route) in',
	    "                $copy)" );
    if ( $family == F_IPV4 ) {
	emit (  '                    case $net in',
		'                        255.255.255.255*)',
		'                            ;;',
		'                        *)',
		"                            run_ip route add table $id \$net \$route $realm",
		'                            ;;',
		'                    esac',
	     );
    } else {
	emit (  '                    case $net in',
		'                        fe80:*)',
		'                            ;;',
		'                        *)',
		"                            run_ip route add table $id \$net \$route $realm",
		'                            ;;',
		'                    esac',
	     );
    }

    emit (  '                    ;;',
	    '            esac',
	    '            ;;',
	    '    esac',
	    "done\n" );
}

sub balance_default_route( $$$$ ) {
    my ( $weight, $gateway, $interface, $realm ) = @_;

    $balancing = 1;

    emit '';

    if ( $first_default_route ) {
	if ( $balanced_providers == 1 ) {
	    if ( $gateway ) {
		emit qq(DEFAULT_ROUTE="via $gateway dev $interface $realm");
	    } else {
		emit qq(DEFAULT_ROUTE="dev $interface $realm");
	    }
	} elsif ( $gateway ) {
	    emit qq(DEFAULT_ROUTE="nexthop via $gateway dev $interface weight $weight $realm");
	} else {
	    emit qq(DEFAULT_ROUTE="nexthop dev $interface weight $weight $realm");
	}

	$first_default_route = 0;
    } else {
	if ( $gateway ) {
	    emit qq(DEFAULT_ROUTE="\$DEFAULT_ROUTE nexthop via $gateway dev $interface weight $weight $realm");
	} else {
	    emit qq(DEFAULT_ROUTE="\$DEFAULT_ROUTE nexthop dev $interface weight $weight $realm");
	}
    }
}

sub balance_fallback_route( $$$$ ) {
    my ( $weight, $gateway, $interface, $realm ) = @_;

    $fallback = 1;

    emit '';

    if ( $first_fallback_route ) {
	if ( $fallback_providers == 1 ) {
	    if ( $gateway ) {
		emit qq(FALLBACK_ROUTE="via $gateway dev $interface $realm");
	    } else {
		emit qq(FALLBACK_ROUTE="dev $interface $realm");
	    }
	} elsif ( $gateway ) {
	    emit qq(FALLBACK_ROUTE="nexthop via $gateway dev $interface weight $weight $realm");
	} else {
	    emit qq(FALLBACK_ROUTE="nexthop dev $interface weight $weight $realm");
	}

	$first_fallback_route = 0;
    } else {
	if ( $gateway ) {
	    emit qq(FALLBACK_ROUTE="\$FALLBACK_ROUTE nexthop via $gateway dev $interface weight $weight $realm");
	} else {
	    emit qq(FALLBACK_ROUTE="\$FALLBACK_ROUTE nexthop dev $interface weight $weight $realm");
	}
    }
}

sub start_provider( $$$$$ ) {
    my ($what, $table, $number, $id, $test ) = @_;

    emit "\n#\n# Add $what $table ($number)\n#";

    if ( $number >= 0 ) {
	emit "start_provider_$table() {";
    } else {
	emit "start_interface_$table() {";
    }

    push_indent;
    emit $test;
    push_indent;

    if ( $number >= 0 ) {
	emit "qt ip -$family route flush table $id";
	emit "echo \"\$IP -$family route flush table $id > /dev/null 2>&1\" > \${VARDIR}/undo_${table}_routing";
    } else {
	emit( "> \${VARDIR}/undo_${table}_routing" );
    }
}

#
# Look up a provider and return a reference to its table entry. If unknown provider, undef is returned
#
sub lookup_provider( $ ) {
    my $provider    = $_[0];
    my $providerref = $providers{ $provider };

    unless ( $providerref ) {
	my $provider_number = numeric_value $provider;

	if ( defined $provider_number ) {
	    for ( values %providers ) {
		$providerref = $_, last if $_->{number} == $provider_number;
	    }
	}
    }

    $providerref;
}

#
# Process a record in the providers file
#
sub process_a_provider( $ ) {
    my $pseudo = $_[0]; # When true, this is an optional interface that we are treating somewhat like a provider.

    my ($table, $number, $mark, $duplicate, $interface, $gateway,  $options, $copy ) =
	split_line('providers file',
		   { table => 0, number => 1, mark => 2, duplicate => 3, interface => 4, gateway => 5, options => 6, copy => 7 } );

    fatal_error "Duplicate provider ($table)" if $providers{$table};

    fatal_error 'NAME must be specified' if $table eq '-';

    unless ( $pseudo ) {
	fatal_error "Invalid Provider Name ($table)" unless $table =~ /^[A-Za-z][\w]*$/;

	my $num = numeric_value $number;

	fatal_error 'NUMBER must be specified' if $number eq '-';
	fatal_error "Invalid Provider number ($number)" unless defined $num;

	$number = $num;

	for my $providerref ( values %providers  ) {
	    fatal_error "Duplicate provider number ($number)" if $providerref->{number} == $number;
	}
    }

    fatal_error 'INTERFACE must be specified' if $interface eq '-';

    ( $interface, my $address ) = split /:/, $interface, 2;

    my $shared = 0;
    my $noautosrc = 0;
    my $mac = '';

    if ( defined $address ) {
	validate_address $address, 0;
	$shared = 1;
	require_capability 'REALM_MATCH', "Configuring multiple providers through one interface", "s";
    }

    my $interfaceref = known_interface( $interface );

    fatal_error "Unknown Interface ($interface)" unless $interfaceref;

    fatal_error "A bridge port ($interface) may not be configured as a provider interface" if port_to_bridge $interface;

    #
    # Switch to the logical name if a physical name was passed
    #
    my $physical;

    if ( $interface eq $interfaceref->{name} ) {
	#
	# The logical interface name was specified
	#
	$physical = $interfaceref->{physical};
    } else {
	#
	# A Physical name was specified
	#
	$physical = $interface;
	#
	# Switch to the logical name unless it is a wildcard
	#
	$interface = $interfaceref->{name} unless $interfaceref->{wildcard};
    } 

    if ( $physical =~ /\+$/ ) {
	return 0 if $pseudo;
	fatal_error "Wildcard interfaces ($physical) may not be used as provider interfaces";
    }

    my $gatewaycase = '';
    my $gw;

    if ( ( $gw = lc $gateway ) eq 'detect' ) {
	fatal_error "Configuring multiple providers through one interface requires an explicit gateway" if $shared;
	$gateway = get_interface_gateway( $interface, undef, $number );
	$gatewaycase = 'detect';
	set_interface_option( $interface, 'gateway', 'detect' );
    } elsif ( $gw eq 'none' ) {
	fatal_error "Configuring multiple providers through one interface requires a gateway" if $shared;
	$gatewaycase = 'none';
	$gateway = '';
	set_interface_option( $interface, 'gateway', 'none' );
    } elsif ( $gateway && $gateway ne '-' ) {
	( $gateway, $mac ) = split_host_list( $gateway, 0 );

	$gateway = $1 if $family == F_IPV6 && $gateway =~ /^\[(.+)\]$/;

	validate_address $gateway, 0;

	if ( defined $mac ) {
	    $mac =~ tr/-/:/;
	    $mac =~ s/^~//;
	    fatal_error "Invalid MAC address ($mac)" unless $mac =~ /^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/;
	} else {
	    $mac = '';
	}

	$gatewaycase = 'specified';
	set_interface_option( $interface, 'gateway', $gateway );
    } else {
	$gatewaycase = 'omitted';
	fatal_error "Configuring multiple providers through one interface requires a gateway" if $shared;
	$gateway = '';
	set_interface_option( $interface, 'gateway', $pseudo ? 'detect' : 'omitted' );
    }


    my ( $loose, $track, $balance, $default, $default_balance, $optional, $mtu, $tproxy, $local, $load, $what, $hostroute, $persistent );

    if ( $pseudo ) {	
	( $loose, $track,                   $balance , $default, $default_balance,                   $optional,                           $mtu, $tproxy , $local, $load, $what ,      $hostroute,        $persistent ) =
	( 0,      0                       , 0 ,        0,        0,                                  1                                  , ''  , 0       , 0,      0,     'interface', 0,                 0);
    } else {
	( $loose, $track,                   $balance , $default, $default_balance,                   $optional,                           $mtu, $tproxy , $local, $load, $what      , $hostroute,        $persistent  )=
	( 0,      $config{TRACK_PROVIDERS}, 0 ,        0,        $config{BALANCE_PROVIDERS} ? 1 : 0, interface_is_optional( $interface ), ''  , 0       , 0,      0,     'provider',  1,                 0);
    }

    unless ( $options eq '-' ) {
	for my $option ( split_list $options, 'option' ) {
	    if ( $option eq 'track' ) {
		require_capability( 'MANGLE_ENABLED' , q(The 'track' option) , 's' );
		$track = 1;
	    } elsif ( $option eq 'notrack' ) {
		$track = 0;
	    } elsif ( $option =~ /^balance=(\d+)$/ ) {
		fatal_error q('balance' may not be spacified when GATEWAY is 'none') if $gatewaycase eq 'none';
		fatal_error 'The balance setting must be non-zero' unless $1;
		$balance = $1;
	    } elsif ( $option eq 'balance' || $option eq 'primary') {
		fatal_error qq('$option' may not be spacified when GATEWAY is 'none') if $gatewaycase eq 'none';
		$balance = 1;
	    } elsif ( $option eq 'loose' ) {
		$loose   = 1;
		$default_balance = 0;
	    } elsif ( $option eq 'optional' ) {
		unless ( $shared ) {
		    warning_message q(The 'optional' provider option is deprecated - use the 'optional' interface option instead);
		    set_interface_option $interface, 'optional', 1;
		}

		$optional = 1;
	    } elsif ( $option =~ /^src=(.*)$/ ) {
		fatal_error "OPTION 'src' not allowed on shared interface" if $shared;
		$address = validate_address( $1 , 1 );
	    } elsif ( $option =~ /^mtu=(\d+)$/ ) {
		$mtu = "mtu $1 ";
	    } elsif ( $option =~ /^fallback=(\d+)$/ ) {
		fatal_error q('fallback' may not be spacified when GATEWAY is 'none') if $gatewaycase eq 'none';
		$default = $1;
		$default_balance = 0;
		fatal_error 'fallback must be non-zero' unless $default;
	    } elsif ( $option eq 'fallback' ) {
		fatal_error q('fallback' may not be spacified when GATEWAY is 'none') if $gatewaycase eq 'none';
		$default = -1;
		$default_balance = 0;
	    } elsif ( $option eq 'local' ) {
		warning_message q(The 'local' provider option is deprecated in favor of 'tproxy');
		$local = $tproxy = 1;
		$track  = 0           if $config{TRACK_PROVIDERS};
		$default_balance = 0  if $config{USE_DEFAULT_RT};
	    } elsif ( $option eq 'tproxy' ) {
		$tproxy = 1;
		$track  = 0           if $config{TRACK_PROVIDERS};
		$default_balance = 0  if $config{USE_DEFAULT_RT};
	    } elsif ( $option =~ /^load=(0?\.\d{1,8})/ ) {
		fatal_error q('fallback' may not be spacified when GATEWAY is 'none') if $gatewaycase eq 'none';
		$load = sprintf "%1.8f", $1;
		require_capability 'STATISTIC_MATCH', "load=$1", 's';
	    } elsif ( $option eq 'autosrc' ) {
		$noautosrc = 0;
	    } elsif ( $option eq 'noautosrc' ) {
		$noautosrc = 1;
	    } elsif ( $option eq 'hostroute' ) {
		$hostroute = 1;
	    } elsif ( $option eq 'nohostroute' ) {
		$hostroute = 0;
	    } elsif ( $option eq 'persistent' ) {
		warning_message "When RESTORE_DEFAULT_ROUTE=Yes, the 'persistent' option may not work as expected" if $config{RESTORE_DEFAULT_ROUTE};
		$persistent = 1;
	    } else {
		fatal_error "Invalid option ($option)";
	    }
	}
    }

    if ( $balance ) {
	fatal_error q(The 'balance' and 'fallback' options are mutually exclusive) if $default;
	$balanced_providers++;
    } elsif ( $default ) {
	$fallback_providers++;
    }

    if ( $load ) {
	fatal_error q(The 'balance=<weight>' and 'load=<load-factor>' options are mutually exclusive) if $balance > 1;
	fatal_error q(The 'fallback=<weight>' and 'load=<load-factor>' options are mutually exclusive) if $default > 1;
	$maxload += $load;
    }

    fatal_error "A provider interface must have at least one associated zone" unless $tproxy || %{interface_zones($interface)};
    fatal_error "An interface supporting multiple providers may not be optional" if $shared && $optional;

    unless ( $pseudo ) {
	if ( $local ) {
	    fatal_error "GATEWAY not valid with 'local' provider"  unless $gatewaycase eq 'omitted';
	    fatal_error "'track' not valid with 'local'"           if $track;
	    fatal_error "DUPLICATE not valid with 'local'"         if $duplicate ne '-';
	    fatal_error "'persistent' is not valid with 'local"    if $persistent;
	} elsif ( $tproxy ) {
	    fatal_error "Only one 'tproxy' provider is allowed"    if $tproxies++;
	    fatal_error "GATEWAY not valid with 'tproxy' provider" unless $gatewaycase eq 'omitted';
	    fatal_error "'track' not valid with 'tproxy'"          if $track;
	    fatal_error "DUPLICATE not valid with 'tproxy'"        if $duplicate ne '-';
	    fatal_error "MARK not allowed with 'tproxy'"           if $mark ne '-';
	    fatal_error "'persistent' is not valid with 'tproxy"   if $persistent;
	    $mark = $globals{TPROXY_MARK};
	} elsif ( ( my $rf = ( $config{ROUTE_FILTER} eq 'on' ) ) || $interfaceref->{options}{routefilter} ) {
	    if ( $config{USE_DEFAULT_RT} ) {
		if ( $rf ) {
		    fatal_error "There may be no providers when ROUTE_FILTER=Yes and USE_DEFAULT_RT=Yes";
		} else {
		    fatal_error "Providers interfaces may not specify 'routefilter' when USE_DEFAULT_RT=Yes";
		}
	    } else {
		unless ( $balance ) {
		    if ( $rf ) {
			fatal_error "The 'balance' option is required when ROUTE_FILTER=Yes";
		    } else {
			fatal_error "Provider interfaces may not specify 'routefilter' without 'balance' or 'primary'";
		    }
		}
	    }
	}
    }

    my $val = 0;
    my $pref;

    $mark = ( $lastmark += ( 1 << $config{PROVIDER_OFFSET} ) ) if $mark eq '-' && $track;

    if ( $mark ne '-' ) {

	require_capability( 'MANGLE_ENABLED' , 'Provider marks' , '' );

	if ( $tproxy && ! $local ) {
	    $val = $globals{TPROXY_MARK};
	    $pref = 1;
	} else {
	    $val = numeric_value $mark;

	    fatal_error "Invalid Mark Value ($mark)" unless defined $val && $val;

	    verify_mark $mark;

	    fatal_error "Invalid Mark Value ($mark)" unless ( $val & $globals{PROVIDER_MASK} ) == $val;

	    fatal_error "Provider MARK may not be specified when PROVIDER_BITS=0" unless $config{PROVIDER_BITS};

	    for my $providerref ( values %providers  ) {
		fatal_error "Duplicate mark value ($mark)" if numeric_value( $providerref->{mark} ) == $val;
	    }

	    $lastmark = $val;
	    
	    $pref = 10000 + $number - 1;
	}
    }

    unless ( $loose || $pseudo ) {
	warning_message q(The 'proxyarp' option is dangerous when specified on a Provider interface) if get_interface_option( $interface, 'proxyarp' );
	warning_message q(The 'proxyndp' option is dangerous when specified on a Provider interface) if get_interface_option( $interface, 'proxyndp' );
    }

    $balance = $default_balance unless $balance || $gatewaycase eq 'none';

    fatal_error "Interface $interface is already associated with non-shared provider $provider_interfaces{$interface}" if $provider_interfaces{$interface};

    if ( $duplicate ne '-' ) {
	fatal_error "The DUPLICATE column must be empty when USE_DEFAULT_RT=Yes" if $config{USE_DEFAULT_RT};
	my $p = lookup_provider( $duplicate );
	my $n = $p ? $p->{number} : 0;
	warning_message "Unknown routing table ($duplicate)" unless $n && ( $n == MAIN_TABLE || $n < BALANCE_TABLE );
	warning_message "An optional provider ($duplicate) is listed in the DUPLICATE column - enable and disable will not work correctly on that provider" if $p && $p->{optional};
    } elsif ( $copy ne '-' ) {
	fatal_error "The COPY column must be empty when USE_DEFAULT_RT=Yes" if $config{USE_DEFAULT_RT};
	fatal_error 'A non-empty COPY column requires that a routing table be specified in the DUPLICATE column' unless $copy eq 'none';
    }

    if ( $persistent ) {
	warning_message( "Provider $table is not optional -- the 'persistent' option is ignored" ), $persistent = 0 unless $optional;
    }

    $providers{$table} = { provider          => $table,
			   number            => $number ,
			   id                => $config{USE_RT_NAMES} ? $table : $number,
			   rawmark           => $mark ,
			   mark              => $val ? in_hex($val) : $val ,
			   interface         => $interface ,
			   physical          => $physical ,
			   optional          => $optional ,
			   wildcard          => $interfaceref->{wildcard} || 0,
			   gateway           => $gateway ,
			   gatewaycase       => $gatewaycase ,
			   shared            => $shared ,
			   default           => $default ,
			   copy              => $copy ,
			   balance           => $balance ,
			   pref              => $pref ,
			   mtu               => $mtu ,
			   noautosrc         => $noautosrc ,
			   track             => $track ,
			   loose             => $loose ,
			   duplicate         => $duplicate ,
			   address           => $address ,
			   mac               => $mac ,
			   local             => $local ,
			   tproxy            => $tproxy ,
			   load              => $load ,
			   pseudo            => $pseudo ,
			   what              => $what ,
			   hostroute         => $hostroute ,
			   rules             => [] ,
			   persistent_rules  => [] ,
			   routes            => [] ,
			   persistent_routes => [],
			   routedests        => {} ,
			   persistent        => $persistent,
			   origin            => shortlineinfo( '' ),
			 };

    $provider_interfaces{$interface} = $table unless $shared;

    if ( $track ) {
	if ( $routemarked_interfaces{$interface} ) {
	    fatal_error "Interface $interface is tracked through an earlier provider" if $routemarked_interfaces{$interface} == ROUTEMARKED_UNSHARED;
	    fatal_error "Multiple providers through the same interface must have their IP address specified in the INTERFACES column" unless $shared;
	} else {
	    $routemarked_interfaces{$interface} = $shared ? ROUTEMARKED_SHARED : ROUTEMARKED_UNSHARED;
	    push @routemarked_interfaces, $interface;
	}

	push @routemarked_providers, $providers{$table};
    }

    push @load_providers, $table if $load;

    push @providers, $table;

    progress_message "   Provider \"$currentline\" $done" unless $pseudo;

    return 1;
}

#
# Emit a 'started' message
#
sub emit_started_message( $$$$$ ) {
    my ( $spaces, $level, $pseudo, $name, $number ) = @_;

    if ( $pseudo ) {
	emit qq(${spaces}progress_message${level} "Optional interface $name Started");
    } else {
	emit qq(${spaces}progress_message${level} "Provider $name ($number) Started");
    }
}

#
# Generate the start_provider_...() function for the passed provider
#
sub add_a_provider( $$ ) {

    my ( $providerref, $tcdevices ) = @_;

    my $table       = $providerref->{provider};
    my $number      = $providerref->{number};
    my $id          = $providerref->{id};
    my $mark        = $providerref->{rawmark};
    my $interface   = $providerref->{interface};
    my $physical    = $providerref->{physical};
    my $optional    = $providerref->{optional};
    my $gateway     = $providerref->{gateway};
    my $gatewaycase = $providerref->{gatewaycase};
    my $shared      = $providerref->{shared};
    my $default     = $providerref->{default};
    my $copy        = $providerref->{copy};
    my $balance     = $providerref->{balance};
    my $pref        = $providerref->{pref};
    my $mtu         = $providerref->{mtu};
    my $noautosrc   = $providerref->{noautosrc};
    my $track       = $providerref->{track};
    my $loose       = $providerref->{loose};
    my $duplicate   = $providerref->{duplicate};
    my $address     = $providerref->{address};
    my $mac         = $providerref->{mac};
    my $local       = $providerref->{local};
    my $tproxy      = $providerref->{tproxy};
    my $load        = $providerref->{load};
    my $pseudo      = $providerref->{pseudo};
    my $what        = $providerref->{what};
    my $label       = $pseudo ? 'Optional Interface' : 'Provider';
    my $hostroute   = $providerref->{hostroute};
    my $persistent  = $providerref->{persistent};

    my $dev         = var_base $physical;
    my $base        = uc $dev;
    my $realm = '';

    if ( $persistent ) {
	emit( '',
	      '#',
	      "# Persistent $what $table is currently disabled",
	      '#',
	      "do_persistent_${what}_${table}() {" );

	push_indent;

	emit( "if interface_is_up $physical; then" );

	push_indent;

	if ( $gatewaycase eq 'omitted' ) {
	    if ( $tproxy ) {
		emit 'run_ip route add local ' . ALLIP . " dev $physical table $id";
	    } else {
		emit "run_ip route replace default dev $physical table $id";
	    }
	}

	if ( $gateway ) {
	    $address = get_interface_address( $interface, 1 ) unless $address;

	    emit( qq([ -z "$address" ] && return\n) );

	    if ( $hostroute ) {
		emit qq(run_ip route replace $gateway src $address dev $physical ${mtu});
		emit qq(run_ip route replace $gateway src $address dev $physical ${mtu}table $id $realm);
		emit qq(echo "\$IP route del $gateway src $address dev $physical ${mtu} > /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing);
		emit qq(echo "\$IP route del $gateway src $address dev $physical ${mtu}table $id $realm > /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing);
	    }

	    emit( "run_ip route replace default via $gateway src $address dev $physical ${mtu}table $id $realm" );
	    emit( qq(echo "\$IP route del default via $gateway src $address dev $physical ${mtu}table $id $realm > /dev/null 2>&1"  >> \${VARDIR}/undo_${table}_routing) );
	}

	if ( ! $noautosrc ) {
	    if ( $shared ) {
		emit  "qt \$IP -$family rule del from $address";
		emit( "run_ip rule add from $address pref 20000 table $id" ,
		      "echo \"\$IP -$family rule del from $address pref 20000> /dev/null 2>&1\" >> \${VARDIR}/undo_${table}_routing" );
	    } else {
		emit  ( '',
			"find_interface_addresses $physical | while read address; do",
			"    qt \$IP -$family rule del from \$address",
			"    run_ip rule add from \$address pref 20000 table $id",
			"    echo \"\$IP -$family rule del from \$address pref 20000 > /dev/null 2>&1\" >> \${VARDIR}/undo_${table}_routing",
			'    rulenum=$(($rulenum + 1))',
			'done'
		      );
	    }
	}

	if ( @{$providerref->{persistent_routes}} ) {
	    emit '';
	    emit $_ for @{$providers{$table}->{persistent_routes}};
	}

	if ( @{$providerref->{persistent_rules}} ) {
	    emit '';
	    emit $_ for @{$providers{$table}->{persistent_rules}};
	}

	pop_indent;

	emit( qq(fi\n),
	      qq(echo 1 > \${VARDIR}/${physical}_disabled) );

	pop_indent;

	emit( "}\n" );
    }

    if ( $shared ) {
	my $variable = $providers{$table}{mac} = get_interface_mac( $gateway, $interface , $table, $mac );
	$realm = "realm $number";
	start_provider( $label , $table, $number, $id, qq(if interface_is_usable $physical && [ -n "$variable" ]; then) );
    } elsif ( $pseudo ) {
	start_provider( $label , $table, $number, $id, qq(if [ -n "\$SW_${base}_IS_USABLE" ]; then) );
    } else {
	if ( $optional ) {
	    start_provider( $label, $table , $number, $id, qq(if [ -n "\$SW_${base}_IS_USABLE" ]; then) );
	} elsif ( $gatewaycase eq 'detect' ) {
	    start_provider( $label, $table, $number, $id, qq(if interface_is_usable $physical && [ -n "$gateway" ]; then) );
	} else {
	    start_provider( $label, $table, $number, $id, "if interface_is_usable $physical; then" );
	}
	$provider_interfaces{$interface} = $table;

	if ( $gatewaycase eq 'omitted' ) {
	    if ( $tproxy ) {
		emit 'run_ip route add local ' . ALLIP . " dev $physical table $id";
	    } else {
		emit "run_ip route replace default dev $physical table $id";
	    }
	}
    }

    emit( "echo $load > \${VARDIR}/${table}_load",
	  'echo ' . in_hex( $mark ) . '/' . in_hex( $globals{PROVIDER_MASK} ) . " > \${VARDIR}/${table}_mark",
	  "echo $physical > \${VARDIR}/${table}_interface" ) if $load;

    emit( '',
	  "cat <<EOF >> \${VARDIR}/undo_${table}_routing" );

    emit_unindented 'case \$COMMAND in';
    emit_unindented '    enable|disable)';
    emit_unindented '        ;;';
    emit_unindented '    *)';
    emit_unindented "        rm -f \${VARDIR}/${physical}_load" if $load;
    emit_unindented "        rm -f \${VARDIR}/${physical}_mark" if $load;
    emit_unindented <<"CEOF", 1;
        rm -f \${VARDIR}/${physical}.status
        ;;
esac
EOF
CEOF
    #
    # /proc for this interface
    #
    setup_interface_proc( $interface );

    if ( $mark ne '-' ) {
	my $hexmark = in_hex( $mark );
	my $mask = have_capability( 'FWMARK_RT_MASK' ) ? '/' . in_hex( $globals{ $tproxy && ! $local ? 'TPROXY_MARK' : 'PROVIDER_MASK' } ) : '';

	emit ( "qt \$IP -$family rule del fwmark ${hexmark}${mask}" ) if $persistent || $config{DELETE_THEN_ADD};

	emit ( "run_ip rule add fwmark ${hexmark}${mask} pref $pref table $id",
	       "echo \"\$IP -$family rule del fwmark ${hexmark}${mask} > /dev/null 2>&1\" >> \${VARDIR}/undo_${table}_routing"
	    );
    }

    if ( $duplicate ne '-' ) {
	if ( $copy eq '-' ) {
	    copy_table ( $duplicate, $number, $realm );
	} else {
	    if ( $copy eq 'none' ) {
		$copy = $interface;
	    } else {
		$copy = "$interface,$copy";
	    }

	    copy_and_edit_table( $duplicate, $number, $id, $copy, $realm);
	}
    }

    if ( $gateway ) {
	$address = get_interface_address( $interface, 1 ) unless $address;

	if ( $hostroute ) {
	    emit qq(run_ip route replace $gateway src $address dev $physical ${mtu});
	    emit qq(run_ip route replace $gateway src $address dev $physical ${mtu}table $id $realm);
	}

	emit "run_ip route replace default via $gateway src $address dev $physical ${mtu}table $id $realm";
    }

    if ( $balance ) {
	balance_default_route( $balance , $gateway, $physical, $realm );
    } elsif ( $default > 0 ) {
	balance_fallback_route( $default , $gateway, $physical, $realm );
    } elsif ( $default ) {
	my $id = $providers{default}->{id};
	emit '';
	if ( $gateway ) {
	    emit qq(run_ip route replace $gateway/32 dev $physical table $id) if $hostroute;
	    emit qq(run_ip route replace default via $gateway src $address dev $physical table $id metric $number);
	    emit qq(echo "\$IP -$family route del default via $gateway table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing);
	    emit qq(echo "\$IP -4 route del $gateway/32 dev $physical table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing) if $family == F_IPV4;
	} else {
	    emit qq(run_ip route replace default table $id dev $physical metric $number);
	    emit qq(echo "\$IP -$family route del default dev $physical table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing);
	}

	emit( 'g_fallback=Yes' ) if $persistent;

	$metrics = 1;
    }

    emit( qq(\n) ,
	  qq(if ! \$IP -6 rule ls | egrep -q "32767:[[:space:]]+from all lookup (default|253)"; then) ,
	  qq(    qt \$IP -6 rule add from all table $providers{default}->{id} prio 32767\n) ,
	  qq(fi) ) if $family == F_IPV6;

    unless ( $tproxy ) {
	emit '';

	if ( $loose ) {
	    if ( $config{DELETE_THEN_ADD} ) {
		emit ( "find_interface_addresses $physical | while read address; do",
		       "    qt \$IP -$family rule del from \$address",
		       'done'
		     );
	    }
	} elsif ( ! $noautosrc ) {
	    if ( $shared ) {
		if ( $persistent ) {
		    emit( qq(if ! egrep -q "^20000:[[:space:]]+from $address lookup $id"; then),
			  qq(    qt \$IP -$family rule del from $address pref 20000),
			  qq(    run_ip rule add from $address pref 20000 table $id),
			  qq(    echo "\$IP -$family rule del from $address pref 20000> /dev/null 2>&1" >> \${VARDIR}/undo_${table}_routing ),
			  qq(fi) );
		} else {
		    emit  "qt \$IP -$family rule del from $address" if $persistent || $config{DELETE_THEN_ADD};
		    emit( "run_ip rule add from $address pref 20000 table $id" ,
			  "echo \"\$IP -$family rule del from $address pref 20000> /dev/null 2>&1\" >> \${VARDIR}/undo_${table}_routing" );
		}
	    } elsif ( ! $pseudo ) {
		emit  ( "find_interface_addresses $physical | while read address; do" );
		emit  ( "    qt \$IP -$family rule del from \$address" ) if $persistent || $config{DELETE_THEN_ADD};
		emit  ( "    run_ip rule add from \$address pref 20000 table $id",
			"    echo \"\$IP -$family rule del from \$address pref 20000 > /dev/null 2>&1\" >> \${VARDIR}/undo_${table}_routing",
			'    rulenum=$(($rulenum + 1))',
			'done'
		      );
	    }
	}
    }

    if ( @{$providerref->{rules}} ) {
	emit '';
	emit $_ for @{$providers{$table}->{rules}};
    }

    if ( @{$providerref->{routes}} ) {
	emit '';
	emit $_ for @{$providers{$table}->{routes}};
    }

    emit( '' );

    my ( $tbl, $weight );

    emit( qq(echo 0 > \${VARDIR}/${physical}.status) );

    if ( $optional ) {
	emit( '',
	      'if [ $COMMAND = enable ]; then' );

	push_indent;

	if ( $balance || $default > 0 ) {
	    $tbl    = $providers{$default ? 'default' : $config{USE_DEFAULT_RT} ? 'balance' : 'main'}->{id};
	    $weight = $balance ? $balance : $default;

	    if ( $gateway ) {
		emit qq(add_gateway "nexthop via $gateway dev $physical weight $weight $realm" ) . $tbl;
	    } else {
		emit qq(add_gateway "nexthop dev $physical weight $weight $realm" ) . $tbl;
	    }
	} else {
	    $weight = 1;
	}

	emit ( "distribute_load $maxload @load_providers" ) if $load;

	unless ( $shared ) {
	    emit( "setup_${dev}_tc" ) if $tcdevices->{$interface};
	}

	emit( qq(rm -f \${VARDIR}/${physical}_disabled),
	      $pseudo ? "run_enabled_exit ${physical} ${interface}" : "run_enabled_exit ${physical} ${interface} ${table}"
	    );

	if ( ! $pseudo && $config{USE_DEFAULT_RT} && $config{RESTORE_DEFAULT_ROUTE} ) {
	    emit  ( '#',
		    '# We now have a viable default route in the \'default\' table so delete any default routes in the main table',
		    '#',
		    'while qt \$IP -$family route del default table ' . MAIN_TABLE . '; do',
		    '    true',
		    'done',
		    ''
		);
	}

	emit_started_message( '', 2, $pseudo, $table, $number );

	if ( get_interface_option( $interface, 'used_address_variable' ) || get_interface_option( $interface, 'used_gateway_variable' ) ) {
	    emit( '',
		  'if [ -n "$g_forcereload" ]; then',
		  "    progress_message2 \"The IP address or gateway of $physical has changed -- forcing reload of the ruleset\"",
		  '    COMMAND=reload',
		  '    detect_configuration',
		  '    define_firewall',
		  'fi' );
	}

	pop_indent;

	unless ( $pseudo ) {
	    emit( 'else' );
	    emit( qq(    echo $weight > \${VARDIR}/${physical}_weight) );
	    emit( qq(    rm -f \${VARDIR}/${physical}_disabled) ) if $persistent;
	    emit_started_message( '    ', '', $pseudo, $table, $number );
	}

	emit "fi\n";

	if ( get_interface_option( $interface, 'used_address_variable' ) ) {
	    my $variable = interface_address( $interface );

	    emit( "echo \$$variable > \${VARDIR}/${physical}.address" );
	}

	if ( get_interface_option( $interface, 'used_gateway_variable' ) ) {
	    my $variable = interface_gateway( $interface );
	    emit( qq(echo "\$$variable" > \${VARDIR}/${physical}.gateway\n) );
	}
    } else {
	emit( qq(progress_message "Provider $table ($number) Started") );
    }

    pop_indent;

    emit 'else';

    push_indent;

    emit( qq(echo 1 > \${VARDIR}/${physical}.status) );

    if ( $optional ) {
	if ( $persistent ) {
	    emit( "do_persistent_${what}_${table}\n" );
	}

	if ( $shared ) {
	    emit ( "error_message \"WARNING: Gateway $gateway is not reachable -- Provider $table ($number) not Started\"" );
	} elsif ( $pseudo ) {
	    emit ( "error_message \"WARNING: Optional Interface $physical is not usable -- $table not Started\"" );
	} else {
	    emit ( "error_message \"WARNING: Interface $physical is not usable -- Provider $table ($number) not Started\"" );
	}


	if ( get_interface_option( $interface, 'used_address_variable' ) ) {
	    my $variable = interface_address( $interface );
	    emit( "\necho \$$variable > \${VARDIR}/${physical}.address" );
	}

	if ( get_interface_option( $interface, 'used_gateway_variable' ) ) {
	    my $variable = interface_gateway( $interface );
	    emit( qq(\necho "\$$variable" > \${VARDIR}/${physical}.gateway) );
	}
    } else {
	if ( $shared ) {
	    emit( "fatal_error \"Gateway $gateway is not reachable -- Provider $table ($number) Cannot be Started\"" );
	} else {
	    emit( "fatal_error \"Interface $physical is not usable -- Provider $table ($number) Cannot be Started\"" );
	}
    }

    pop_indent;

    emit 'fi';

    pop_indent;

    emit "} # End of start_${what}_${table}();";

    if ( $optional ) {
	emit( '',
	      '#',
	      "# Stop $what $table",
	      '#',
	      "stop_${what}_${table}() {" );

	push_indent;

	my $undo = "\${VARDIR}/undo_${table}_routing";

	emit( "if [ -f $undo ]; then" );

	push_indent;

	if ( $balance || $default > 0 ) {
	    $tbl    = $providers{$default ? 'default' : $config{USE_DEFAULT_RT} ? 'balance' : 'main'}->{id};
	    $weight = $balance ? $balance : $default;

	    my $via;

	    if ( $gateway ) {
		$via = "via $gateway dev $physical";
	    } else {
		$via = "dev $physical";
	    }

	    $via .= " weight $weight" unless $weight < 0;
	    $via .= " $realm"         if $realm;

	    emit( qq(delete_gateway "$via" $tbl $physical) );
	}

	emit (". $undo" );

	if ( $pseudo ) {
	    emit( "rm -f $undo" );
	} else {
	    emit( "> $undo" );
	}

	emit ( '',
	       "distribute_load $maxload @load_providers" ) if $load;

	if ( $persistent ) {
	    emit ( '',
		   'if [ $COMMAND = disable ]; then',
		   "    do_persistent_${what}_${table}",
		   "else",
		   "    echo 1 > \${VARDIR}/${physical}_disabled",
		   "fi\n",
		 );
	}

	unless ( $shared ) {
	    emit( '',
		  "qt \$TC qdisc del dev $physical root",
		  "qt \$TC qdisc del dev $physical ingress\n" ) if $tcdevices->{$interface};
	}

	emit( "echo 1 > \${VARDIR}/${physical}.status",
	      $pseudo ? "run_disabled_exit ${physical} ${interface}" : "run_disabled_exit ${physical} ${interface} ${table}"
	    );

	if ( $pseudo ) {
	    emit( "progress_message2 \"Optional Interface $table stopped\"" );
	} else {
	    emit( "progress_message2 \"Provider $table ($number) stopped\"" );
	}

	pop_indent;

	emit( 'else',
	      "    startup_error \"$undo does not exist\"",
	      'fi'
	    );

	pop_indent;

	emit '}';
    }
}

sub add_an_rtrule1( $$$$$ ) {
    my ( $source, $dest, $provider, $priority, $originalmark ) = @_;

    our $current_if;

    unless ( $providers{$provider} ) {
	my $found = 0;

	if ( "\L$provider" =~ /^(0x[a-f0-9]+|0[0-7]*|[0-9]*)$/ ) {
	    my $provider_number = numeric_value $provider;

	    for ( keys %providers ) {
		if ( $providers{$_}{number} == $provider_number ) {
		    $provider = $_;
		    $found = 1;
		    last;
		}
	    }
	}

	fatal_error "Unknown provider ($provider)" unless $found;
    }

    my $providerref = $providers{$provider};

    my $number = $providerref->{number};
    my $id     = $providerref->{id};

    fatal_error "You may not add rules for the $provider provider" if $number == LOCAL_TABLE || $number == UNSPEC_TABLE;
    fatal_error "You must specify either the source or destination in a rtrules entry" if $source eq '-' && $dest eq '-';

    if ( $dest eq '-' ) {
	$dest = 'to ' . ALLIP;
    } else {
	$dest = validate_net( $dest, 0 );
	$dest = "to $dest";
    }

    if ( $source eq '-' ) {
	$source = 'from ' . ALLIP;
    } elsif ( $source =~ s/^&// ) {
	$source = 'from ' . record_runtime_address( '&', $source, undef, 1 );
    } elsif ( $family == F_IPV4 ) {
	if ( $source =~ /:/ ) {
	    ( my $interface, $source , my $remainder ) = split( /:/, $source, 3 );
	    fatal_error "Invalid SOURCE" if defined $remainder;
	    $source = validate_net ( $source, 0 );
	    $interface = physical_name $interface;
	    $source = "iif $interface from $source";
	} elsif ( $source =~ /\..*\..*/ ) {
	    $source = validate_net ( $source, 0 );
	    $source = "from $source";
	} else {
	    $source = 'iif ' . physical_name $source;
	}
    } elsif ( $source =~  /^(.+?):<(.+)>\s*$/ ||  $source =~  /^(.+?):\[(.+)\]\s*$/ || $source =~ /^(.+?):(\[.+?\](?:\/\d+))$/ ) {
	my ($interface, $source ) = ($1, $2);
	$source = validate_net ($source, 0);
	$interface = physical_name $interface;
	$source = "iif $interface from $source";
    } elsif (  $source =~ /:.*:/ || $source =~ /\..*\..*/ ) {
	$source = validate_net ( $source, 0 );
	$source = "from $source";
    } else {
	$source = 'iif ' . physical_name $source;
    }

    my $mark = '';
    my $mask;

    if ( $originalmark ne '-' ) {
	validate_mark( $originalmark );

	( $mark, $mask ) = split '/' , $originalmark;
	$mask = $globals{PROVIDER_MASK} unless supplied $mask;

	$mark = ' fwmark ' . in_hex( $mark ) . '/' . in_hex( $mask );
    }

    my $persistent = ( $priority =~s/!$// );

    fatal_error "Invalid priority ($priority)" unless $priority && $priority =~ /^\d{1,5}$/;

    $priority = "pref $priority";

    push @{$providerref->{rules}}, "qt \$IP -$family rule del $source ${dest}${mark} $priority" if $persistent || $config{DELETE_THEN_ADD};
    push @{$providerref->{rules}}, "run_ip rule add $source ${dest}${mark} $priority table $id";

    if ( $persistent ) {
	push @{$providerref->{persistent_rules}}, "qt \$IP -$family rule del $source ${dest}${mark} $priority";
	push @{$providerref->{persistent_rules}}, "run_ip rule add $source ${dest}${mark} $priority table $id";
    }

    push @{$providerref->{rules}}, "echo \"\$IP -$family rule del $source ${dest}${mark} $priority > /dev/null 2>&1\" >> \${VARDIR}/undo_${provider}_routing";

    progress_message "   Routing rule \"$currentline\" $done";
}

sub add_an_rtrule( ) {
    my ( $sources, $dests, $provider, $priority, $originalmark ) =
	split_line( 'rtrules file',
		    { source => 0, dest => 1, provider => 2, priority => 3 , mark => 4 } );
    for my $source ( split_list( $sources, "source" ) ) {
	for my $dest (split_list( $dests , "dest" ) ) {
	    add_an_rtrule1( $source, $dest, $provider, $priority, $originalmark );
	}
    }
}

sub add_a_route( ) {
    my ( $provider, $dest, $gateway, $device, $options ) =
	split_line( 'routes file',
		    { provider => 0, dest => 1, gateway => 2, device => 3, options=> 4 } );

    our $current_if;

    fatal_error 'PROVIDER must be specified' if $provider eq '-';

    unless ( $providers{$provider} ) {
	my $found = 0;

	if ( "\L$provider" =~ /^(0x[a-f0-9]+|0[0-7]*|[0-9]*)$/ ) {
	    my $provider_number = numeric_value $provider;

	    for ( keys %providers ) {
		if ( $providers{$_}{number} == $provider_number ) {
		    $provider = $_;
		    $found = 1;
		    last;
		}
	    }
	}

	fatal_error "Unknown provider ($provider)" unless $found;
    }

    fatal_error 'DEST must be specified' if $dest eq '-';
    $dest = validate_net ( $dest, 0 );

    my $null;

    if ( $gateway =~ /^(?:blackhole|unreachable|prohibit)$/ ) {
	fatal_error q('$gateway' routes may not specify a DEVICE) unless $device eq '-';
	$null = $gateway;
    } else {
	validate_address ( $gateway, 1 ) if $gateway ne '-';
    }

    my $providerref       = $providers{$provider};
    my $number            = $providerref->{number};
    my $id                = $providerref->{id};
    my $physical          = $device eq '-' ? $providers{$provider}{physical} : physical_name( $device );
    my $routes            = $providerref->{routes};
    my $persistent_routes = $providerref->{persistent_routes};
    my $routedests        = $providerref->{routedests};

    fatal_error "You may not add routes to the $provider table" if $number == LOCAL_TABLE || $number == UNSPEC_TABLE;

    $dest .= join( '', '/', VLSM ) unless $dest =~ '/';

    if ( $routedests->{$dest} ) {
	fatal_error "Duplicate DEST ($dest) in table ($provider)";
    } else {
	$routedests->{$dest} = 1;
    }

    my $persistent;

    if ( $options ne '-' ) {
	for ( split_list1( 'option', $options ) ) {
	    my ( $option, $value ) = split /=/, $options;

	    if ( $option eq 'persistent' ) {
		fatal_error "The 'persistent' option does not accept a value" if supplied $value;
		$persistent = 1;
	    } else {
		fatal_error "Invalid route option($option)";
	    }
	}
    }

    if ( $gateway ne '-' ) {
	if ( $device ne '-' ) {
	    push @$routes,            qq(run_ip route replace $dest via $gateway dev $physical table $id);
	    push @$persistent_routes, qq(run_ip route replace $dest via $gateway dev $physical table $id) if $persistent;
	    push @$routes,             q(echo "$IP ) . qq(-$family route del $dest via $gateway dev $physical table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${provider}_routing) if $number >= DEFAULT_TABLE;
	} elsif ( $null ) {
	    push @$routes,            qq(run_ip route replace $null $dest table $id);
	    push @$persistent_routes, qq(run_ip route replace $null $dest table $id) if $persistent;
	    push @$routes,             q(echo "$IP ) . qq(-$family route del $null $dest table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${provider}_routing) if $number >= DEFAULT_TABLE;
	} else {
	    push @$routes,            qq(run_ip route replace $dest via $gateway table $id);
	    push @$persistent_routes, qq(run_ip route replace $dest via $gateway table $id) if $persistent;
	    push @$routes,             q(echo "$IP ) . qq(-$family route del $dest via $gateway table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${provider}_routing) if $number >= DEFAULT_TABLE;
	}
    } else {
	fatal_error "You must specify a device for this route" unless $physical;
	push @$routes,            qq(run_ip route replace $dest dev $physical table $id);
	push @$persistent_routes, qq(run_ip route replace $dest dev $physical table $id) if $persistent;
	push @$routes,             q(echo "$IP ) . qq(-$family route del $dest dev $physical table $id > /dev/null 2>&1" >> \${VARDIR}/undo_${provider}_routing) if $number >= DEFAULT_TABLE;
    }

    progress_message "   Route \"$currentline\" $done";
}

sub setup_null_routing() {
    my $type = $config{NULL_ROUTE_RFC1918};

    save_progress_message "Null Routing the RFC 1918 subnets";
    emit "> \${VARDIR}/undo_rfc1918_routing\n";
    for ( rfc1918_networks ) {
	if ( $providers{main}{routedests}{$_} ) {
	    warning_message "No NULL_ROUTE_RFC1918 route added for $_; there is already a route to that network defined in the routes file";
	} else {
	    emit( qq(if ! \$IP -4 route ls | grep -q '^$_.* dev '; then),
		  qq(    run_ip route replace $type $_),
		  qq(    echo "\$IP -4 route del $type $_ > /dev/null 2>&1" >> \${VARDIR}/undo_rfc1918_routing),
		  qq(fi\n) );
	}
    }
}

sub start_providers() {
    emit  ( '#',
	    '# Undo any changes made since the last time that we [re]started -- this will not restore the default route',
	    '#',
	    'undo_routing' );

    unless ( $config{KEEP_RT_TABLES} ) {
	emit( "\n#\n# Update the routing table database\n#",
	      'if [ -w /etc/iproute2/rt_tables ]; then',
	      '    cat > /etc/iproute2/rt_tables <<EOF' );

	emit_unindented join( "\n",
			      '#',
			      '# reserved values',
			      '#',
			      LOCAL_TABLE   . "\tlocal",
			      MAIN_TABLE    . "\tmain",
			      $config{USE_DEFAULT_RT} ? ( DEFAULT_TABLE . "\tdefault\n" . BALANCE_TABLE . "\tbalance" ) : DEFAULT_TABLE . "\tdefault",
			      "0\tunspec",
			      '#',
			      '# local',
			      '#' );
	for ( @providers ) {
	    emit_unindented "$providers{$_}{number}\t$_" unless $providers{$_}{pseudo};
	}

	emit_unindented 'EOF';

	emit( 'else',
	      '    error_message "WARNING: /etc/iproute2/rt_tables is missing or is not writeable"',
	      "fi\n" );
    }

    emit  ( '#',
	    '# Capture the default route(s) if we don\'t have it (them) already.',
	    '#',
	    "[ -f \${VARDIR}/default_route ] || \$IP -$family route list | save_default_route > \${VARDIR}/default_route" );

    save_progress_message 'Adding Providers...';

    emit 'DEFAULT_ROUTE=';
    emit 'FALLBACK_ROUTE=';
    emit '';

    for my $provider ( qw/main default/ ) {
	emit '';
	emit qq(> \${VARDIR}/undo_${provider}_routing );
	emit '';
	emit $_ for @{$providers{$provider}{routes}};
	emit '';
	emit $_ for @{$providers{$provider}{rules}};
    }
}

sub finish_providers() {
    my $main    = $providers{main}->{id};
    my $table   = $main;
    my $balance = $providers{balance}->{id};
    my $default = $providers{default}->{id};

    if ( $config{USE_DEFAULT_RT} ) {
	emit ( 'run_ip rule add from ' . ALLIP . " table $main pref 999",
	       'run_ip rule add from ' . ALLIP . " table $balance pref 32765",
	       "\$IP -$family rule del from " . ALLIP . " table $main pref 32766",
	       qq(echo "\$IP -$family rule add from ) . ALLIP . qq( table $main pref 32766 > /dev/null 2>&1")    . ' >> ${VARDIR}/undo_main_routing',
	       qq(echo "\$IP -$family rule del from ) . ALLIP . qq( table $main pref 999 > /dev/null 2>&1")      . ' >> ${VARDIR}/undo_main_routing',
	       qq(echo "\$IP -$family rule del from ) . ALLIP . qq( table $balance pref 32765 > /dev/null 2>&1") . ' >> ${VARDIR}/undo_balance_routing',
	       '' );
	$table = $providers{balance}->{id};
    }

    if ( $balancing ) {
	emit  ( 'if [ -n "$DEFAULT_ROUTE" ]; then' );

	if ( $family == F_IPV4 ) {
	    emit  ( "    run_ip route replace default scope global table $table \$DEFAULT_ROUTE" );
	} else {
	    emit  ( "    if echo \$DEFAULT_ROUTE | grep -q 'nexthop.+nexthop'; then",
		    "        while qt \$IP -6 route delete default table $table; do true; done",
		    "        run_ip route add default scope global table $table \$DEFAULT_ROUTE",
		    '    else',
		    "        run_ip route replace default scope global table $table \$DEFAULT_ROUTE",
		    '    fi',
		    '' );
	}

	if ( $config{USE_DEFAULT_RT} ) {
	    emit  ( '',
		    "    while qt \$IP -$family route del default table $main; do",
		    '        true',
		    '    done',
		    ''
		  );
	}

	emit  ( "    progress_message \"Default route '\$(echo \$DEFAULT_ROUTE | sed 's/\$\\s*//')' Added\"",
		'else',
		'    error_message "WARNING: No Default route added (all \'balance\' providers are down)"' );

	if ( $config{RESTORE_DEFAULT_ROUTE} ) {
	    emit qq(    [ -z "\${FALLBACK_ROUTE}\${g_fallback}" ] && restore_default_route $config{USE_DEFAULT_RT} && error_message "NOTICE: Default route restored")
	} else {
	    emit qq(    qt \$IP -$family route del default table $table && error_message "WARNING: Default route deleted from table $table");
	}

	emit(   'fi',
		'' );
    } else {
	if ( ( $fallback || @load_providers ) && $config{USE_DEFAULT_RT} ) {
	    emit  ( q(#),
		    q(# Delete any default routes in the 'main' table),
		    q(#),
		    "while qt \$IP -$family route del default table $main; do",
		    '    true',
		    'done',
		    ''
		  );
	} else {
	    emit ( q(#),
		   q(# We don't have any 'balance'. 'load='  or 'fallback=' providers so we restore any default route that we've saved),
		   q(#),
		   qq(restore_default_route $config{USE_DEFAULT_RT}),
		   ''
		 );
	}

	emit ( '#',
	       '# Delete any default routes with metric 0 in the \'balance\' table',
	       '#',
	       "while qt \$IP -$family route del default table $balance; do",
	       '    true',
	       'done',
	       ''
	     );
    }

    if ( $fallback ) {
	emit  ( 'if [ -n "$FALLBACK_ROUTE" ]; then' );

	if ( $family == F_IPV4 ) {
	    emit( "    run_ip route replace default scope global table $default \$FALLBACK_ROUTE" );
	} else {
	    emit( "    while qt \$IP -6 route delete default table $default; do true; done" );
	    emit( "    run_ip route add default scope global table $default \$FALLBACK_ROUTE" );
	}

	emit( "    progress_message \"Fallback route '\$(echo \$FALLBACK_ROUTE | sed 's/\$\\s*//')' Added\"",
	      'else',
	      '    #',
	      '    # We don\'t have any \'fallback\' providers so we delete any default routes in the default table',
	      '    #',
	      "    delete_default_routes $default",
	      'fi',
	      '' );
    } elsif ( $config{USE_DEFAULT_RT} ) {
	emit( '#',
	      '# No balanced fallback routes - delete any routes with metric 0 from the \'default\' table',
	      '#',
	      "delete_default_routes $default",
	      ''
	    );
    }
}

sub process_providers( $ ) {
    my $tcdevices = shift;

    our $providers = 0;
    our $pseudoproviders = 0;
    #
    # We defer initialization of the 'id' member until now so that the setting of USE_RT_NAMES will have been established.
    #
    unless ( $config{USE_RT_NAMES} ) {
	for ( values %providers ) {
	    $_->{id} = $_->{number};
	}
    } else {
	for ( values %providers ) {
	    $_->{id} = $_->{provider};
	}
    }

    $lastmark = 0;

    if ( my $fn = open_file 'providers' ) {
	first_entry "$doing $fn...";
	$providers += process_a_provider(0) while read_a_line( NORMAL_READ );
    }
    #
    # Treat optional interfaces as pseudo-providers
    #
    my $num = -65536;

    for ( grep interface_is_optional( $_ ) && ! $provider_interfaces{ $_ }, all_real_interfaces ) {
	$num++;
	#
	#               TABLE             NUMBER            MARK DUPLICATE INTERFACE GATEWAY OPTIONS COPY
	$currentline =  var_base($_) .  " $num              -    -         $_        -       -       -";
	#
	$pseudoproviders += process_a_provider(1);
    }

    if ( $providers ) {
	fatal_error q(Either all 'fallback' providers must specify a weight or none of them can specify a weight) if $fallback && $metrics;

	my $fn = open_file( 'route_rules' );

	if ( $fn ){
	    if ( -f ( my $fn1 = find_file 'rtrules' ) ) {
		warning_message "Both $fn and $fn1 exist: $fn1 will be ignored";
	    }
	} else {
	    $fn = open_file( 'rtrules' );
	}

	if ( $fn ) {
	    first_entry "$doing $fn...";

	    emit '';

	    add_an_rtrule while read_a_line( NORMAL_READ );
	}
    }

    my $fn = open_file 'routes';

    if ( $fn ) {
	first_entry "$doing $fn...";
	emit '';
	add_a_route while read_a_line( NORMAL_READ );
    }

    add_a_provider( $providers{$_}, $tcdevices ) for @providers;

    emithd << 'EOF';;

#
# Enable an optional provider
#
enable_provider() {
    g_interface=$1;

    case $g_interface in
EOF

    push_indent;
    push_indent;

    for my $provider (@providers ) {
	my $providerref = $providers{$provider};

	if ( $providerref->{optional} ) {
	    if ( $providerref->{shared} || $providerref->{physical} eq $provider) {
		emit "$provider)";
	    } else {
		emit( "$providerref->{physical}|$provider)" );
	    }

	    if ( $providerref->{pseudo} ) {
		emit ( "    if [ ! -f \${VARDIR}/undo_${provider}_routing ]; then",
		       "        start_interface_$provider" );
	    } elsif ( $providerref->{persistent} ) {
		emit ( "    if [ -f \${VARDIR}/$providerref->{physical}_disabled ]; then",
		       "        start_provider_$provider" );
	    } else {
		emit ( "    if [ -z \"`\$IP -$family route ls table $providerref->{number}`\" ]; then",
		       "        start_provider_$provider" );
	    }

	    emit ( '    elif [ -z "$2" ]; then',
		   "        startup_error \"Interface $providerref->{physical} is already enabled\"",
		   '    fi',
		   '    ;;'
		 );
	}
    }

    pop_indent;
    pop_indent;

    emithd << 'EOF';;
        *)
            startup_error "$g_interface is not an optional provider or interface"
            ;;
    esac
}

#
# Disable an optional provider
#
disable_provider() {
    g_interface=$1;

    case $g_interface in
EOF

    push_indent;
    push_indent;

    for my $provider (@providers ) {
	my $providerref = $providers{$provider};

	if ( $providerref->{optional} ) {
	    if ( $provider eq $providerref->{physical} ) {
		emit( "$provider)" );
	    } else {
		emit( "$providerref->{physical}|$provider)" );
	    }

	    if ( $providerref->{pseudo} ) {
		emit( "    if [ -f \${VARDIR}/undo_${provider}_routing ]; then" );
	    } elsif ( $providerref->{persistent} ) {
		emit( "    if [ ! -f \${VARDIR}/$providerref->{physical}_disabled ]; then" );
	    } else {
		emit( "    if [ -n \"`\$IP -$family route ls table $providerref->{number}`\" ]; then" );
	    }

	    emit( "        stop_$providerref->{what}_$provider",
		  '    elif [ -z "$2" ]; then',
		  "        startup_error \"Interface $providerref->{physical} is already disabled\"",
		  '    fi',
		  '    ;;'
		);
	}
    }

    pop_indent;
    pop_indent;

    emit << 'EOF';;
        *)
            startup_error "$g_interface is not an optional provider interface"
            ;;
    esac
}
EOF

}

sub have_providers() {
    return our $providers;
}

sub map_provider_to_interface() {

    my $haveoptional;

    for my $providerref ( values %providers ) {
	if ( $providerref->{optional} ) {
	    unless ( $haveoptional++ ) {
		emit( 'if [ -n "$interface" ]; then',
		      '    case $interface in' );

		push_indent;
		push_indent;
	    }

	    emit( $providerref->{provider} . ')',
		  '    interface=' . $providerref->{physical},
		  '    ;;' );
	}
    }

    if ( $haveoptional ) {
	pop_indent;
	pop_indent;
	emit( '    esac',
	      "fi\n"
	    );
    }
}

sub setup_providers() {
    our $providers;
    our $pseudoproviders;

    if ( $providers ) {
	if ( $maxload ) {
	    warning_message "The sum of the provider interface loads exceeds 1.000000" if $maxload > 1;
	    warning_message "The sum of the provider interface loads is less than 1.000000" if $maxload < 1;
	}

	emit "\nif [ -z \"\$g_noroutes\" ]; then";

	push_indent;

	start_providers;

	setup_null_routing, emit '' if $config{NULL_ROUTE_RFC1918};

	if ( @providers ) {
	    emit "start_$providers{$_}->{what}_$_" for @providers;
	    emit '';
	}

	finish_providers;

	emit "\nrun_ip route flush cache";

	pop_indent;
	emit 'fi';

	setup_route_marking if @routemarked_interfaces || @load_providers;
    } else {
	emit "\nif [ -z \"\$g_noroutes\" ]; then";

	push_indent;

	emit "undo_routing";
	emit "restore_default_route $config{USE_DEFAULT_RT}";

	if ( $pseudoproviders ) {
	    emit '';
	    emit "start_$providers{$_}->{what}_$_" for @providers;
	}

	my $standard_routes = @{$providers{main}{routes}} || @{$providers{default}{routes}};

	if ( $config{NULL_ROUTE_RFC1918} ) {
	    emit '';
	    setup_null_routing;
	    emit "\nrun_ip route flush cache" unless $standard_routes;
	}

	if ( $standard_routes ) {
	    for my $provider ( qw/main default/ ) {
		emit '';
		emit qq(> \${VARDIR}/undo_${provider}_routing );
		emit '';
		emit $_ for @{$providers{$provider}{routes}};
		emit '';
		emit $_ for @{$providers{$provider}{rules}};
	    }

	    emit "\nrun_ip route flush cache";
	}

	pop_indent;

	emit 'fi';
    }
}

#
# Emit the updown() function
#
sub compile_updown() {
    emit( '',
	  '#',
	  '# Handle the "up" and "down" commands',
	  '#',
	  'updown() # $1 = interface',
	  '{',
	);

    push_indent;

    emit( 'local state',
	  'state=cleared',
	  ''
	);

    emit 'progress_message3 "$g_product $COMMAND triggered by $1"';
    emit '';

    if ( $family == F_IPV4 ) {
	emit 'if shorewall_is_started; then';
    } else {
	emit 'if shorewall6_is_started; then';
    }

    emit( '    state=started',
	  'elif [ -f ${VARDIR}/state ]; then',
	  '    case "$(cat ${VARDIR}/state)" in',
	  '        Stopped*)',
	  '            state=stopped',
	  '            ;;',
	  '        Cleared*)',
	  '            ;;',
	  '        *)',
	  '            state=unknown',
	  '            ;;',
	  '    esac',
	  'else',
	  '    state=unknown',
	  'fi',
	  ''
	);

    emit( 'case $1 in' );

    push_indent;

    my $ignore   = find_interfaces_by_option 'ignore', 1;
    my $required = find_interfaces_by_option 'required';
    my $optional = find_interfaces_by_option 'optional';

    if ( @$ignore ) {
	my $interfaces = join '|', map get_physical( $_ ), @$ignore;

	$interfaces =~ s/\+/*/g;

	emit( "$interfaces)",
	      '    progress_message3 "$COMMAND on interface $1 ignored"',
	      '    exit 0',
	      '    ;;'
	    );
    }

    my @nonshared = ( grep $providers{$_}->{optional},
		      values %provider_interfaces );

    if ( @nonshared ) {
	my $interfaces = join( '|', map $providers{$_}->{physical}, @nonshared );

	emit "$interfaces)";

	push_indent;

	emit( q(if [ "$state" = started ]; then) ,
	      q(    if [ "$COMMAND" = up ]; then) , 
	      q(        progress_message3 "Attempting enable on interface $1") ,
	      q(        COMMAND=enable) ,
	      q(        detect_configuration $1),
	      q(        enable_provider $1),
	      q(    elif [ "$PHASE" != post-down ]; then # pre-down or not Debian) ,
	      q(        progress_message3 "Attempting disable on interface $1") ,
	      q(        COMMAND=disable) ,
	      q(        detect_configuration $1),
	      q(        disable_provider $1) ,
	      q(    fi) ,
	      q(elif [ "$COMMAND" = up ]; then) ,
	      q(    echo 0 > ${VARDIR}/${1}.status) ,
	      q(    COMMAND=start),
	      q(    progress_message3 "$g_product attempting start") ,
	      q(    detect_configuration),
	      q(    define_firewall),
	      q(else),
	      q(    progress_message3 "$COMMAND on interface $1 ignored") ,
	      q(fi) ,
	      q(;;) );

	pop_indent;
    }

    if ( @$required ) {
	my $interfaces = join '|', map get_physical( $_ ), @$required;

	my $wildcard = ( $interfaces =~ s/\+/*/g );

	emit( "$interfaces)",
	      '    if [ "$COMMAND" = up ]; then' );

	if ( $wildcard ) {
	    emit( '        if [ "$state" = started ]; then',
		  '            COMMAND=reload',
		  '        else',
		  '            COMMAND=start',
		  '        fi' );
	} else {
	    emit( '        COMMAND=start' );
	}

	emit( '        progress_message3 "$g_product attempting $COMMAND"',
	      '        detect_configuration',
	      '        define_firewall',
	      '    elif [ "$PHASE" != pre-down ]; then # Not Debian pre-down phase'
	    );

	push_indent;

	if ( $wildcard ) {

	    emit( '    if [ "$state" = started ]; then',
		  '        progress_message3 "$g_product attempting reload"',
		  '        COMMAND=reload',
		  '        detect_configuration',
		  '        define_firewall',
		  '    fi' );

	} else {
	    emit( '    COMMAND=stop',
		  '    progress_message3 "$g_product attempting stop"',
		  '    detect_configuration',
		  '    stop_firewall' );
	}

	pop_indent;

	emit( '    fi',
	      '    ;;'
	    );
    }

    if ( @$optional ) {
	my @interfaces = map( get_physical( $_ ), grep( ! $provider_interfaces{$_} , @$optional ) );
	my $interfaces = join '|', @interfaces;

	if ( $interfaces ) {
	    if ( $interfaces =~ s/\+/*/g || @interfaces > 1 ) {
		emit( "$interfaces)",
		      '    if [ "$COMMAND" = up ]; then',
		      '        echo 0 > ${VARDIR}/${1}.state',
		      '    else',
		      '        echo 1 > ${VARDIR}/${1}.state',
		      '    fi' );
	    } else {
		emit( "$interfaces)",
		      '    if [ "$COMMAND" = up ]; then',
		      "        echo 0 > \${VARDIR}/$interfaces.state",
		      '    else',
		      "        echo 1 > \${VARDIR}/$interfaces.state",
		      '    fi' );
	    }

	    emit( '',
		  '    if [ "$state" = started ]; then',
		  '        COMMAND=reload',
		  '        progress_message3 "$g_product attempting reload"',
		  '        detect_configuration',
		  '        define_firewall',
		  '    elif [ "$state" = stopped ]; then',
		  '        COMMAND=start',
		  '        progress_message3 "$g_product attempting start"',
		  '        detect_configuration',
		  '        define_firewall',
		  '    else',
		  '        progress_message3 "$COMMAND on interface $1 ignored"',
		  '    fi',
		  '    ;;',
		);
	}
    }

    if ( my @plain_interfaces = all_plain_interfaces ) {			
	my $interfaces = join ( '|', @plain_interfaces );

	$interfaces =~ s/\+/*/g;
	
	emit( "$interfaces)",
	      '    case $state in',
	      '        started)',
	      '            COMMAND=reload',
	      '            progress_message3 "$g_product attempting reload"',
	      '            detect_configuration',
	      '            define_firewall',
	      '            ;;',
	      '        *)',
	      '            progress_message3 "$COMMAND on interface $1 ignored"',
	      '            ;;',
	      '    esac',
	    );
    }

    pop_indent;

    emit( 'esac' );

    pop_indent;

    emit( '}',
	  '',
	);
}

#
# Lookup the passed provider. Raise a fatal error if provider is unknown. 
# Return the provider's realm if it is a shared provider; otherwise, return zero
#
sub provider_realm( $ ) {
    my $provider    = $_[0];
    my $providerref = $providers{ $provider };

    unless ( $providerref ) {
	fatal_error "Unknown provider ($provider)" unless $provider =~ /^(0x[a-f0-9]+|0[0-7]*|[0-9]*)$/;

	my $provider_number = numeric_value $provider;

	for ( values %providers ) {
	    $providerref = $_, last if $_->{number} == $provider_number;
	}

	fatal_error "Unknown provider ($provider)" unless $providerref;
    }

    $providerref->{shared} ? $providerref->{number} : 0;
}

#
# Perform processing related to optional interfaces. Returns true if there are optional interfaces.

#
sub handle_optional_interfaces() {

    my @interfaces;
    my $wildcards;
    #
    # First do the provider interfacess. Those that are real providers will never have wildcard physical
    # names but they might derive from wildcard interface entries. Optional interfaces which do not have
    # wildcard physical names are also included in the providers table.
    #
    for my $providerref ( grep $_->{optional} , values %providers ) {
	push @interfaces, $providerref->{interface};
	$wildcards ||= $providerref->{wildcard};
    }

    #
    # Now do the optional wild interfaces
    #
    for my $interface ( grep interface_is_optional($_) && ! $provider_interfaces{$_}, all_real_interfaces ) {
	push@interfaces, $interface;
	unless ( $wildcards ) {
	    my $interfaceref = find_interface($interface);
	    $wildcards = 1 if $interfaceref->{wildcard};
	}
    }

    if ( @interfaces ) {
	my $require     = $config{REQUIRE_INTERFACE};

	emit( 'HAVE_INTERFACE=', '' ) if $require;
	#
	# Clear the '_IS_USABLE' variables
	#
	emit( join( '_', 'SW', uc var_base( get_physical( $_ ) ) , 'IS_USABLE=' ) ) for @interfaces;

	if ( $wildcards ) {
	    #
	    # We must consider all interfaces with an address in $family -- generate a list of such addresses.
	    #
	    emit( '',
		  'for interface in $(find_all_interfaces1); do',
		);

	    push_indent;
	    emit ( 'case "$interface" in' );
	    push_indent;
	} else {
	    emit '';
	}

	for my $interface ( @interfaces ) {
	    if ( my $provider = $provider_interfaces{ $interface } ) {
		my $physical     = get_physical $interface;
		my $base         = uc var_base( $physical );
		my $providerref  = $providers{$provider};
		my $interfaceref = known_interface( $interface );
		my $wildbase     = uc $interfaceref->{base};

		emit( "$physical)" ), push_indent if $wildcards;

		if ( $provider eq $physical ) {
		    #
		    # Just an optional interface, or provider and interface are the same
		    #
		    emit qq(if [ -z "\$interface" -o "\$interface" = "$physical" ]; then);
		} else {
		    #
		    # Provider
		    #
		    emit qq(if [ -z "\$interface" -o "\$interface" = "$physical" ]; then);
		}

		push_indent;

		if ( $providerref->{gatewaycase} eq 'detect' ) {
		    emit qq(if interface_is_usable $physical && [ -n "$providerref->{gateway}" ]; then);
		} else {
		    emit qq(if interface_is_usable $physical; then);
		}

		emit( '    HAVE_INTERFACE=Yes' ) if $require;

		emit( "    SW_${base}_IS_USABLE=Yes" );
		emit( "    SW_${wildbase}_IS_USABLE=Yes" ) if $interfaceref->{wildcard};
		emit( 'fi' );

		if ( get_interface_option( $interface, 'used_address_variable' ) ) {
		    my $variable = interface_address( $interface );

		    emit( '',
			  "if [ -f \${VARDIR}/${physical}.address ]; then",
			  "    if [ \$(cat \${VARDIR}/${physical}.address) != \$$variable ]; then",
			  '        g_forcereload=Yes',
			  '    fi',
			  'fi' );
		}

		if ( get_interface_option( $interface, 'used_gateway_variable' ) ) {
		    my $variable = interface_gateway( $interface );

		    emit( '',
			  "if [ -f \${VARDIR}/${physical}.gateway ]; then",
			  "    if [ \$(cat \${VARDIR}/${physical}.gateway) != \"\$$variable\" ]; then",
			  '        g_forcereload=Yes',
			  '    fi',
			  'fi' );
		}

		pop_indent;

		emit( "fi\n" );

		emit( ';;' ), pop_indent if $wildcards;
	    } else {
		my $physical    = get_physical $interface;
		my $base        = uc var_base( $physical );
		my $case        = $physical;
		my $wild        = $case =~ s/\+$/*/;
		my $variable    = interface_address( $interface );

		if ( $wildcards ) {
		    emit( "$case)" );
		    push_indent;

		    if ( $wild ) {
			emit( qq(if [ -z "\$SW_${base}_IS_USABLE" ]; then) );
			push_indent;
			emit ( 'if interface_is_usable $interface; then' );
		    } else {
			emit ( "if interface_is_usable $physical; then" );
		    }
		} else {
		    emit ( "if interface_is_usable $physical; then" );
		}

		emit ( '    HAVE_INTERFACE=Yes' ) if $require;
		emit ( "    SW_${base}_IS_USABLE=Yes" ,
		       'fi' );

		if ( get_interface_option( $interface, 'used_address_variable' ) ) {
		    emit( '',
			  "if [ -f \${VARDIR}/${physical}.address ]; then",
			  "    if [ \$(cat \${VARDIR}/${physical}.address) != \$$variable ]; then",
			  '        g_forcereload=Yes',
			  '    fi',
			  'fi' );
		}

		if ( $wildcards ) {
		    pop_indent, emit( 'fi' ) if $wild;
		    emit( ';;' );
		    pop_indent;
		}
	    }
	}

	if ( $wildcards ) {
	    emit( '*)' ,
		  '    ;;'
		);
	    pop_indent;
	    emit( 'esac' );
	    pop_indent;
	    emit('done' );
	}

	if ( $require ) {
	    emit( '',
		  'if [ -z "$HAVE_INTERFACE" ]; then' ,
		  '    case "$COMMAND" in',
		  '        start|reload|restore)'
		);

	    if ( $family == F_IPV4 ) {
		emit( '            if shorewall_is_started; then' );
	    } else {
		emit( '            if shorewall6_is_started; then' );
	    }

	    emit( '                fatal_error "No network interface available"',
		  '            else',
		  '                startup_error "No network interface available"',
		  '            fi',
		  '            ;;',
		  '    esac',
		  'fi'
		);
	}

	return 1;
    }
}

#
# The Tc module has collected the 'sticky' rules in the 'tcpre' and 'tcout' chains. In this function, we apply them
# to the 'tracked' providers
#
sub handle_stickiness( $ ) {
    my $havesticky   = shift;
    my $mask         = in_hex( $globals{PROVIDER_MASK} );
    my $setstickyref = $mangle_table->{setsticky};
    my $setstickoref = $mangle_table->{setsticko};
    my $tcpreref     = $mangle_table->{tcpre};
    my $tcoutref     = $mangle_table->{tcout};
    my %marked_interfaces;
    my $sticky = 1;

    if ( $havesticky ) {
	fatal_error "There are SAME tcrules but no 'track' providers" unless @routemarked_providers;

	for my $providerref ( @routemarked_providers ) {
	    my $interface = $providerref->{physical};
	    my $base      = uc var_base $interface;
	    my $mark      = $providerref->{mark};

	    for ( grep rule_target($_) eq 'sticky', @{$tcpreref->{rules}} ) {
		my $stickyref = ensure_mangle_chain 'sticky';
		my ( $rule1, $rule2 );
		my $list = sprintf "sticky%03d" , $sticky++;

		for my $chainref ( $stickyref, $setstickyref ) {
		    if ( $chainref->{name} eq 'sticky' ) {
			$rule1 = clone_irule( $_ );

			set_rule_target( $rule1, 'MARK',   "--set-mark $mark" );
			set_rule_option( $rule1, 'recent', "--name $list --update --seconds $rule1->{t} --reap" );

			$rule2 = clone_irule( $_ );

			clear_rule_target( $rule2 );
			set_rule_option( $rule2, 'mark',   "--mark 0\/$mask" );
			set_rule_option( $rule2, 'recent', "--name $list --remove" );
		    } else {
			$rule1 = clone_irule( $_ );

			clear_rule_target( $rule1 );
			set_rule_option( $rule1, 'mark',   "--mark $mark\/$mask" );
			set_rule_option( $rule1, 'recent', "--name $list --set" );

			$rule2 = '';
		    }

		    add_trule $chainref, $rule1;

		    if ( $rule2 ) {
			add_trule $chainref, $rule2;
		    }
		}
	    }

	    for ( grep rule_target( $_ ) eq 'sticko', , @{$tcoutref->{rules}} ) {
		my ( $rule1, $rule2 );
		my $list = sprintf "sticky%03d" , $sticky++;
		my $stickoref = ensure_mangle_chain 'sticko';

		for my $chainref ( $stickoref, $setstickoref ) {
		    if ( $chainref->{name} eq 'sticko' ) {
			$rule1 = clone_irule $_;

			set_rule_target( $rule1, 'MARK',   "--set-mark $mark" );
			set_rule_option( $rule1, 'recent', " --name $list --rdest --update --seconds $rule1->{t} --reap" );

			$rule2 = clone_irule $_;

			clear_rule_target( $rule2 );
			set_rule_option  ( $rule2, 'mark',   "--mark 0\/$mask" );
			set_rule_option  ( $rule2, 'recent', "--name $list --rdest --remove" );
		    } else {
			$rule1 = clone_irule $_;

			clear_rule_target( $rule1 );
			set_rule_option  ( $rule1, 'mark',   "--mark $mark" );
			set_rule_option  ( $rule1, 'recent', "--name $list --rdest --set" );

			$rule2 = '';
		    }

		    add_trule $chainref, $rule1;

		    if ( $rule2 ) {
			add_trule $chainref, $rule2;
		    }
		}
	    }
	}
    }

    if ( @routemarked_providers || @load_providers ) {
	delete_jumps $mangle_table->{PREROUTING}, $setstickyref unless @{$setstickyref->{rules}};
	delete_jumps $mangle_table->{OUTPUT},     $setstickoref unless @{$setstickoref->{rules}};
    }
}

sub setup_load_distribution() {
    emit ( '',
	   "distribute_load $maxload @load_providers" ,
	   ''
	 ) if @load_providers;
}

1;
