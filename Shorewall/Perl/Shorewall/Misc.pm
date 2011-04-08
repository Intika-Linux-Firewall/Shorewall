#
# Shorewall 4.4 -- /usr/share/shorewall/Shorewall/Misc.pm
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2007,2008,2009,2010 - Tom Eastep (teastep@shorewall.net)
#
#       Complete documentation is available at http://shorewall.net
#
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of Version 2 of the GNU General Public License
#       as published by the Free Software Foundation.
#
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty ofs
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#   This module contains those routines that don't seem to fit well elsewhere. It
#   was carved from the Rules module in 4.4.16.
#
package Shorewall::Misc;
require Exporter;

use Shorewall::Config qw(:DEFAULT :internal);
use Shorewall::IPAddrs;
use Shorewall::Zones;
use Shorewall::Chains qw(:DEFAULT :internal);
use Shorewall::Rules;
use Shorewall::Proc;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( process_tos
		  setup_ecn
		  add_common_rules
		  setup_mac_lists
		  process_routestopped
		  compile_stop_firewall
		  generate_matrix
		  );
our @EXPORT_OK = qw( initialize );
our $VERSION = '4.4_19';

our $family;

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
}

sub process_tos() {
    my $chain    = have_capability( 'MANGLE_FORWARD' ) ? 'fortos'  : 'pretos';
    my $stdchain = have_capability( 'MANGLE_FORWARD' ) ? 'FORWARD' : 'PREROUTING';

    my %tosoptions = ( 'minimize-delay'       => 0x10 ,
		       'maximize-throughput'  => 0x08 ,
		       'maximize-reliability' => 0x04 ,
		       'minimize-cost'        => 0x02 ,
		       'normal-service'       => 0x00 );

    if ( my $fn = open_file 'tos' ) {
	my $first_entry = 1;

	my ( $pretosref, $outtosref );

	first_entry( sub { progress_message2 "$doing $fn..."; $pretosref = ensure_chain 'mangle' , $chain; $outtosref = ensure_chain 'mangle' , 'outtos'; } );

	while ( read_a_line ) {

	    my ($src, $dst, $proto, $sports, $ports , $tos, $mark ) = split_line 6, 7, 'tos file entry';

	    $first_entry = 0;

	    fatal_error 'A value must be supplied in the TOS column' if $tos eq '-';

	    if ( defined ( my $tosval = $tosoptions{"\L$tos"} ) ) {
		$tos = $tosval;
	    } else {
		my $val = numeric_value( $tos );
		fatal_error "Invalid TOS value ($tos)" unless defined( $val ) && $val < 0x1f;
	    }

	    my $chainref;

	    my $restriction = NO_RESTRICT;

	    my ( $srczone , $source , $remainder );

	    if ( $family == F_IPV4 ) {
		( $srczone , $source , $remainder ) = split( /:/, $src, 3 );
		fatal_error 'Invalid SOURCE' if defined $remainder;
	    } elsif ( $src =~ /^(.+?):<(.*)>\s*$/ || $src =~ /^(.+?):\[(.*)\]\s*$/ ) {
		$srczone = $1;
		$source  = $2;
	    } else {
		$srczone = $src;
	    }

	    if ( $srczone eq firewall_zone ) {
		$chainref    = $outtosref;
		$src         = $source || '-';
		$restriction = OUTPUT_RESTRICT;
	    } else {
		$chainref = $pretosref;
		$src =~ s/^all:?//;
	    }

	    $dst =~ s/^all:?//;

	    expand_rule
		$chainref ,
		$restriction ,
		do_proto( $proto, $ports, $sports ) . do_test( $mark , $globals{TC_MASK} ) ,
		$src ,
		$dst ,
		'' ,
		"TOS --set-tos $tos" ,
		'' ,
		'TOS' ,
		'';
	}

	unless ( $first_entry ) {
	    add_jump( $mangle_table->{$stdchain}, $chain,   0 ) if $pretosref->{referenced};
	    add_jump( $mangle_table->{OUTPUT},    'outtos', 0 ) if $outtosref->{referenced};
	}
    }
}

#
# Setup ECN disabling rules
#
sub setup_ecn()
{
    my %interfaces;
    my @hosts;

    if ( my $fn = open_file 'ecn' ) {

	first_entry "$doing $fn...";

	while ( read_a_line ) {

	    my ($interface, $hosts ) = split_line 1, 2, 'ecn file entry';

	    fatal_error "Unknown interface ($interface)" unless known_interface $interface;

	    $interfaces{$interface} = 1;

	    $hosts = ALLIP if $hosts eq '-';

	    for my $host( split_list $hosts, 'address' ) {
		validate_host( $host , 1 );
		push @hosts, [ $interface, $host ];
	    }
	}

	if ( @hosts ) {
	    my @interfaces = ( keys %interfaces );

	    progress_message "$doing ECN control on @interfaces...";

	    for my $interface ( @interfaces ) {
		my $chainref = ensure_chain 'mangle', ecn_chain( $interface );

		add_jump $mangle_table->{POSTROUTING} , $chainref, 0, "-p tcp " . match_dest_dev( $interface );
		add_jump $mangle_table->{OUTPUT},       $chainref, 0, "-p tcp " . match_dest_dev( $interface );
	    }

	    for my $host ( @hosts ) {
		add_rule $mangle_table->{ecn_chain $host->[0]}, join ('', '-p tcp ', match_dest_net( $host->[1] ) , ' -j ECN --ecn-tcp-remove' );
	    }
	}
    }
}

sub add_rule_pair( $$$$ ) {
    my ($chainref , $predicate , $target , $level ) = @_;

    log_rule( $level, $chainref, "\U$target", $predicate )  if defined $level && $level ne '';
    add_jump( $chainref , $target, 0, $predicate );
}

sub setup_blacklist() {

    my $zones  = find_zones_by_option 'blacklist', 'in';
    my $zones1 = find_zones_by_option 'blacklist', 'out';
    my $chainref;
    my $chainref1;
    my ( $level, $disposition ) = @config{'BLACKLIST_LOGLEVEL', 'BLACKLIST_DISPOSITION' };
    my $target = $disposition eq 'REJECT' ? 'reject' : $disposition;
    #
    # We go ahead and generate the blacklist chains and jump to them, even if they turn out to be empty. That is necessary
    # for 'refresh' to work properly.
    #
    if ( @$zones || @$zones1 ) {
	$chainref  = dont_delete new_standard_chain 'blacklst' if @$zones;
	$chainref1 = dont_delete new_standard_chain 'blackout' if @$zones1;

	if ( defined $level && $level ne '' ) {
	    my $logchainref = new_standard_chain 'blacklog';

	    log_rule_limit( $level , $logchainref , 'blacklst' , $disposition , "$globals{LOGLIMIT}" , '', 'add',	'' );

	    add_jump $logchainref, $target, 1;

	    $target = 'blacklog';
	}
    }

  BLACKLIST:
    {
	if ( my $fn = open_file 'blacklist' ) {

	    my $first_entry = 1;

	    first_entry "$doing $fn...";

	    while ( read_a_line ) {

		if ( $first_entry ) {
		    unless  ( @$zones || @$zones1 ) {
			warning_message qq(The entries in $fn have been ignored because there are no 'blacklist' zones);
			close_file;
			last BLACKLIST;
		    }

		    $first_entry = 0;
		}

		my ( $networks, $protocol, $ports, $options ) = split_line 1, 4, 'blacklist file';

		$options = 'src' if $options eq '-';

		my ( $to, $from ) = ( 0, 0 );

		for ( split /,/, $options ) {
		    if ( $_ =~ /^(?:from|src)$/ ) {
			if ( $from++ ) {
			    warning_message "Duplicate 'src' ignored";
			} else {
			    if ( @$zones ) {
				expand_rule(
					    $chainref ,
					    NO_RESTRICT ,
					    do_proto( $protocol , $ports, '' ) ,
					    $networks,
					    '',
					    '' ,
					    $target ,
					    '' ,
					    $target ,
					    '' );
			    } else {
				warning_message '"src" entry ignored because there are no "blacklist in" zones';
			    }
			}
		    } elsif ( $_ =~ /^(?:dst|to)$/ ) {
			if ( $to++ ) {
			    warning_message "Duplicate 'dst' ignored";
			} else {
			    if ( @$zones1 ) {
				expand_rule(
					    $chainref1 ,
					    NO_RESTRICT ,
					    do_proto( $protocol , $ports, '' ) ,
					    '',
					    $networks,
					    '' ,
					    $target ,
					    '' ,
					    $target ,
					    '' );
			    } else {
				warning_message '"dst" entry ignored because there are no "blacklist out" zones';
			    }
			}
		    } else {
			fatal_error "Invalid blacklist option($_)";
		    }
		}

		progress_message "  \"$currentline\" added to blacklist";
	    }

	    warning_message q(There are interfaces or zones with the 'blacklist' option but the 'blacklist' file is empty) if $first_entry && @$zones;
	} elsif ( @$zones || @$zones1 ) {
	    warning_message q(There are interfaces or zones with the 'blacklist' option, but the 'blacklist' file is either missing or has zero size);
	}
    }
}

sub process_routestopped() {

    if ( my $fn = open_file 'routestopped' ) {
	my ( @allhosts, %source, %dest , %notrack, @rule );

	my $seq = 0;

	first_entry "$doing $fn...";

	while ( read_a_line ) {

	    my ($interface, $hosts, $options , $proto, $ports, $sports ) = split_line 1, 6, 'routestopped file';

	    my $interfaceref;

	    fatal_error "Unknown interface ($interface)" unless $interfaceref = known_interface $interface;
	    $hosts = ALLIP unless $hosts && $hosts ne '-';

	    my $routeback = 0;

	    my @hosts;

	    $seq++;

	    my $rule = do_proto( $proto, $ports, $sports, 0 );

	    for my $host ( split /,/, $hosts ) {
		fatal_error "Ipsets not allowed with SAVE_IPSETS=Yes" if $host =~ /^!?\+/ && $config{SAVE_IPSETS};
		validate_host $host, 1;
		push @hosts, "$interface|$host|$seq";
		push @rule, $rule;
	    }


	    unless ( $options eq '-' ) {
		for my $option (split /,/, $options ) {
		    if ( $option eq 'routeback' ) {
			if ( $routeback ) {
			    warning_message "Duplicate 'routeback' option ignored";
			} else {
			    $routeback = 1;
			}
		    } elsif ( $option eq 'source' ) {
			for my $host ( split /,/, $hosts ) {
			    $source{"$interface|$host|$seq"} = 1;
			}
		    } elsif ( $option eq 'dest' ) {
			for my $host ( split /,/, $hosts ) {
			    $dest{"$interface|$host|$seq"} = 1;
			}
		    } elsif ( $option eq 'notrack' ) {
			for my $host ( split /,/, $hosts ) {
			    $notrack{"$interface|$host|$seq"} = 1;
			}
		    } else {
			warning_message "Unknown routestopped option ( $option ) ignored" unless $option eq 'critical';
			warning_message "The 'critical' option is no longer supported (or needed)";
		    }
		}
	    }

	    if ( $routeback || $interfaceref->{options}{routeback} ) {
		my $chainref = $filter_table->{FORWARD};

		for my $host ( split /,/, $hosts ) {
		    add_rule( $chainref ,
			      match_source_dev( $interface ) .
			      match_dest_dev( $interface ) .
			      match_source_net( $host ) .
			      match_dest_net( $host ) );
		    clearrule;
		}
	    }

	    push @allhosts, @hosts;
	}

	for my $host ( @allhosts ) {
	    my ( $interface, $h, $seq ) = split /\|/, $host;
	    my $source  = match_source_net $h;
	    my $dest    = match_dest_net $h;
	    my $sourcei = match_source_dev $interface;
	    my $desti   = match_dest_dev $interface;
	    my $rule    = shift @rule;

	    add_rule $filter_table->{INPUT},  "$sourcei $source $rule -j ACCEPT", 1;
	    add_rule $filter_table->{OUTPUT}, "$desti $dest $rule -j ACCEPT", 1 unless $config{ADMINISABSENTMINDED};

	    my $matched = 0;

	    if ( $source{$host} ) {
		add_rule $filter_table->{FORWARD}, "$sourcei $source $rule -j ACCEPT", 1;
		$matched = 1;
	    }

	    if ( $dest{$host} ) {
		add_rule $filter_table->{FORWARD}, "$desti $dest $rule -j ACCEPT", 1;
		$matched = 1;
	    }

	    if ( $notrack{$host} ) {
		add_rule $raw_table->{PREROUTING}, "$sourcei $source $rule -j NOTRACK", 1;
		add_rule $raw_table->{OUTPUT},     "$desti $dest $rule -j NOTRACK", 1;
	    }

	    unless ( $matched ) {
		for my $host1 ( @allhosts ) {
		    unless ( $host eq $host1 ) {
			my ( $interface1, $h1 , $seq1 ) = split /\|/, $host1;
			my $dest1 = match_dest_net $h1;
			my $desti1 = match_dest_dev $interface1;
			add_rule $filter_table->{FORWARD}, "$sourcei $desti1 $source $dest1 $rule -j ACCEPT", 1;
			clearrule;
		    }
		}
	    }
	}
    }
}

sub setup_mss();

sub add_common_rules() {
    my $interface;
    my $chainref;
    my $target;
    my $rule;
    my $list;
    my $chain;

    my $state     = $config{BLACKLISTNEWONLY} ? $globals{UNTRACKED} ? "-m state --state NEW,INVALID,UNTRACKED " : "$globals{STATEMATCH} NEW,INVALID " : '';
    my $level     = $config{BLACKLIST_LOGLEVEL};
    my $rejectref = dont_move new_standard_chain 'reject';

    if ( $config{DYNAMIC_BLACKLIST} ) {
	add_rule_pair dont_delete( new_standard_chain( 'logdrop' ) ),   ' ' , 'DROP'   , $level ;
	add_rule_pair dont_delete( new_standard_chain( 'logreject' ) ), ' ' , 'reject' , $level ;
	$chainref = dont_optimize( new_standard_chain( 'dynamic' ) );
	add_jump $filter_table->{$_}, $chainref, 0, $state for qw( INPUT FORWARD );
	add_commands( $chainref, '[ -f ${VARDIR}/.dynamic ] && cat ${VARDIR}/.dynamic >&3' );
    }

    setup_mss;

    if ( $config{FASTACCEPT} ) {
	add_rule( $filter_table->{$_} , "$globals{STATEMATCH} ESTABLISHED,RELATED -j ACCEPT" ) for qw( INPUT FORWARD OUTPUT );
    }

    for $interface ( grep $_ ne '%vserver%', all_interfaces ) {
	ensure_chain( 'filter', $_ ) for first_chains( $interface ), output_chain( $interface );
    }

    run_user_exit1 'initdone';

    setup_blacklist;

    $list = find_hosts_by_option 'nosmurfs';

    if ( @$list ) {
	progress_message2 'Adding Anti-smurf Rules';

	$chainref = new_standard_chain 'smurfs';

	my $smurfdest;

	if ( defined $config{SMURF_LOG_LEVEL} && $config{SMURF_LOG_LEVEL} ne '' ) {
	    my $smurfref = new_chain( 'filter', $smurfdest = 'smurflog' );

	    log_rule_limit( $config{SMURF_LOG_LEVEL},
			    $smurfref,
			    'smurfs' ,
			    'DROP',
			    $globals{LOGLIMIT},
			    '',
			    'add',
			    '' );
	    add_rule( $smurfref, '-j DROP' );
	} else {
	    $smurfdest = 'DROP';
	}

	if ( have_capability( 'ADDRTYPE' ) ) {
	    if ( $family == F_IPV4 ) {
		add_rule $chainref , '-s 0.0.0.0 -j RETURN';
	    } else {
		add_rule $chainref , '-s :: -j RETURN';
	    }

	    add_jump( $chainref, $smurfdest, 1, '-m addrtype --src-type BROADCAST ' ) ;
	} else {
	    if ( $family == F_IPV4 ) {
		add_commands $chainref, 'for address in $ALL_BCASTS; do';
	    } else {
		add_commands $chainref, 'for address in $ALL_ACASTS; do';
	    }

	    incr_cmd_level $chainref;
	    add_jump( $chainref, $smurfdest, 1, '-s $address ' );
	    decr_cmd_level $chainref;
	    add_commands $chainref, 'done';
	}

	if ( $family == F_IPV4 ) {
	    add_jump( $chainref, $smurfdest, 1, '-s 224.0.0.0/4 ' );
	} else {
	    add_jump( $chainref, $smurfdest, 1, '-s ' . IPv6_MULTICAST . ' ' );
	}

	my $state = $globals{UNTRACKED} ? '-m state --state NEW,INVALID,UNTRACKED ' : "$globals{STATEMATCH} NEW,INVALID ";

	for my $hostref  ( @$list ) {
	    $interface     = $hostref->[0];
	    my $ipsec      = $hostref->[1];
	    my $policy     = have_ipsec ? "-m policy --pol $ipsec --dir in " : '';
	    my $target     = source_exclusion( $hostref->[3], $chainref );

	    for $chain ( first_chains $interface ) {
		add_jump $filter_table->{$chain} , $target, 0, join( '', $state, match_source_net( $hostref->[2] ),  $policy );
	    }

	    set_interface_option $interface, 'use_input_chain', 1;
	    set_interface_option $interface, 'use_forward_chain', 1;
	}
    }

    if ( have_capability( 'ADDRTYPE' ) ) {
	add_rule $rejectref , '-m addrtype --src-type BROADCAST -j DROP';
    } else {
	if ( $family == F_IPV4 ) {
	    add_commands $rejectref, 'for address in $ALL_BCASTS; do';
	} else {
	    add_commands $rejectref, 'for address in $ALL_ACASTS; do';
	}

	incr_cmd_level $rejectref;
	add_rule $rejectref, '-d $address -j DROP';
	decr_cmd_level $rejectref;
	add_commands $rejectref, 'done';
    }

    if ( $family == F_IPV4 ) {
	add_rule $rejectref , '-s 224.0.0.0/4 -j DROP';
    } else {
	add_rule $rejectref , '-s ' . IPv6_MULTICAST . ' -j DROP';
    }

    add_rule $rejectref , '-p 2 -j DROP';
    add_rule $rejectref , '-p 6 -j REJECT --reject-with tcp-reset';

    if ( have_capability( 'ENHANCED_REJECT' ) ) {
	add_rule $rejectref , '-p 17 -j REJECT';

	if ( $family == F_IPV4 ) {
	    add_rule $rejectref, '-p 1 -j REJECT --reject-with icmp-host-unreachable';
	    add_rule $rejectref, '-j REJECT --reject-with icmp-host-prohibited';
	} else {
	    add_rule $rejectref, '-p 58 -j REJECT --reject-with icmp6-addr-unreachable';
	    add_rule $rejectref, '-j REJECT --reject-with icmp6-adm-prohibited';
	}
    } else {
	add_rule $rejectref , '-j REJECT';
    }

    $list = find_interfaces_by_option 'dhcp';

    if ( @$list ) {
	progress_message2 'Adding rules for DHCP';

	my $ports = $family == F_IPV4 ? '67:68' : '546:547';

	for $interface ( @$list ) {
	    set_interface_option $interface, 'use_input_chain', 1;
	    set_interface_option $interface, 'use_forward_chain', 1;

	    for $chain ( input_chain $interface, output_chain $interface ) {
		add_rule $filter_table->{$chain} , "-p udp --dport $ports -j ACCEPT";
	    }

	    add_rule( $filter_table->{forward_chain $interface} ,
		      "-p udp " .
		      match_dest_dev( $interface ) .
		      "--dport $ports -j ACCEPT" )
		if get_interface_option( $interface, 'bridge' );
	}
    }

    $list = find_hosts_by_option 'tcpflags';

    if ( @$list ) {
	my $disposition;

	progress_message2 "$doing TCP Flags filtering...";

	$chainref = new_standard_chain 'tcpflags';

	if ( $config{TCP_FLAGS_LOG_LEVEL} ne ''  ) {
	    my $logflagsref = new_standard_chain 'logflags';

	    my $savelogparms = $globals{LOGPARMS};

	    $globals{LOGPARMS} = "$globals{LOGPARMS}--log-ip-options ";

	    log_rule $config{TCP_FLAGS_LOG_LEVEL} , $logflagsref , $config{TCP_FLAGS_DISPOSITION}, '';

	    $globals{LOGPARMS} = $savelogparms;

	    if ( $config{TCP_FLAGS_DISPOSITION} eq 'REJECT' ) {
		add_rule $logflagsref , '-p 6 -j REJECT --reject-with tcp-reset';
	    } else {
		add_rule $logflagsref , "-j $config{TCP_FLAGS_DISPOSITION}";
	    }

	    $disposition = 'logflags';
	} else {
	    $disposition = $config{TCP_FLAGS_DISPOSITION};
	}

	add_jump $chainref , $disposition, 1, '-p tcp --tcp-flags ALL FIN,URG,PSH ';
	add_jump $chainref , $disposition, 1, '-p tcp --tcp-flags ALL NONE ';
	add_jump $chainref , $disposition, 1, '-p tcp --tcp-flags SYN,RST SYN,RST ';
	add_jump $chainref , $disposition, 1, '-p tcp --tcp-flags SYN,FIN SYN,FIN ';
	add_jump $chainref , $disposition, 1, '-p tcp --syn --sport 0 ';

	for my $hostref  ( @$list ) {
	    my $interface  = $hostref->[0];
	    my $target     = source_exclusion( $hostref->[3], $chainref );
	    my $policy     = have_ipsec ? "-m policy --pol $hostref->[1] --dir in " : '';

	    for $chain ( first_chains $interface ) {
		add_jump $filter_table->{$chain} , $target, 0, join( '', '-p tcp ', match_source_net( $hostref->[2] ), $policy );
	    }
	    set_interface_option $interface, 'use_input_chain', 1;
	    set_interface_option $interface, 'use_forward_chain', 1;
	}
    }

    if ( $family == F_IPV4 ) {
	my $announced = 0;

	$list = find_interfaces_by_option 'upnp';

	if ( @$list ) {
	    progress_message2 "$doing UPnP";

	    $chainref = dont_optimize new_nat_chain( 'UPnP' );

	    add_commands( $chainref, '[ -s /${VARDIR}/.UPnP ] && cat ${VARDIR}/.UPnP >&3' );

	    $announced = 1;

	    for $interface ( @$list ) {
		add_jump $nat_table->{PREROUTING} , 'UPnP', 0, match_source_dev ( $interface );
	    }
	}

	$list = find_interfaces_by_option 'upnpclient';

	if ( @$list ) {
	    progress_message2 "$doing UPnP" unless $announced;

	    for $interface ( @$list ) {
		my $chainref = $filter_table->{input_chain $interface};
		my $base     = uc chain_base get_physical $interface;
		my $variable = get_interface_gateway $interface;

		if ( interface_is_optional $interface ) {
		    add_commands( $chainref,
				  qq(if [ -n "SW_\$${base}_IS_USABLE" -a -n "$variable" ]; then) ,
				  '    echo "-A ' . match_source_dev( $interface ) . qq(-s $variable -p udp -j ACCEPT" >&3) ,
				  qq(fi) );
		} else {
		    add_rule( $chainref, match_source_dev( $interface ) . qq(-s $variable -p udp -j ACCEPT) );
		}
	    }
	}
    }

    setup_syn_flood_chains;

}

my %maclist_targets = ( ACCEPT => { target => 'RETURN' , mangle => 1 } ,
			REJECT => { target => 'reject' , mangle => 0 } ,
			DROP   => { target => 'DROP' ,   mangle => 1 } );

sub setup_mac_lists( $ ) {

    my $phase = $_[0];

    my %maclist_interfaces;

    my $table = $config{MACLIST_TABLE};

    my $maclist_hosts = find_hosts_by_option 'maclist';

    my $target      = $globals{MACLIST_TARGET};
    my $level       = $config{MACLIST_LOG_LEVEL};
    my $disposition = $config{MACLIST_DISPOSITION};
    my $ttl         = $config{MACLIST_TTL};

    progress_message2 "$doing MAC Filtration -- Phase $phase...";

    for my $hostref ( @$maclist_hosts ) {
	$maclist_interfaces{ $hostref->[0] } = 1;
    }

    my @maclist_interfaces = ( sort keys %maclist_interfaces );

    if ( $phase == 1 ) {

	for my $interface ( @maclist_interfaces ) {
	    my $chainref = new_chain $table , mac_chain $interface;

	    if ( $family == F_IPV4 ) {
		add_rule $chainref , '-s 0.0.0.0 -d 255.255.255.255 -p udp --dport 67:68 -j RETURN'
		    if $table eq 'mangle'  && get_interface_option( $interface, 'dhcp');
	    } else {
		#
		# Accept any packet with a link-level source or destination address
		#
		add_rule $chainref , '-s ff80::/10 -j RETURN';
		add_rule $chainref , '-d ff80::/10 -j RETURN';
		#
		# Accept Multicast
		#
		add_rule $chainref , '-d ' . IPv6_MULTICAST . ' -j RETURN';
	    }

	    if ( $ttl ) {
		my $chain1ref = new_chain $table, macrecent_target $interface;

		my $chain = $chainref->{name};

		add_rule $chainref, "-m recent --rcheck --seconds $ttl --name $chain -j RETURN";
		add_jump $chainref, $chain1ref, 0;
		add_rule $chainref, "-m recent --update --name $chain -j RETURN";
		add_rule $chainref, "-m recent --set --name $chain";
	    }
	}

	if ( my $fn = open_file 'maclist' ) {

	    first_entry "$doing $fn...";

	    while ( read_a_line ) {

		my ( $original_disposition, $interface, $mac, $addresses  ) = split_line1 3, 4, 'maclist file';

		if ( $original_disposition eq 'COMMENT' ) {
		    process_comment;
		} else {
		    my ( $disposition, $level, $remainder) = split( /:/, $original_disposition, 3 );

		    fatal_error "Invalid DISPOSITION ($original_disposition)" if defined $remainder || ! $disposition;

		    my $targetref = $maclist_targets{$disposition};

		    fatal_error "Invalid DISPOSITION ($original_disposition)"              if ! $targetref || ( ( $table eq 'mangle' ) && ! $targetref->{mangle} );
		    fatal_error "Unknown Interface ($interface)"                           unless known_interface( $interface );
		    fatal_error "No hosts on $interface have the maclist option specified" unless $maclist_interfaces{$interface};

		    my $chainref = $chain_table{$table}{( $ttl ? macrecent_target $interface : mac_chain $interface )};

		    $mac       = '' unless $mac && ( $mac ne '-' );
		    $addresses = '' unless defined $addresses && ( $addresses ne '-' );

		    fatal_error "You must specify a MAC address or an IP address" unless $mac || $addresses;

		    $mac = mac_match $mac if $mac;

		    if ( $addresses ) {
			for my $address ( split ',', $addresses ) {
			    my $source = match_source_net $address;
			    log_rule_limit $level, $chainref , mac_chain( $interface) , $disposition, '', '', 'add' , "${mac}${source}"
				if defined $level && $level ne '';
			    add_jump $chainref , $targetref->{target}, 0, "${mac}${source}";
			}
		    } else {
			log_rule_limit $level, $chainref , mac_chain( $interface) , $disposition, '', '', 'add' , $mac
			    if defined $level && $level ne '';
			add_jump $chainref , $targetref->{target}, 0, "$mac";
		    }

		    progress_message "      Maclist entry \"$currentline\" $done";
		}
	    }

	    clear_comment;
	}
	#
	# Generate jumps from the input and forward chains
	#
	for my $hostref ( @$maclist_hosts ) {
	    my $interface  = $hostref->[0];
	    my $ipsec      = $hostref->[1];
	    my $policy     = have_ipsec ? "-m policy --pol $ipsec --dir in " : '';
	    my $source     = match_source_net $hostref->[2];

	    my $state = $globals{UNTRACKED} ? '-m state --state NEW,UNTRACKED' : "$globals{STATEMATCH} NEW";

	    if ( $table eq 'filter' ) {
		my $chainref = source_exclusion( $hostref->[3], $filter_table->{mac_chain $interface} );

		for my $chain ( first_chains $interface ) {
		    add_jump $filter_table->{$chain} , $chainref, 0, "${source}${state} ${policy}";
		}

		set_interface_option $interface, 'use_input_chain', 1;
		set_interface_option $interface, 'use_forward_chain', 1;
	    } else {
		my $chainref = source_exclusion( $hostref->[3], $mangle_table->{mac_chain $interface} );
		add_jump $mangle_table->{PREROUTING}, $chainref, 0, match_source_dev( $interface ) . "${source}${state} ${policy}";
	    }
	}
    } else {
	#
	# Phase II
	#
	for my $interface ( @maclist_interfaces ) {
	    my $chainref = $chain_table{$table}{( $ttl ? macrecent_target $interface : mac_chain $interface )};
	    my $chain    = $chainref->{name};

	    if ( $family == F_IPV4 ) {
		if ( $level ne '' || $disposition ne 'ACCEPT' ) {
		    my $variable = get_interface_addresses source_port_to_bridge( $interface );

		    if ( have_capability( 'ADDRTYPE' ) ) {
			add_commands( $chainref,
				      "for address in $variable; do",
				      "    echo \"-A -s \$address -m addrtype --dst-type BROADCAST -j RETURN\" >&3",
				      "    echo \"-A -s \$address -d 224.0.0.0/4 -j RETURN\" >&3",
				      'done' );
		    } else {
			my $bridge    = source_port_to_bridge( $interface );
			my $bridgeref = find_interface( $bridge );

			add_commands( $chainref,
				      "for address in $variable; do" );

			if ( $bridgeref->{broadcasts} ) {
			    for my $address ( @{$bridgeref->{broadcasts}}, '255.255.255.255' ) {
				add_commands( $chainref ,
					      "    echo \"-A -s \$address -d $address -j RETURN\" >&3" );
			    }
			} else {
			    my $variable1 = get_interface_bcasts $bridge;

			    add_commands( $chainref,
					  "    for address1 in $variable1; do" ,
					  "        echo \"-A -s \$address -d \$address1 -j RETURN\" >&3",
					  "    done" );
			}

			add_commands( $chainref
				      , "    echo \"-A -s \$address -d 224.0.0.0/4 -j RETURN\" >&3" ,
				      , 'done' );
		    }
		}
	    }

	    run_user_exit2( 'maclog', $chainref );

	    log_rule_limit $level, $chainref , $chain , $disposition, '', '', 'add', '' if $level ne '';
	    add_jump $chainref, $target, 0;
	}
    }
}

#
# Helper functions for generate_matrix()
#-----------------------------------------
#
# Return the target for rules from $zone to $zone1.
#
sub rules_target( $$ ) {
    my ( $zone, $zone1 ) = @_;
    my $chain = rules_chain( ${zone}, ${zone1} );
    my $chainref = $filter_table->{$chain};

    return $chain   if $chainref && $chainref->{referenced};
    return 'ACCEPT' if $zone eq $zone1;

    assert( $chainref );

    if ( $chainref->{policy} ne 'CONTINUE' ) {
	my $policyref = $filter_table->{$chainref->{policychain}};
	assert( $policyref );
	return $policyref->{name} if $policyref ne $chainref;
	return $chainref->{policy} eq 'REJECT' ? 'reject' : $chainref->{policy};
    }

    ''; # CONTINUE policy
}

#
# Generate rules for one destination zone
#
sub generate_dest_rules( $$$$ ) {
    my ( $chainref, $chain, $z2, $match ) = @_;

    my $z2ref            = find_zone( $z2 );
    my $type2            = $z2ref->{type};

    if ( $type2 == VSERVER ) {
	for my $hostref ( @{$z2ref->{hosts}{ip}{'%vserver%'}} ) {
	    my $exclusion = dest_exclusion( $hostref->{exclusions}, $chain);

	    for my $net ( @{$hostref->{hosts}} ) {
		add_jump( $chainref,
			  $exclusion ,
			  0,
			  join('', $match, match_dest_net( $net ) ) )
	    }
	}
    } else {
	add_jump( $chainref, $chain, 0, $match );
    }
}

#
# Generate rules for one vserver source zone
#
sub generate_source_rules( $$$$ ) {
    my ( $outchainref, $z1, $z2, $match ) = @_;
    my $chain = rules_target ( $z1, $z2 );

    if ( $chain ) {
	#
	# Not a CONTINUE policy with no rules
	#
	for my $hostref ( @{defined_zone( $z1 )->{hosts}{ip}{'%vserver%'}} ) {
	    my $ipsec_match = match_ipsec_in $z1 , $hostref;
	    my $exclusion   = source_exclusion( $hostref->{exclusions}, $chain);

	    for my $net ( @{$hostref->{hosts}} ) {
		generate_dest_rules( $outchainref,
				     $exclusion,
				     $z2,
				     join('', match_source_net( $net ), $match , $ipsec_match )
				   );
	    }
	}
    }
}

#
# Loopback traffic -- this is where we assemble the intra-firewall chains
#
sub handle_loopback_traffic() {
    my @zones   = ( vserver_zones, firewall_zone );
    my $natout  = $nat_table->{OUTPUT};
    my $rulenum = 0;

    my $outchainref;
    my $rule = '';

    if ( @zones > 1 ) {
	$outchainref = new_standard_chain 'loopback';
	add_jump $filter_table->{OUTPUT}, $outchainref, 0, '-o lo ';
    } else {
	$outchainref = $filter_table->{OUTPUT};
	$rule = '-o lo ';
    }

    for my $z1 ( @zones ) {
	my $z1ref            = find_zone( $z1 );
	my $type1            = $z1ref->{type};
	my $natref           = $nat_table->{dnat_chain $z1};

	if ( $type1 == FIREWALL ) {
	    for my $z2 ( @zones ) {
		my $chain = rules_target( $z1, $z2 );

		generate_dest_rules( $outchainref, $chain, $z2, $rule ) if $chain;
	    }
	} else {
	    for my $z2 ( @zones ) {
		generate_source_rules( $outchainref, $z1, $z2, $rule );
	    }
	}

	if ( $natref && $natref->{referenced} ) {
	    my $source_hosts_ref = defined_zone( $z1 )->{hosts};

	    for my $typeref ( values %{$source_hosts_ref} ) {
		for my $hostref ( @{$typeref->{'%vserver%'}} ) {
		    my $exclusion   = source_exclusion( $hostref->{exclusions}, $natref);

		    for my $net ( @{$hostref->{hosts}} ) {
			add_jump( $natout, $exclusion, 0, match_source_net( $net ), 0, $rulenum++ );
		    }
		}
	    }
	}
    }

    add_rule $filter_table->{INPUT}  , '-i lo -j ACCEPT';
}

#
# Add jumps from the builtin chains to the interface-chains that are used by this configuration
#
sub add_interface_jumps {
    our %input_jump_added;
    our %output_jump_added;
    our %forward_jump_added;
    #
    # Add Nat jumps
    #
    for my $interface ( @_ ) {
	addnatjump 'POSTROUTING' , snat_chain( $interface ), match_dest_dev( $interface );
    }

    addnatjump 'PREROUTING'  , 'nat_in'  , '';
    addnatjump 'POSTROUTING' , 'nat_out' , '';
    addnatjump 'PREROUTING', 'dnat', '';

    for my $interface ( grep $_ ne '%vserver%', @_ ) {
	addnatjump 'PREROUTING'  , input_chain( $interface )  , match_source_dev( $interface );
	addnatjump 'POSTROUTING' , output_chain( $interface ) , match_dest_dev( $interface );
	addnatjump 'POSTROUTING' , masq_chain( $interface ) , match_dest_dev( $interface );
    }
    #
    # Add the jumps to the interface chains from filter FORWARD, INPUT, OUTPUT
    #
    for my $interface ( grep $_ ne '%vserver%', @_ ) {
	my $forwardref   = $filter_table->{forward_chain $interface};
	my $inputref     = $filter_table->{input_chain $interface};
	my $outputref    = $filter_table->{output_chain $interface};
	my $interfaceref = find_interface($interface);

	if ( $interfaceref->{options}{port} ) {
	    my $bridge = $interfaceref->{bridge};
	    add_rule ( $filter_table->{forward_chain $bridge},
		       match_source_dev( $interface, 1) . match_dest_dev( $interface, 1) . '-j ACCEPT'
		     ) unless $interfaceref->{nets} || ! $interfaceref->{options}{bridge};

	    add_jump( $filter_table->{forward_chain $bridge} ,
		      $forwardref , 
		      0, 
		      match_source_dev( $interface, 1 )
		    ) unless $forward_jump_added{$interface} || ! use_forward_chain $interface, $forwardref;

	    add_jump( $filter_table->{input_chain $bridge },
		      $inputref ,
		      0,
		      match_source_dev( $interface, 1 )
		    ) unless $input_jump_added{$interface}   || ! use_input_chain $interface, $inputref;

	    unless ( $output_jump_added{$interface} || ! use_output_chain $interface, $outputref ) {
		add_jump( $filter_table->{output_chain $bridge} ,
			  $outputref ,
			  0 ,
			  match_dest_dev( $interface, 1 ) )
		    unless get_interface_option( $interface, 'port' );
	    }
	} else {
	    add_rule ( $filter_table->{FORWAR}, match_source_dev( $interface) . match_dest_dev( $interface) . '-j ACCEPT' ) unless $interfaceref->{nets} || ! $interfaceref->{options}{bridge};

	    add_jump( $filter_table->{FORWARD} , $forwardref , 0, match_source_dev( $interface ) ) unless $forward_jump_added{$interface} || ! use_forward_chain $interface, $forwardref;
	    add_jump( $filter_table->{INPUT}   , $inputref ,   0, match_source_dev( $interface ) ) unless $input_jump_added{$interface}   || ! use_input_chain $interface, $inputref;

	    unless ( $output_jump_added{$interface} || ! use_output_chain $interface, $outputref ) {
		add_jump $filter_table->{OUTPUT} , $outputref , 0, match_dest_dev( $interface ) unless get_interface_option( $interface, 'port' );
	    }
	}
    }

    handle_loopback_traffic;
}

# Generate the rules matrix.
#
# Stealing a comment from the Burroughs B6700 MCP Operating System source, "generate_matrix makes a sow's ear out of a silk purse".
#
# The biggest disadvantage of the zone-policy-rule model used by Shorewall is that it doesn't scale well as the number of zones increases (Order N**2 where N = number of zones).
# A major goal of the rewrite of the compiler in Perl was to restrict those scaling effects to this function and the rules that it generates.
#
# The function traverses the full "source-zone by destination-zone" matrix and generates the rules necessary to direct traffic through the right set of filter-table and 
# nat-table rules.
#
sub generate_matrix() {
    my @interfaces = ( all_interfaces );
    #
    # Should this be the real PREROUTING chain?
    #
    my $preroutingref = ensure_chain 'nat', 'dnat';

    my $fw       = firewall_zone;
    my @zones    = off_firewall_zones;
    my @vservers = vserver_zones;
    
    my $notrackref = $raw_table->{notrack_chain $fw};
    my $state = $config{BLACKLISTNEWONLY} ? $globals{UNTRACKED} ? "-m state --state NEW,INVALID,UNTRACKED " : "$globals{STATEMATCH} NEW,INVALID " : '';
    my $interface_jumps_added = 0;

    our %input_jump_added   = ();
    our %output_jump_added  = ();
    our %forward_jump_added = ();
    my  %ipsec_jump_added   = ();

    progress_message2 'Generating Rule Matrix...';
    progress_message  '  Handling blacklisting and complex zones...';
    #
    # Special processing for complex and/or blacklisting configurations
    #
    for my $zone ( @zones ) {
	my $zoneref = find_zone( $zone );
	my $simple  =  @zones <= 2 && ! $zoneref->{options}{complex};
	#
	# Handle blacklisting first
	#
	if ( $zoneref->{options}{in}{blacklist} ) {
	    my $blackref = $filter_table->{blacklst};
	    add_jump ensure_rules_chain( rules_chain( $zone, $_ ) ) , $blackref , 0, $state, 0, -1 for firewall_zone, @vservers;

	    if ( $simple ) {
		#
		# We won't create a zone forwarding chain for this zone so we must add blacklisting jumps to the rules chains
		#
		for my $zone1 ( @zones ) {
		    my $ruleschain    = rules_chain( $zone, $zone1 );
		    my $ruleschainref = $filter_table->{$ruleschain};

		    if ( ( $zone ne $zone1 || $ruleschainref->{referenced} ) && $ruleschainref->{policy} ne 'NONE' ) {
			add_jump( ensure_rules_chain( $ruleschain ), $blackref, 0, $state, 0, -1 );
		    }
		}
	    }
	}

	if ( $zoneref->{options}{out}{blacklist} ) {
	    my $blackref = $filter_table->{blackout};
	    add_jump ensure_rules_chain( rules_chain( firewall_zone, $zone ) ) , $blackref , 0, $state, 0, -1;

	    for my $zone1 ( @zones, @vservers ) {
		my $ruleschain    = rules_chain( $zone1, $zone );
		my $ruleschainref = $filter_table->{$ruleschain};

		if ( ( $zone ne $zone1 || $ruleschainref->{referenced} ) && $ruleschainref->{policy} ne 'NONE' ) {
		    add_jump( ensure_rules_chain( $ruleschain ), $blackref, 0, $state, 0, -1 );
		}
	    }
	}

	next if $simple;

	#
	# Complex zone or we have more than one non-firewall zone -- create a zone forwarding chain
	#
	my $frwd_ref = new_standard_chain zone_forward_chain( $zone );

	add_jump $frwd_ref , $filter_table->{blacklst}, 0, $state, 0, -1 if $zoneref->{options}{in}{blacklist};

	if ( have_ipsec ) {
	    #
	    # Because policy match only matches an 'in' or an 'out' policy (but not both), we have to place the
	    # '--pol ipsec --dir in' rules at the front of the (interface) forwarding chains. Otherwise, decrypted packets
	    # can match '--pol none --dir out' rules and send the packets down the wrong rules chain.
	    #
	    my $type       = $zoneref->{type};
	    my $source_ref = ( $zoneref->{hosts}{ipsec} ) || {};

	    for my $interface ( sort { interface_number( $a ) <=> interface_number( $b ) } keys %$source_ref ) {
		my $sourcechainref = $filter_table->{forward_chain $interface};
		my $interfacematch = '';
		my $interfaceref = find_interface $interface;

		if ( use_forward_chain( $interface, $sourcechainref ) ) {
		    if ( $interfaceref->{ports} && $interfaceref->{options}{bridge} ) {
			$interfacematch = match_source_dev $interface;
			copy_rules( $sourcechainref, $frwd_ref, 1 ) unless $ipsec_jump_added{$zone}++;
			$sourcechainref = $filter_table->{FORWARD};
		    } elsif ( $interfaceref->{options}{port} ) {
			add_jump( $filter_table->{ forward_chain $interfaceref->{bridge} } ,
				  $sourcechainref ,
				  0 ,
				  match_source_dev( $interface , 1 ) )
			    unless $forward_jump_added{$interface}++;
		    } else {
			add_jump $filter_table->{FORWARD} , $sourcechainref, 0 , match_source_dev( $interface ) unless $forward_jump_added{$interface}++;
		    }
		} else {
		    if ( $interfaceref->{options}{port} ) {
			$sourcechainref = $filter_table->{ forward_chain $interfaceref->{bridge} };
			$interfacematch = match_source_dev $interface, 1;
		    } else {
			$sourcechainref = $filter_table->{FORWARD};
			$interfacematch = match_source_dev $interface;
		    }

		    move_rules( $filter_table->{forward_chain $interface} , $frwd_ref );
		}

		my $arrayref = $source_ref->{$interface};

		for my $hostref ( @{$arrayref} ) {
		    my $ipsec_match = match_ipsec_in $zone , $hostref;
		    for my $net ( @{$hostref->{hosts}} ) {
			add_jump(
				 $sourcechainref,
				 source_exclusion( $hostref->{exclusions}, $frwd_ref ),
				 ! @{$zoneref->{parents}},
				 join( '', $interfacematch , match_source_net( $net ), $ipsec_match )
				);
		    }
		}
	    }
	}
    }

    #
    # NOTRACK from firewall
    #
    add_jump $raw_table->{OUTPUT}, $notrackref, 0 if $notrackref->{referenced};
    #
    # Main source-zone matrix-generation loop
    #
    progress_message '  Entering main matrix-generation loop...';

    for my $zone ( @zones ) {
	my $zoneref          = find_zone( $zone );
	my $source_hosts_ref = $zoneref->{hosts};
	my $chain1           = rules_target firewall_zone , $zone;
	my $chain2           = rules_target $zone, firewall_zone;
	my $complex          = $zoneref->{options}{complex} || 0;
	my $type             = $zoneref->{type};
	my $frwd_ref         = $filter_table->{zone_forward_chain $zone};
	my $chain            = 0;
	my $dnatref          = ensure_chain 'nat' , dnat_chain( $zone );
	my $notrackref       = ensure_chain 'raw' , notrack_chain( $zone );
	my $nested           = $zoneref->{options}{nested};
	my $parenthasnat     = 0;
	my $parenthasnotrack = 0;

	if ( $nested ) {
	    #
	    # This is a sub-zone. We need to determine if
	    #
	    #   a) A parent zone defines DNAT/REDIRECT or notrack rules; and
	    #   b) The current zone has a CONTINUE policy to some other zone.
	    #
	    # If a) but not b), then we must avoid sending packets from this
	    # zone through the DNAT/REDIRECT or notrack chain for the parent.
	    #
	    for my $parent ( @{$zoneref->{parents}} ) {
		my $ref1 = $nat_table->{dnat_chain $parent} || {};
		my $ref2 = $raw_table->{notrack_chain $parent} || {};
		$parenthasnat     = 1 if $ref1->{referenced};
		$parenthasnotrack = 1 if $ref2->{referenced};
		last if $parenthasnat && $parenthasnotrack;
	    }

	    if ( $parenthasnat || $parenthasnotrack ) {
		for my $zone1 ( all_zones ) {
		    if ( $filter_table->{rules_chain( ${zone}, ${zone1} )}->{policy} eq 'CONTINUE' ) {
			#
			# This zone has a continue policy to another zone. We must
			# send packets from this zone through the parent's DNAT/REDIRECT/NOTRACK chain.
			#
			$nested = 0;
			last;
		    }
		}
	    } else {
		#
		# No parent has DNAT or notrack so there is nothing to worry about. Don't bother to generate needless RETURN rules in the 'dnat' or 'notrack' chain.
		#
		$nested = 0;
	    }
	}
	#
	# Take care of PREROUTING, INPUT and OUTPUT jumps
	#
	for my $typeref ( values %$source_hosts_ref ) {
	    for my $interface ( sort { interface_number( $a ) <=> interface_number( $b ) } keys %$typeref ) {
		my $arrayref = $typeref->{$interface};
		my $interfaceref = find_interface $interface;
		my $isport = $interfaceref->{options}{port};
		my $bridge = $interfaceref->{bridge};

		if ( get_physical( $interface ) eq '+' ) {
		    #
		    # Insert the interface-specific jumps before this one which is not interface-specific
		    #
		    add_interface_jumps(@interfaces) unless $interface_jumps_added++;
		}

		for my $hostref ( @$arrayref ) {
		    my $ipsec_in_match  = match_ipsec_in  $zone , $hostref;
		    my $ipsec_out_match = match_ipsec_out $zone , $hostref;
		    my $exclusions = $hostref->{exclusions};

		    for my $net ( @{$hostref->{hosts}} ) {
			my $dest   = match_dest_net $net;

			if ( $chain1 && zone_type ( $zone) != BPORT ) {
			    my $chain1ref = $filter_table->{$chain1};
			    my $nextchain = dest_exclusion( $exclusions, $chain1 );
			    my $outputref;
			    my $interfacechainref = $filter_table->{output_chain $interface};
			    my $interfacematch = '';
			    my $use_output = 0;

			    if ( @vservers || use_output_chain( $interface, $interfacechainref ) || ( @{$interfacechainref->{rules}} && ! $chain1ref ) ) {
				$outputref = $interfacechainref;

				if ( $isport ) {
				    add_jump( $filter_table->{ output_chain $bridge },
					      $outputref ,
					      0 ,
					      match_dest_dev( $interface, 1 ) )
					unless $output_jump_added{$interface}++;
				} else {
				    add_jump $filter_table->{OUTPUT}, $outputref, 0, match_dest_dev( $interface ) unless $output_jump_added{$interface}++;
				}

				$use_output = 1;

				unless ( lc $net eq IPv6_LINKLOCAL ) {
				    for my $vzone ( vserver_zones ) {
					generate_source_rules ( $outputref, $vzone, $zone, $dest );
				    }
				}
			    } elsif ( $isport ) {
				$outputref = $filter_table->{ output_chain $bridge };
				$interfacematch = match_dest_dev $interface, 1;
			    } else {
				$outputref = $filter_table->{OUTPUT};
				$interfacematch = match_dest_dev $interface;
			    }

			    add_jump $outputref , $nextchain, 0, join( '', $interfacematch, $dest, $ipsec_out_match );

			    add_jump( $outputref , $nextchain, 0, join('', $interfacematch, '-d 255.255.255.255 ' , $ipsec_out_match ) )
				if $family == F_IPV4 && $hostref->{options}{broadcast};

			    move_rules( $interfacechainref , $chain1ref ) unless $use_output;
			}

			clearrule;

			next if $hostref->{options}{destonly};

			my $source = match_source_net $net;

			if ( $dnatref->{referenced} ) {
			    #
			    # There are DNAT/REDIRECT rules with this zone as the source.
			    # Add a jump from this source network to this zone's DNAT/REDIRECT chain
			    #
			    add_jump( $preroutingref,
				      source_exclusion( $exclusions, $dnatref),
				      0,
				      join( '', match_source_dev( $interface), $source, $ipsec_in_match ) );
				      
			    if ( get_physical( $interface ) eq '+' ) {
				#
				# The jump from the PREROUTING chain to dnat may not have been added above
				# 
				addnatjump 'PREROUTING', 'dnat', '' unless $preroutingref->{references}{PREROUTING};
			    }
				
			    check_optimization( $dnatref ) if $source;
			}

			if ( $notrackref->{referenced} ) {
			    #
			    # There are notrack rules with this zone as the source.
			    # Add a jump from this source network to this zone's notrack chain
			    #
			    add_jump $raw_table->{PREROUTING}, source_exclusion( $exclusions, $notrackref), 0, join( '', match_source_dev( $interface), $source, $ipsec_in_match );
			}

			#
			# If this zone has parents with DNAT/REDIRECT or notrack rules and there are no CONTINUE polcies with this zone as the source
			# then add a RETURN jump for this source network.
			#
			if ( $nested ) {
			    add_rule $preroutingref, join( '', match_source_dev( $interface), $source, $ipsec_in_match, '-j RETURN' )           if $parenthasnat;
			    add_rule $raw_table->{PREROUTING}, join( '', match_source_dev( $interface), $source, $ipsec_in_match, '-j RETURN' ) if $parenthasnotrack;
			}

			my $chain2ref = $filter_table->{$chain2};
			my $inputchainref;
			my $interfacechainref = $filter_table->{input_chain $interface};
			my $interfacematch = '';
			my $use_input;
			my $blacklist = $zoneref->{options}{in}{blacklist};

			if ( @vservers || use_input_chain( $interface, $interfacechainref ) || ! $chain2 || ( @{$interfacechainref->{rules}} && ! $chain2ref ) ) {
			    $inputchainref = $interfacechainref;
			    
			    if ( $isport ) {
				add_jump( $filter_table->{ input_chain $bridge },
					  $inputchainref ,
					  0 ,
					  match_source_dev($interface, 1) )
				    unless $input_jump_added{$interface}++;
			    } else {
				add_jump $filter_table->{INPUT}, $inputchainref, 0, match_source_dev($interface) unless $input_jump_added{$interface}++;
			    }

			    $use_input = 1;

			    unless ( lc $net eq IPv6_LINKLOCAL ) {
				for my $vzone ( @vservers ) {
				    my $target = rules_target( $zone, $vzone );
				    generate_dest_rules( $inputchainref, $target, $vzone, $source . $ipsec_in_match ) if $target;
				}
			    }
			} elsif ( $isport ) {
			    $inputchainref = $filter_table->{ input_chain $bridge };
			    $interfacematch = match_source_dev $interface, 1;
			} else {
			    $inputchainref = $filter_table->{INPUT};
			    $interfacematch = match_source_dev $interface;
			}

			if ( $chain2 ) {
			    add_jump $inputchainref, source_exclusion( $exclusions, $chain2 ), 0, join( '', $interfacematch, $source, $ipsec_in_match );
			    move_rules( $interfacechainref , $chain2ref ) unless $use_input;
			}

			if ( $frwd_ref && $hostref->{ipsec} ne 'ipsec' ) {
			    my $ref = source_exclusion( $exclusions, $frwd_ref );
			    my $forwardref = $filter_table->{forward_chain $interface};

			    if ( use_forward_chain $interface, $forwardref ) {
				add_jump $forwardref , $ref, 0, join( '', $source, $ipsec_in_match );
				
				if ( $isport ) {
				    add_jump( $filter_table->{ forward_chain $bridge } ,
					      $forwardref ,
					      0 ,
					      match_source_dev( $interface , 1 ) )
					unless $forward_jump_added{$interface}++;
				} else {
				    add_jump $filter_table->{FORWARD} , $forwardref, 0 , match_source_dev( $interface ) unless $forward_jump_added{$interface}++;
				}
			    } else {
				if ( $isport ) {
				    add_jump( $filter_table->{ forward_chain $bridge } ,
					      $ref ,
					      0 ,
					      join( '', match_source_dev( $interface, 1 ) , $source, $ipsec_in_match ) );
				} else {
				    add_jump $filter_table->{FORWARD} , $ref, 0, join( '', match_source_dev( $interface ) , $source, $ipsec_in_match );
				}

				move_rules ( $forwardref , $frwd_ref );
			    }
			}
		    }
		}
	    }
	}

	#
	#                           F O R W A R D I N G
	#
	my @dest_zones;
	my $last_chain = '';

	if ( $config{OPTIMIZE} & 1 ) {
	    my @temp_zones;

	    for my $zone1 ( @zones )  {
		my $zone1ref = find_zone( $zone1 );
		my $policy = $filter_table->{rules_chain( ${zone}, ${zone1} )}->{policy};

		next if $policy eq 'NONE';

		my $chain = rules_target $zone, $zone1;

		next unless $chain;

		if ( $zone eq $zone1 ) {
		    next if ( scalar ( keys( %{ $zoneref->{interfaces}} ) ) < 2 ) && ! $zoneref->{options}{in_out}{routeback};
		}

		if ( $zone1ref->{type} == BPORT ) {
		    next unless $zoneref->{bridge} eq $zone1ref->{bridge};
		}

		if ( $chain =~ /(2all|-all)$/ ) {
		    if ( $chain ne $last_chain ) {
			$last_chain = $chain;
			push @dest_zones, @temp_zones;
			@temp_zones = ( $zone1 );
		    } elsif ( $policy eq 'ACCEPT' ) {
			push @temp_zones , $zone1;
		    } else {
			$last_chain = $chain;
			@temp_zones = ( $zone1 );
		    }
		} else {
		    push @dest_zones, @temp_zones, $zone1;
		    @temp_zones = ();
		    $last_chain = '';
		}
	    }

	    if ( $last_chain && @temp_zones == 1 ) {
		push @dest_zones, @temp_zones;
		$last_chain = '';
	    }
	} else {
	    @dest_zones =  @zones ;
	}
	#
	# Here it is -- THE BIG UGLY!!!!!!!!!!!!
	#
	# We now loop through the destination zones creating jumps to the rules chain for each source/dest combination.
	# @dest_zones is the list of destination zones that we need to handle from this source zone
	#
	for my $zone1 ( @dest_zones ) {
	    my $zone1ref = find_zone( $zone1 );

	    next if $filter_table->{rules_chain( ${zone}, ${zone1} )}->{policy}  eq 'NONE';

	    my $chain = rules_target $zone, $zone1;

	    next unless $chain; # CONTINUE policy with no rules

	    my $num_ifaces = 0;

	    if ( $zone eq $zone1 ) {
		next if ( $num_ifaces = scalar( keys ( %{$zoneref->{interfaces}} ) ) ) < 2 && ! $zoneref->{options}{in_out}{routeback};
	    }

	    if ( $zone1ref->{type} == BPORT ) {
		next unless $zoneref->{bridge} eq $zone1ref->{bridge};
	    }

	    my $chainref = $filter_table->{$chain}; #Will be null if $chain is a Netfilter Built-in target like ACCEPT

	    if ( $frwd_ref ) {
		#
		# Simple case -- the source zone has it's own forwarding chain
		#
		for my $typeref ( values %{$zone1ref->{hosts}} ) {
		    for my $interface ( sort { interface_number( $a ) <=> interface_number( $b ) } keys %$typeref ) {
			for my $hostref ( @{$typeref->{$interface}} ) {
			    next if $hostref->{options}{sourceonly};
			    if ( $zone ne $zone1 || $num_ifaces > 1 || $hostref->{options}{routeback} ) {
				my $ipsec_out_match = match_ipsec_out $zone1 , $hostref;
				my $dest_exclusion = dest_exclusion( $hostref->{exclusions}, $chain);
				for my $net ( @{$hostref->{hosts}} ) {
				    add_jump $frwd_ref, $dest_exclusion, 0, join( '', match_dest_dev( $interface) , match_dest_net($net), $ipsec_out_match );
				}
			    }
			}
		    }
		}
	    } else {
		#
		# More compilcated case. If the interface is associated with a single simple zone, we try to combine the interface's forwarding chain with the rules chain
		#
		for my $typeref ( values %$source_hosts_ref ) {
		    for my $interface ( keys %$typeref ) {
			my $interfaceref = find_interface $interface;
			my $chain3ref;
			my $match_source_dev = '';
			my $forwardchainref = $filter_table->{forward_chain $interface};

			if ( use_forward_chain( $interface , $forwardchainref ) || ( @{$forwardchainref->{rules} } && ! $chainref ) ) {
			    #
			    # Either we must use the interface's forwarding chain or that chain has rules and we have nowhere to move them
			    #
			    $chain3ref = $forwardchainref;
			    
			    if ( $interfaceref->{options}{port} ) {
				add_jump( $filter_table->{ forward_chain $interfaceref->{bridge} } ,
					  $chain3ref,
					  0 ,
					  match_source_dev( $interface , 1 ) )
				    unless $forward_jump_added{$interface}++;
			    } else {
				add_jump $filter_table->{FORWARD} , $chain3ref, 0 , match_source_dev( $interface ) unless $forward_jump_added{$interface}++;
			    }
			} else {
			    #
			    # Don't use the interface's forward chain -- move any rules in that chain to this rules chain
			    #
			    if ( $interfaceref->{options}{port} ) {
				$chain3ref  = $filter_table->{ forward_chain $interfaceref->{bridge} };
				$match_source_dev = match_source_dev $interface, 1;
			    } else {
				$chain3ref  = $filter_table->{FORWARD};
				$match_source_dev = match_source_dev $interface;
			    }

			    move_rules $forwardchainref, $chainref;
			}

			for my $hostref ( @{$typeref->{$interface}} ) {
			    next if $hostref->{options}{destonly};
			    my $excl3ref = source_exclusion( $hostref->{exclusions}, $chain3ref );
			    for my $net ( @{$hostref->{hosts}} ) {
				for my $type1ref ( values %{$zone1ref->{hosts}} ) {
				    for my $interface1 ( keys %$type1ref ) {
					my $array1ref = $type1ref->{$interface1};
					for my $host1ref ( @$array1ref ) {
					    next if $host1ref->{options}{sourceonly};
					    my $ipsec_out_match = match_ipsec_out $zone1 , $host1ref;
					    my $dest_exclusion  = dest_exclusion( $host1ref->{exclusions}, $chain );
					    for my $net1 ( @{$host1ref->{hosts}} ) {
						unless ( $interface eq $interface1 && $net eq $net1 && ! $host1ref->{options}{routeback} ) {
						    #
						    # We defer evaluation of the source net match to accomodate systems without $capabilities{KLUDEFREE};
						    #
						    add_jump(
							     $excl3ref ,
							     $dest_exclusion,
							     0,
							     join( '',
								   $match_source_dev,
								   match_dest_dev($interface1),
								   match_source_net($net),
								   match_dest_net($net1),
								   $ipsec_out_match )
							    );
						}
					    }
					}
				    }
				}
			    }
			}
		    }
		}
	    }
	}
	#
	#                                      E N D   F O R W A R D I N G
	#
	# Now add an unconditional jump to the last unique policy-only chain determined above, if any
	#
	add_jump $frwd_ref , $last_chain, 1 if $frwd_ref && $last_chain;
    }

    progress_message '  Finishing matrix...';

    add_interface_jumps @interfaces unless $interface_jumps_added;

    promote_blacklist_rules;

    my %builtins = ( mangle => [ qw/PREROUTING INPUT FORWARD POSTROUTING/ ] ,
		     nat=>     [ qw/PREROUTING OUTPUT POSTROUTING/ ] ,
		     filter=>  [ qw/INPUT FORWARD OUTPUT/ ] );

    unless ( $config{COMPLETE} ) {
	complete_standard_chain $filter_table->{INPUT}   , 'all' , firewall_zone , 'DROP';
	complete_standard_chain $filter_table->{OUTPUT}  , firewall_zone , 'all', 'REJECT';
	complete_standard_chain $filter_table->{FORWARD} , 'all' , 'all', 'REJECT';
    }

    if ( $config{LOGALLNEW} ) {
	for my $table qw/mangle nat filter/ {
	    for my $chain ( @{$builtins{$table}} ) {
		log_rule_limit
		    $config{LOGALLNEW} ,
		    $chain_table{$table}{$chain} ,
		    $table ,
		    $chain ,
		    '' ,
		    '' ,
		    'insert' ,
		    "$globals{STATEMATCH} NEW ";
	    }
	}
    }
}

sub setup_mss( ) {
    my $clampmss = $config{CLAMPMSS};
    my $option;
    my $match = '';
    my $chainref = $filter_table->{FORWARD};

    if ( $clampmss ) {
	if ( "\L$clampmss" eq 'yes' ) {
	    $option = '--clamp-mss-to-pmtu';
	} else {
	    $match  = "-m tcpmss --mss $clampmss: " if have_capability( 'TCPMSS_MATCH' );
	    $option = "--set-mss $clampmss";
	}

	$match .= '-m policy --pol none --dir out ' if have_ipsec;
    }

    my $interfaces = find_interfaces_by_option( 'mss' );

    if ( @$interfaces ) {
	#
	# Since we will need multiple rules, we create a separate chain
	#
	$chainref = new_chain 'filter', 'settcpmss';
	#
	# Send all forwarded SYN packets to the 'settcpmss' chain
	#
	add_jump $filter_table->{FORWARD} , $chainref, 0, '-p tcp --tcp-flags SYN,RST SYN ';

	my $in_match  = '';
	my $out_match = '';

	if ( have_ipsec ) {
	    $in_match  = '-m policy --pol none --dir in ';
	    $out_match = '-m policy --pol none --dir out ';
	}

	for ( @$interfaces ) {
	    my $mss      = get_interface_option( $_, 'mss' );
	    my $mssmatch = have_capability( 'TCPMSS_MATCH' ) ? "-m tcpmss --mss $mss: " : '';
	    my $source   = match_source_dev $_;
	    my $dest     = match_dest_dev $_;
	    add_rule $chainref, "${dest}-p tcp --tcp-flags SYN,RST SYN ${mssmatch}${out_match}-j TCPMSS --set-mss $mss";
	    add_rule $chainref, "${dest}-j RETURN" if $clampmss;
	    add_rule $chainref, "${source}-p tcp --tcp-flags SYN,RST SYN ${mssmatch}${in_match}-j TCPMSS --set-mss $mss";
	    add_rule $chainref, "${source}-j RETURN" if $clampmss;
	}
    }

    add_rule $chainref , "-p tcp --tcp-flags SYN,RST SYN ${match}-j TCPMSS $option" if $clampmss;
}

#
# Compile the stop_firewall() function
#
sub compile_stop_firewall( $$ ) {
    my ( $test, $export ) = @_;

    my $input   = $filter_table->{INPUT};
    my $output  = $filter_table->{OUTPUT};
    my $forward = $filter_table->{FORWARD};

    emit <<'EOF';
#
# Stop/restore the firewall after an error or because of a 'stop' or 'clear' command
#
stop_firewall() {
    local hack
EOF

    $output->{policy} = 'ACCEPT' if $config{ADMINISABSENTMINDED};

    if ( $family == F_IPV4 ) {
	emit <<'EOF';
    deletechain() {
        qt $IPTABLES -L $1 -n && qt $IPTABLES -F $1 && qt $IPTABLES -X $1
    }

    case $COMMAND in
        stop|clear|restore)
            if chain_exists dynamic; then
                ${IPTABLES}-save -t filter | grep '^-A dynamic' > ${VARDIR}/.dynamic
            fi
            ;;
        *)
            set +x
EOF
    } else {
	emit <<'EOF';
    deletechain() {
        qt $IPTABLES -L $1 -n && qt $IPTABLES -F $1 && qt $IPTABLES -X $1
    }

    case $COMMAND in
        stop|clear|restore)
            if chain_exists dynamic; then
                ${IP6TABLES}-save -t filter | grep '^-A dynamic' > ${VARDIR}/.dynamic
            fi
            ;;
        *)
            set +x
EOF
    }

    emit <<'EOF';
            case $COMMAND in
	        start)
	            logger -p kern.err "ERROR:$g_product start failed"
	            ;;
	        restart)
	            logger -p kern.err "ERROR:$g_product restart failed"
	            ;;
	        refresh)
	            logger -p kern.err "ERROR:$g_product refresh failed"
	            ;;
            esac

            if [ "$RESTOREFILE" = NONE ]; then
                COMMAND=clear
                clear_firewall
                echo "$g_product Cleared"

	        kill $$
	        exit 2
            else
	        g_restorepath=${VARDIR}/$RESTOREFILE

	        if [ -x $g_restorepath ]; then
		    echo Restoring ${g_product:=Shorewall}...

                    g_recovering=Yes

		    if run_it $g_restorepath restore; then
		        echo "$g_product restored from $g_restorepath"
		        set_state "Restored from $g_restorepath"
		    else
		        set_state "Unknown"
		    fi

	            kill $$
	            exit 2
	        fi
            fi
	    ;;
    esac

    if [ -n "$g_stopping" ]; then
        kill $$
        exit 1
    fi

    set_state "Stopping"

    g_stopping="Yes"

    deletechain shorewall

    run_stop_exit
EOF

    if ( have_capability( 'NAT_ENABLED' ) ) {
	emit<<'EOF';
    if [ -f ${VARDIR}/nat ]; then
        while read external interface; do
      	    del_ip_addr $external $interface
	done < ${VARDIR}/nat

	rm -f ${VARDIR}/nat
    fi
EOF
    }

    if ( $family == F_IPV4 ) {
	emit <<'EOF';
    if [ -f ${VARDIR}/proxyarp ]; then
	while read address interface external haveroute; do
	    qt $IP -4 neigh del proxy $address dev $external
	    [ -z "${haveroute}${g_noroutes}" ] && qt $IP -4 route del $address/32 dev $interface
	    f=/proc/sys/net/ipv4/conf/$interface/proxy_arp
	    [ -f $f ] && echo 0 > $f
	done < ${VARDIR}/proxyarp

        rm -f ${VARDIR}/proxyarp
    fi

EOF
    } else {
	emit <<'EOF';
    if [ -f ${VARDIR}/proxyndp ]; then
	while read address interface external haveroute; do
	    qt $IP -6 neigh del proxy $address dev $external
	    [ -z "${haveroute}${g_noroutes}" ] && qt $IP -6 route del $address/128 dev $interface
	    f=/proc/sys/net/ipv4/conf/$interface/proxy_ndp
	    [ -f $f ] && echo 0 > $f
	done < ${VARDIR}/proxyndp

        rm -f ${VARDIR}/proxyndp
    fi

EOF
    }

    push_indent;

    emit 'delete_tc1' if $config{CLEAR_TC};

    emit( 'undo_routing',
	  'restore_default_route'
	  );

    my @chains = $config{ADMINISABSENTMINDED} ? qw/INPUT FORWARD/ : qw/INPUT OUTPUT FORWARD/;

    add_rule $filter_table->{$_}, "$globals{STATEMATCH} ESTABLISHED,RELATED -j ACCEPT" for @chains;

    if ( $family == F_IPV6 ) {
	add_rule $input, '-s ' . IPv6_LINKLOCAL . ' -j ACCEPT';
	add_rule $input, '-d ' . IPv6_LINKLOCAL . ' -j ACCEPT';
	add_rule $input, '-d ' . IPv6_MULTICAST . ' -j ACCEPT';

	unless ( $config{ADMINISABSENTMINDED} ) {
	    add_rule $output, '-d ' . IPv6_LINKLOCAL . ' -j ACCEPT';
	    add_rule $output, '-d ' . IPv6_MULTICAST . ' -j ACCEPT';
	}
    }

    process_routestopped;

    add_rule $input, '-i lo -j ACCEPT';
    add_rule $input, '-i lo -j ACCEPT';

    add_rule $output, '-o lo -j ACCEPT' unless $config{ADMINISABSENTMINDED};

    my $interfaces = find_interfaces_by_option 'dhcp';

    if ( @$interfaces ) {
	my $ports = $family == F_IPV4 ? '67:68' : '546:547';

	for my $interface ( @$interfaces ) {
	    add_rule $input,  "-p udp " . match_source_dev( $interface ) . "--dport $ports -j ACCEPT";
	    add_rule $output, "-p udp " . match_dest_dev( $interface )   . "--dport $ports -j ACCEPT" unless $config{ADMINISABSENTMINDED};
	    #
	    # This might be a bridge
	    #
	    add_rule $forward, "-p udp " . match_source_dev( $interface ) . match_dest_dev( $interface ) . "--dport $ports -j ACCEPT";
	}
    }

    emit '';

    create_stop_load $test;

    if ( $family == F_IPV4 ) {
	if ( $config{IP_FORWARDING} eq 'on' ) {
	    emit( 'echo 1 > /proc/sys/net/ipv4/ip_forward',
		  'progress_message2 IPv4 Forwarding Enabled' );
	} elsif ( $config{IP_FORWARDING} eq 'off' ) {
	    emit( 'echo 0 > /proc/sys/net/ipv4/ip_forward',
		  'progress_message2 IPv4 Forwarding Disabled!'
		);
	}
    } else {
	for my $interface ( all_bridges ) {
	    emit "do_iptables -A FORWARD -p 58 " . match_source_dev( $interface ) . match_dest_dev( $interface ) . "-j ACCEPT";
	}

	if ( $config{IP_FORWARDING} eq 'on' ) {
	    emit( 'echo 1 > /proc/sys/net/ipv6/conf/all/forwarding',
		  'progress_message2 IPv6 Forwarding Enabled' );
	} elsif ( $config{IP_FORWARDING} eq 'off' ) {
	    emit( 'echo 0 > /proc/sys/net/ipv6/conf/all/forwarding',
		  'progress_message2 IPv6 Forwarding Disabled!'
		);
	}
    }

    pop_indent;

    emit '
    run_stopped_exit';

    my @ipsets = all_ipsets;

    if ( @ipsets || ( $config{SAVE_IPSETS} && have_ipset_rules ) ) {
	emit <<'EOF';

    case $IPSET in
        */*)
            if [ ! -x "$IPSET" ]; then
                error_message "ERROR: IPSET=$IPSET does not exist or is not executable - ipsets are not saved"
                IPSET=
            fi
	    ;;
	*)
	    IPSET="$(mywhich $IPSET)"
	    [ -n "$IPSET" ] || error_message "ERROR: The ipset utility cannot be located - ipsets are not saved"
	    ;;
    esac

    if [ -n "$IPSET" ]; then
        if [ -f /etc/debian_version ] && [ $(cat /etc/debian_version) = 5.0.3 ]; then
            #
            # The 'grep -v' is a hack for a bug in ipset's nethash implementation when xtables-addons is applied to Lenny
            #
            hack='| grep -v /31'
        else
            hack=
        fi

        if eval $IPSET -S $hack > ${VARDIR}/ipsets.tmp; then
            #
            # Don't save an 'empty' file
            #
            grep -q '^-N' ${VARDIR}/ipsets.tmp && mv -f ${VARDIR}/ipsets.tmp ${VARDIR}/ipsets.save
        fi
    fi
EOF
    }

    emit '

    set_state "Stopped"
    logger -p kern.info "$g_product Stopped"

    case $COMMAND in
    stop|clear)
	;;
    *)
	#
	# The firewall is being stopped when we were trying to do something
	# else. Kill the shell in case we\'re running in a subshell
	#
	kill $$
	;;
    esac
}
';

}

1;
