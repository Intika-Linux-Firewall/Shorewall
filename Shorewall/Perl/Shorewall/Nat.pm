#
# Shorewall 4.4 -- /usr/share/shorewall/Shorewall/Nat.pm
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
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#       GNU General Public License for more details.
#
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#   This module contains code for dealing with the /etc/shorewall/masq,
#   /etc/shorewall/nat and /etc/shorewall/netmap files.
#
package Shorewall::Nat;
require Exporter;
use Shorewall::Config qw(:DEFAULT :internal);
use Shorewall::IPAddrs;
use Shorewall::Zones;
use Shorewall::Chains qw(:DEFAULT :internal);
use Shorewall::Providers qw( lookup_provider );

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( setup_masq setup_nat setup_netmap add_addresses );
our @EXPORT_OK = ();
our $VERSION = '4.4_6';

our @addresses_to_add;
our %addresses_to_add;

#
# Called by the compiler
#
sub initialize() {
    @addresses_to_add = ();
    %addresses_to_add = ();
}

#
# Handle IPSEC Options in a masq record
#
sub do_ipsec_options($)
{
    my %validoptions = ( strict       => NOTHING,
			 next         => NOTHING,
			 reqid        => NUMERIC,
			 spi          => NUMERIC,
			 proto        => IPSECPROTO,
			 mode         => IPSECMODE,
			 "tunnel-src" => NETWORK,
			 "tunnel-dst" => NETWORK,
		       );
    my $list=$_[0];
    my $options = '-m policy --pol ipsec --dir out ';
    my $fmt;

    for my $e ( split_list $list, 'option' ) {
	my $val    = undef;
	my $invert = '';

	if ( $e =~ /([\w-]+)!=(.+)/ ) {
	    $val    = $2;
	    $e      = $1;
	    $invert = '! ';
	} elsif ( $e =~ /([\w-]+)=(.+)/ ) {
	    $val = $2;
	    $e   = $1;
	}

	$fmt = $validoptions{$e};

	fatal_error "Invalid Option ($e)" unless $fmt;

	if ( $fmt eq NOTHING ) {
	    fatal_error "Option \"$e\" does not take a value" if defined $val;
	} else {
	    fatal_error "Missing value for option \"$e\""        unless defined $val;
	    fatal_error "Invalid value ($val) for option \"$e\"" unless $val =~ /^($fmt)$/;
	}

	$options .= $invert;
	$options .= "--$e ";
	$options .= "$val " if defined $val;
    }

    $options;
}

#
# Process a single rule from the the masq file
#
sub process_one_masq( )
{
    my ($interfacelist, $networks, $addresses, $proto, $ports, $ipsec, $mark, $user ) = split_line1 2, 8, 'masq file';

    if ( $interfacelist eq 'COMMENT' ) {
	process_comment;
	return 1;
    }

    my $pre_nat;
    my $add_snat_aliases = $config{ADD_SNAT_ALIASES};
    my $destnets = '';
    my $baserule = '';

    #
    # Leading '+'
    #
    $pre_nat = 1 if $interfacelist =~ s/^\+//;
    #
    # Parse the remaining part of the INTERFACE column
    #
    if ( $interfacelist =~ /^([^:]+)::([^:]*)$/ ) {
	$add_snat_aliases = 0;
	$destnets = $2;
	$interfacelist = $1;
    } elsif ( $interfacelist =~ /^([^:]+:[^:]+):([^:]+)$/ ) {
	$destnets = $2;
	$interfacelist = $1;
    } elsif ( $interfacelist =~ /^([^:]+):$/ ) {
	$add_snat_aliases = 0;
	$interfacelist = $1;
    } elsif ( $interfacelist =~ /^([^:]+):([^:]*)$/ ) {
	my ( $one, $two ) = ( $1, $2 );
	if ( $2 =~ /\./ ) {
	    $interfacelist = $one;
	    $destnets = $two;
	}
    }
    #
    # If there is no source or destination then allow all addresses
    #
    $networks = ALLIPv4 if $networks eq '-';
    $destnets = ALLIPv4 if $destnets eq '-';

    #
    # Handle IPSEC options, if any
    #
    if ( $ipsec ne '-' ) {
	fatal_error "Non-empty IPSEC column requires policy match support in your kernel and iptables"  unless have_capability( 'POLICY_MATCH' );

	if ( $ipsec =~ /^yes$/i ) {
	    $baserule .= '-m policy --pol ipsec --dir out ';
	} elsif ( $ipsec =~ /^no$/i ) {
	    $baserule .= '-m policy --pol none --dir out ';
	} else {
	    $baserule .= do_ipsec_options $ipsec;
	}
    } elsif ( have_ipsec ) {
	$baserule .= '-m policy --pol none --dir out ';
    }

    #
    # Handle Protocol and Ports
    #
    $baserule .= do_proto $proto, $ports, '';
    #
    # Handle Mark
    #
    $baserule .= do_test( $mark, $globals{TC_MASK} ) if $mark ne '-';
    $baserule .= do_user( $user )                    if $user ne '-';

    for my $fullinterface (split_list $interfacelist, 'interface' ) {
	my $rule = '';
	my $target = '-j MASQUERADE ';
	#
	# Isolate and verify the interface part
	#
	( my $interface = $fullinterface ) =~ s/:.*//;

	if ( $interface =~ /(.*)[(](\w*)[)]$/ ) {
	    $interface = $1;
	    my $provider  = $2;
	    $fullinterface =~ s/[(]\w*[)]//;
	    my $realm = lookup_provider( $provider );

	    fatal_error "$provider is not a shared-interface provider" unless $realm;

	    $rule .= "-m realm --realm $realm ";
	}

	fatal_error "Unknown interface ($interface)" unless my $interfaceref = known_interface( $interface );

	unless ( $interfaceref->{root} ) {
	    $rule .= match_dest_dev( $interface );
	    $interface = $interfaceref->{name};
	}

	my $chainref = ensure_chain('nat', $pre_nat ? snat_chain $interface : masq_chain $interface);

	my $detectaddress = 0;
	my $exceptionrule = '';
	my $randomize     = '';
	my $persistent    = '';
	#
	# Parse the ADDRESSES column
	#
	if ( $addresses ne '-' ) {
	    if ( $addresses eq 'random' ) {
		$randomize = '--random ';
	    } else {
		$addresses =~ s/:persistent$// and $persistent = '--persistent ';
		$addresses =~ s/:random$//     and $randomize  = '--random ';

		require_capability 'PERSISTENT_SNAT', ':persistent', 's' if $persistent;

		if ( $addresses =~ /^SAME/ ) {
		    fatal_error "The SAME target is no longer supported";
		} elsif ( $addresses eq 'detect' ) {
		    my $variable = get_interface_address $interface;
		    $target = "-j SNAT --to-source $variable";

		    if ( interface_is_optional $interface ) {
			add_commands( $chainref,
				      '',
				      "if [ \"$variable\" != 0.0.0.0 ]; then" );
			incr_cmd_level( $chainref );
			$detectaddress = 1;
		    }
		} elsif ( $addresses eq 'NONAT' ) {
		    $target = '-j RETURN';
		    $add_snat_aliases = 0;
		} else {
		    my $addrlist = '';
		    for my $addr ( split_list $addresses , 'address' ) {
			if ( $addr =~ /^.*\..*\..*\./ ) {
			    $target = '-j SNAT ';
			    my ($ipaddr, $rest) = split ':', $addr;
			    if ( $ipaddr =~ /^(.+)-(.+)$/ ) {
				validate_range( $1, $2 );
			    } else {
				validate_address $ipaddr, 0;
			    }
			    $addrlist .= "--to-source $addr ";
			    $exceptionrule = do_proto( $proto, '', '' ) if $addr =~ /:/;
			} else {
			    $addr =~ s/^://;
			    $addrlist .= "--to-ports $addr ";
			    $exceptionrule = do_proto( $proto, '', '' );
			}
		    }

		    $target .= $addrlist;
		}
	    }

	    $target .= $randomize;
	    $target .= $persistent;
	} else {
	    $add_snat_aliases = 0;
	}
	#
	# And Generate the Rule(s)
	#
	expand_rule( $chainref ,
		     POSTROUTE_RESTRICT ,
		     $baserule . $rule ,
		     $networks ,
		     $destnets ,
		     '' ,
		     $target ,
		     '' ,
		     '' ,
		     $exceptionrule );

	if ( $detectaddress ) {
	    decr_cmd_level( $chainref );
	    add_commands( $chainref , 'fi' );
	}

	if ( $add_snat_aliases ) {
	    my ( $interface, $alias , $remainder ) = split( /:/, $fullinterface, 3 );
	    fatal_error "Invalid alias ($alias:$remainder)" if defined $remainder;
	    for my $address ( split_list $addresses, 'address' ) {
		my ( $addrs, $port ) = split /:/, $address;
		next unless $addrs;
		next if $addrs eq 'detect';
		for my $addr ( ip_range_explicit $addrs ) {
		    unless ( $addresses_to_add{$addr} ) {
			$addresses_to_add{$addr} = 1;
			if ( defined $alias ) {
			    push @addresses_to_add, $addr, "$interface:$alias";
			    $alias++;
			} else {
			    push @addresses_to_add, $addr, $interface;
			}
		    }
		}
	    }
	}
    }

    progress_message "   Masq record \"$currentline\" $done";

}

#
# Process the masq file
#
sub setup_masq()
{
    my $fn = open_file 'masq';

    first_entry( sub { progress_message2 "$doing $fn..."; require_capability 'NAT_ENABLED' , 'a non-empty masq file' , 's'; } );

    process_one_masq while read_a_line;

    clear_comment;

}

#
# Validate the ALL INTERFACES or LOCAL column in the NAT file
#
sub validate_nat_column( $$ ) {
    my $ref = $_[1];
    my $val = $$ref;

    if ( defined $val ) {
	unless ( ( $val = "\L$val" ) eq 'yes' ) {
	    if ( ( $val eq 'no' ) || ( $val eq '-' ) ) {
		$$ref = '';
	    } else {
		fatal_error "Invalid value ($val) for $_[0]";
	    }
	}
    } else {
	$$ref = '';
    }
}

#
# Process a record from the NAT file
#
sub do_one_nat( $$$$$ )
{
    my ( $external, $fullinterface, $internal, $allints, $localnat ) = @_;

    my ( $interface, $alias, $remainder ) = split( /:/, $fullinterface, 3 );

    fatal_error "Invalid alias ($alias:$remainder)" if defined $remainder;

    sub add_nat_rule( $$ ) {
	add_rule ensure_chain( 'nat', $_[0] ) , $_[1];
    }

    my $add_ip_aliases = $config{ADD_IP_ALIASES};

    my $policyin = '';
    my $policyout = '';
    my $rulein = '';
    my $ruleout = '';

    fatal_error "Unknown interface ($interface)" unless my $interfaceref = known_interface( $interface );

    unless ( $interfaceref->{root} ) {
	$rulein  = match_source_dev $interface;
	$ruleout = match_dest_dev $interface;
	$interface = $interfaceref->{name};
    }

    if ( have_ipsec ) {
	$policyin = ' -m policy --pol none --dir in';
	$policyout =  '-m policy --pol none --dir out';
    }

    fatal_error "Invalid nat file entry" unless defined $interface && defined $internal;

    if ( $add_ip_aliases ) {
	$add_ip_aliases = '' if defined( $alias ) && $alias eq '';
    }

    validate_nat_column 'ALL INTERFACES', \$allints;
    validate_nat_column 'LOCAL'         , \$localnat;

    if ( $allints ) {
	add_nat_rule 'nat_in' ,  "-d $external $policyin  -j DNAT --to-destination $internal";
	add_nat_rule 'nat_out' , "-s $internal $policyout -j SNAT --to-source $external";
    } else {
	add_nat_rule input_chain( $interface ) ,  $rulein  . "-d $external $policyin -j DNAT --to-destination $internal";
	add_nat_rule output_chain( $interface ) , $ruleout . "-s $internal $policyout -j SNAT --to-source $external";
    }

    add_nat_rule 'OUTPUT' , "-d $external $policyout -j DNAT --to-destination $internal " if $localnat;

    if ( $add_ip_aliases ) {
	unless ( $addresses_to_add{$external} ) {
	    $addresses_to_add{$external} = 1;
	    push @addresses_to_add, ( $external , $fullinterface );
	}
    }
}

#
# Process NAT file
#
sub setup_nat() {

    my $fn = open_file 'nat';

    first_entry( sub { progress_message2 "$doing $fn..."; require_capability 'NAT_ENABLED' , 'a non-empty nat file' , 's'; } );

    while ( read_a_line ) {

	my ( $external, $interfacelist, $internal, $allints, $localnat ) = split_line1 3, 5, 'nat file';

	if ( $external eq 'COMMENT' ) {
	    process_comment;
	} else {
	    ( $interfacelist, my $digit ) = split /:/, $interfacelist;

	    $digit = defined $digit ? ":$digit" : '';

	    for my $interface ( split_list $interfacelist , 'interface' ) {
		fatal_error "Invalid Interface List ($interfacelist)" unless defined $interface && $interface ne '';
		do_one_nat $external, "${interface}${digit}", $internal, $allints, $localnat;
	    }

	    progress_message "   NAT entry \"$currentline\" $done";
	}

    }

    clear_comment;
}

#
# Setup Network Mapping
#
sub setup_netmap() {

    my $fn = open_file 'netmap';

    first_entry( sub { progress_message2 "$doing $fn..."; require_capability 'NAT_ENABLED' , 'a non-empty netmap file' , 's'; } );

    while ( read_a_line ) {

	my ( $type, $net1, $interfacelist, $net2 ) = split_line 4, 4, 'netmap file';

	for my $interface ( split_list $interfacelist, 'interface' ) {

	    my $rulein = '';
	    my $ruleout = '';
	    my $iface = $interface;

	    fatal_error "Unknown interface ($interface)" unless my $interfaceref = find_interface( $interface );

	    unless ( $interfaceref->{root} ) {
		$rulein  = match_source_dev $interface;
		$ruleout = match_dest_dev $interface;
		$interface = $interfaceref->{name};
	    }

	    if ( $type eq 'DNAT' ) {
		add_rule ensure_chain( 'nat' , input_chain $interface )  , $rulein  . "-d $net1 -j NETMAP --to $net2";
	    } elsif ( $type eq 'SNAT' ) {
		add_rule ensure_chain( 'nat' , output_chain $interface ) , $ruleout . "-s $net1 -j NETMAP --to $net2";
	    } else {
		fatal_error "Invalid type ($type)";
	    }

	    progress_message "   Network $net1 on $iface mapped to $net2 ($type)";
	}
    }

}

sub add_addresses () {
    if ( @addresses_to_add ) {
	my @addrs = @addresses_to_add;
	my $arg = '';
	my $addresses = 0;

	while ( @addrs ) {
	    my $addr      = shift @addrs;
	    my $interface = shift @addrs;
	    $arg = "$arg $addr $interface";
	    unless ( $config{RETAIN_ALIASES} ) {
		emit '' unless $addresses++;
		$interface =~ s/:.*//;
		emit "del_ip_addr $addr $interface";
	    }
	}

	emit "\nadd_ip_aliases $arg";
    }
}

1;
