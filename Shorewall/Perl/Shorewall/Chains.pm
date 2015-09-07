#
# Shorewall 4.5 -- /usr/share/shorewall/Shorewall/Chains.pm
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2007,2008,2009,2010,2011,2012,2013 - Tom Eastep (teastep@shorewall.net)
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
#  This is the low-level iptables module. It provides the basic services
#  of chain and rule creation. It is used by the higher level modules such
#  as Rules to create iptables-restore input.
#
package Shorewall::Chains;
require Exporter;

use Scalar::Util 'reftype';
use Digest::SHA qw(sha1_hex);
use File::Basename;
use Shorewall::Config qw(:DEFAULT :internal);
use Shorewall::Zones;
use Shorewall::IPAddrs;
use strict;

our @ISA = qw(Exporter);
our @EXPORT = ( qw(
		    DONT_OPTIMIZE
		    DONT_DELETE
		    DONT_MOVE

		    add_rule
		    add_irule
		    add_jump
		    add_ijump
		    insert_rule
		    insert_irule
		    clone_irule
		    insert_ijump
		    rule_target
		    clear_rule_target
		    set_rule_target
		    set_rule_option
		    add_trule
		    add_commands
		    incr_cmd_level
		    decr_cmd_level
		    new_chain
		    new_manual_chain
		    ensure_filter_chain
		    ensure_manual_chain
		    ensure_audit_chain
		    ensure_blacklog_chain
		    ensure_audit_blacklog_chain
		    require_audit
		    newlogchain
		    log_rule_limit
		    log_irule_limit
		    allow_optimize
		    allow_delete
		    allow_move
                    make_terminating
		    set_optflags
		    reset_optflags
		    has_return
		    dont_optimize
		    dont_delete
		    dont_move
		    add_interface_options
		    state_match
		    state_imatch
                    split_action
                    get_target_param
                    get_target_param1
                    get_inline_matches
                    handle_inline

		    STANDARD
		    NATRULE
		    BUILTIN
		    NONAT
		    NATONLY
		    REDIRECT
		    ACTION
		    MACRO
		    LOGRULE
		    NFLOG
		    NFQ
		    CHAIN
		    SET
		    AUDIT
		    HELPER
		    INLINE
		    STATEMATCH
		    USERBUILTIN
		    INLINERULE
		    OPTIONS
                    IPTABLES
		    TARPIT
                    FILTER_TABLE
                    NAT_TABLE
                    MANGLE_TABLE
                    RAW_TABLE

		    %chain_table
		    %targets
		    $raw_table
		    $rawpost_table
		    $nat_table
		    $mangle_table
		    $filter_table
		)
	      );

our %EXPORT_TAGS = (
		    internal => [  qw( NO_RESTRICT
				       PREROUTE_RESTRICT
				       DESTIFACE_DISALLOW
				       INPUT_RESTRICT
				       OUTPUT_RESTRICT
				       POSTROUTE_RESTRICT
				       ALL_RESTRICT
				       ALL_COMMANDS
				       NOT_RESTORE

				       unreachable_warning
				       state_match
				       state_imatch
				       initialize_chain_table
				       copy_rules
				       move_rules
				       insert_rule1
				       delete_jumps
				       add_tunnel_rule
				       forward_chain
				       forward_option_chain
				       rules_chain
				       blacklist_chain
				       established_chain
				       related_chain
				       invalid_chain
				       untracked_chain
				       zone_forward_chain
				       use_forward_chain
				       input_chain
				       input_option_chain
				       zone_input_chain
				       use_input_chain
				       output_chain
				       output_option_chain
				       prerouting_chain
				       postrouting_chain
				       zone_output_chain
				       use_output_chain
				       masq_chain
				       syn_flood_chain
				       mac_chain
				       macrecent_target
				       dnat_chain
				       snat_chain
				       ecn_chain
				       notrack_chain
				       load_chain
				       first_chains
				       option_chains
				       reserved_name
				       find_chain
				       ensure_chain
				       ensure_accounting_chain
				       accounting_chainrefs
				       ensure_mangle_chain
				       ensure_nat_chain
				       ensure_raw_chain
				       ensure_rawpost_chain
				       new_standard_chain
				       new_builtin_chain
				       new_nat_chain
				       optimize_chain
				       check_optimization
				       optimize_level0
				       optimize_ruleset
				       setup_zone_mss
				       newexclusionchain
				       newnonatchain
				       source_exclusion
				       source_iexclusion
				       dest_exclusion
				       dest_iexclusion
				       clearrule
				       port_count
				       do_proto
				       do_iproto
				       do_mac
				       do_imac
				       verify_mark
				       verify_small_mark
				       validate_mark
				       do_test
				       do_ratelimit
				       do_connlimit
				       do_time
				       do_user
				       do_length
				       decode_tos
				       do_tos
				       do_connbytes
				       do_helper
				       validate_helper
				       do_headers
				       do_probability
				       do_condition
				       do_dscp
				       do_nfacct
				       have_ipset_rules
				       record_runtime_address
				       verify_address_variables
				       conditional_rule
				       conditional_rule_end
				       match_source_dev
				       imatch_source_dev
				       match_dest_dev
				       imatch_dest_dev
				       iprange_match
				       match_source_net
				       imatch_source_net
				       match_dest_net
				       imatch_dest_net
				       match_orig_dest
				       match_ipsec_in
				       match_ipsec_out
				       do_ipsec_options
				       do_ipsec
				       log_rule
				       log_irule
				       handle_network_list
				       expand_rule
				       addnatjump
				       split_host_list
				       set_chain_variables
				       mark_firewall_not_started
				       mark_firewall6_not_started
				       get_interface_address
				       get_interface_addresses
				       get_interface_bcasts
				       get_interface_acasts
				       get_interface_gateway
				       get_interface_mac
				       have_global_variables
                                       have_address_variables
				       set_global_variables
				       save_dynamic_chains
				       load_ipsets
				       create_save_ipsets
				       validate_nfobject
				       create_nfobjects
				       create_netfilter_load
				       preview_netfilter_load
				       create_chainlist_reload
				       create_stop_load
				       initialize_switches
				       %targets
				       %builtin_target
				       %dscpmap
				     ) ],
		   );

Exporter::export_ok_tags('internal');

our $VERSION = 'MODULEVERSION';

#
# Chain Table
#
#    %chain_table { <table> => { <chain1>  => { name         => <chain name>
#                                               table        => <table name>
#                                               is_policy    => undef|1 -- if 1, this is a policy chain
#                                               provisional  => undef|1 -- See below.
#                                               referenced   => undef|1 -- If 1, will be written to the iptables-restore-input.
#                                               builtin      => undef|1 -- If 1, one of Netfilter's built-in chains.
#                                               manual       => undef|1 -- If 1, a manual chain.
#                                               accounting   => undef|1 -- If 1, an accounting chain
#                                               optflags     => <optimization flags>
#                                               log          => <logging rule number for use when LOGRULENUMBERS>
#                                               policy       => <policy>
#                                               policychain  => <name of policy chain> -- self-reference if this is a policy chain
#                                               policypair   => [ <policy source>, <policy dest> ] -- Used for reporting duplicated policies
#                                               origin       => <filename and line number of entry that created this policy chain>
#                                               loglevel     => <level>
#                                               synparams    => <burst/limit + connlimit>
#                                               synchain     => <name of synparam chain>
#                                               default      => <default action>
#                                               cmdlevel     => <number of open loops or blocks in runtime commands>
#                                               new          => undef|<index into @$rules where NEW section starts>
#                                               rules        => [ <rule1>
#                                                                 <rule2>
#                                                                 ...
#                                                               ]
#                                               logchains    => { <key1> = <chainref1>, ... }
#                                               references   => { <ref1> => <refs>, <ref2> => <refs>, ... }
#                                               blacklistsection
#                                                            => Chain was created by entries in the BLACKLIST section of the rules file
#                                               action       => <action tuple that generated this chain>
#                                               restricted   => Logical OR of restrictions of rules in this chain.
#                                               restriction  => Restrictions on further rules in this chain.
#                                               audit        => Audit the result.
#                                               filtered     => Number of filter rules at the front of an interface forward chain
#                                               digest       => SHA1 digest of the string representation of the chain's rules for use in optimization
#                                                               level 8.
#                                               complete     => The last rule in the chain is a -g or a simple -j to a terminating target
#                                                               Suppresses adding additional rules to the chain end of the chain
#                                               sections     => { <section> = 1, ... } - Records sections that have been completed.
#                                             } ,
#                                <chain2> => ...
#                              }
#                 }
#
#       'provisional' only applies to policy chains; when true, indicates that this is a provisional policy chain which might be
#       replaced. Policy chains created under the IMPLICIT_CONTINUE=Yes option are marked with provisional == 1 as are intra-zone
#       ACCEPT policies.
#
#       Only 'referenced' chains get written to the iptables-restore input.
#
#       'loglevel', 'synparams', 'synchain', 'audit', 'default' abd 'origin' only apply to policy chains.
###########################################################################################################################################
#
# For each ordered pair of zones, there may exist a 'canonical rules chain' in the filter table; the name of this chain is formed by
# joining the names of the zones using the ZONE_SEPARATOR ('2' or '-'). This chain contains the rules that specifically deal with
# connections from the first zone to the second. These chains will end with the policy rules when EXPAND_POLICIES=Yes and when there is an
# explicit policy for the order pair. Otherwise, unless the applicable policy is CONTINUE, the chain will terminate with a jump to a
# wildcard policy chain (all[2-]zone, zone[2-]all, or all[2-]all).
#
# Except in the most trivial one-interface configurations, each zone has a "forward chain" which is branched to from the filter table
# FORWARD chain. 
#
# For each network interface, there are up to 6 chains in the filter table:
#
# - Input, Output, Forward "Interface Chains"
#      These are present when there is more than one zone associated with the interface. They are jumped to from the INPUT, OUTPUT and
#      FORWARD chains respectively.
# - Input Option, Output Option and Forward "Interface Option Chains"
#      Used when blacklisting is involved for enforcing interface options that require Netfilter rules. This allows blacklisting to
#      occur prior to interface option filtering. When these chains are not used, any rules that they contained are moved to the
#      corresponding interface chains.
#
###########################################################################################################################################
#
# Constructed chain names
#
#   Interface Chains for device <dev>
#
#      OUTPUT          - <dev>_out
#      PREROUTING      - <dev>_pre
#      POSTROUTING     - <dev>_post
#      MASQUERADE      - <dev>_masq
#      MAC filtering   - <dev>_mac
#      MAC Recent      - <dev>_rec
#      SNAT            - <dev>_snat
#      ECN             - <dev>_ecn
#      FORWARD Options - <dev>_fop
#      OUTPUT Options  - <dev>_oop
#      FORWARD Options - <dev>_fop
#
#   Zone Chains for zone <z>
#
#      INPUT           - <z>_input
#      OUTPUT          - <z>_output
#      FORWARD         - <z>_frwd
#      DNAT            - <z>_dnat
#      Conntrack       - <z>_ctrk
#
#   Provider Chains for provider <p>
#      Load Balance    - ~<p>
#
#   Zone-pair chains for rules chain <z12z2>
#
#      Syn Flood       - @<z12z2>
#      Blacklist       - <z12z2>~
#      Established     - ^<z12z2>
#      Related         - +<z12z2>
#      Invalid         - _<z12z2>
#      Untracked       - &<z12z2>
#
our %chain_table;
our $raw_table;
our $rawpost_table;
our $nat_table;
our $mangle_table;
our $filter_table;
our $export;
our %renamed;
our %nfobjects;

#
# Target Types
#
use constant { STANDARD     =>      0x1,       #defined by Netfilter
	       NATRULE      =>      0x2,       #Involves NAT
	       BUILTIN      =>      0x4,       #A built-in action
	       NONAT        =>      0x8,       #'NONAT' or 'ACCEPT+'
	       NATONLY      =>     0x10,       #'DNAT-' or 'REDIRECT-'
	       REDIRECT     =>     0x20,       #'REDIRECT'
	       ACTION       =>     0x40,       #An action (may be built-in)
	       MACRO        =>     0x80,       #A Macro
	       LOGRULE      =>    0x100,       #'LOG','NFLOG'
	       NFQ          =>    0x200,       #'NFQUEUE'
	       CHAIN        =>    0x400,       #Manual Chain
	       SET          =>    0x800,       #SET
	       AUDIT        =>   0x1000,       #A_ACCEPT, etc
	       HELPER       =>   0x2000,       #CT:helper
	       NFLOG        =>   0x4000,       #NFLOG or ULOG
	       INLINE       =>   0x8000,       #Inline action
	       STATEMATCH   =>  0x10000,       #action.Invalid, action.Related, etc.
	       USERBUILTIN  =>  0x20000,       #Builtin action from user's actions file.
	       INLINERULE   =>  0x40000,       #INLINE
	       OPTIONS      =>  0x80000,       #Target Accepts Options
	       IPTABLES     => 0x100000,       #IPTABLES or IP6TABLES
	       TARPIT       => 0x200000,       #TARPIT

	       FILTER_TABLE =>  0x1000000,
	       MANGLE_TABLE =>  0x2000000,
	       RAW_TABLE    =>  0x4000000,
	       NAT_TABLE    =>  0x8000000,
	   };
#
# Valid Targets -- value is a combination of one or more of the above
#
our %targets;
#
# Terminating builtins
#
our %terminating;
#
# expand_rule() restrictions
#
use constant { NO_RESTRICT         => 0,   # FORWARD chain rule     - Both -i and -o may be used in the rule
	       PREROUTE_RESTRICT   => 1,   # PREROUTING chain rule  - -o converted to -d <address list> using main routing table
	       INPUT_RESTRICT      => 4,   # INPUT chain rule       - -o not allowed
	       OUTPUT_RESTRICT     => 8,   # OUTPUT chain rule      - -i not allowed
	       POSTROUTE_RESTRICT  => 16,  # POSTROUTING chain rule - -i converted to -s <address list> using main routing table
	       ALL_RESTRICT        => 12,  # fw->fw rule            - neither -i nor -o allowed
	       DESTIFACE_DISALLOW  => 32,  # Don't allow dest interface. Similar to INPUT_RESTRICT but generates a more relevant error message
	       };
#
# Possible IPSET options
#
our %ipset_extensions = (
    'nomatch'               => '--return-nomatch ',
    'no-update-counters'    => '! --update-counters ',
    'no-update-subcounters' => '! --update-subcounters ',
    'packets'               => '',
    'bytes'                 => '',
    );
#
# See initialize() below for additional comments on these variables
#
our $iprangematch;
our %chainseq;
our $idiotcount;
our $idiotcount1;
our $hashlimitset;
our $global_variables;
our %address_variables;
our $ipset_rules;

#
# Determines the commands for which a particular interface-oriented shell variable needs to be set
#
use constant { ALL_COMMANDS => 1, NOT_RESTORE => 2 };

use constant { DONT_OPTIMIZE => 1 , DONT_DELETE => 2, DONT_MOVE => 4, RETURNS => 8, RETURNS_DONT_MOVE => 12 };

our %dscpmap = ( CS0  => 0x00,
		 CS1  => 0x08,
		 CS2  => 0x10,
		 CS3  => 0x18,
		 CS4  => 0x20,
		 CS5  => 0x28,
		 CS6  => 0x30,
		 CS7  => 0x38,
		 BE   => 0x00,
		 AF11 => 0x0a,
		 AF12 => 0x0c,
		 AF13 => 0x0e,
		 AF21 => 0x12,
		 AF22 => 0x14,
		 AF23 => 0x16,
		 AF31 => 0x1a,
		 AF32 => 0x1c,
		 AF33 => 0x1e,
		 AF41 => 0x22,
		 AF42 => 0x24,
		 AF43 => 0x26,
		 EF   => 0x2e,
	       );

our %tosmap = ( 'Minimize-Delay'       => 0x10,
		'Maximize-Throughput'  => 0x08,
		'Maximize-Reliability' => 0x04,
		'Minimize-Cost'        => 0x02,
		'Normal-Service'       => 0x00 );
#
# These hashes hold the shell code to set shell variables. The key is the name of the variable; the value is the code to generate the variable's contents
#
our %interfaceaddr;         # First interface address
our %interfaceaddrs;        # All interface addresses
our %interfacenets;         # Networks routed out of the interface
our %interfacemacs;         # Interface MAC
our %interfacebcasts;       # Broadcast addresses associated with the interface (IPv4)
our %interfaceacasts;       # Anycast addresses associated with the interface (IPv6)
our %interfacegateways;     # Gateway of default route out of the interface

#
# Built-in Chains
#
our @builtins = qw(PREROUTING INPUT FORWARD OUTPUT POSTROUTING);

#
# Mode of the emitter (part of this module that converts rules in the chain table into iptables-restore input)
#
use constant { NULL_MODE => 0 ,   # Emitting neither shell commands nor iptables-restore input
	       CAT_MODE  => 1 ,   # Emitting iptables-restore input
	       CMD_MODE  => 2 };  # Emitting shell commands.

our $mode;
#
# A reference to this rule is returned when we try to push a rule onto a 'complete' chain
#
our $dummyrule = { simple => 1, matches => [], mode => CAT_MODE };

#
# Address Family
#
our $family;

#
# These are the current builtin targets
#
our %builtin_target = ( ACCEPT      => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			ACCOUNT     => STANDARD + MANGLE_TABLE,
			AUDIT       => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			CHAOS       => STANDARD + FILTER_TABLE,
			CHECKSUM    => STANDARD                            + MANGLE_TABLE,
			CLASSIFY    => STANDARD                            + MANGLE_TABLE,
		        CLUSTERIP   => STANDARD                            + MANGLE_TABLE + RAW_TABLE,
			CONNMARK    => STANDARD                            + MANGLE_TABLE,
			CONNSECMARK => STANDARD                            + MANGLE_TABLE,
			COUNT       => STANDARD + FILTER_TABLE,
			CT          => STANDARD                                           + RAW_TABLE,
			DELUDE      => STANDARD + FILTER_TABLE,
			DHCPMAC     => STANDARD                            + MANGLE_TABLE,
			DNAT        => STANDARD                + NAT_TABLE,
			DNETMAP     => STANDARD                + NAT_TABLE,
			DROP        => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			DSCP        => STANDARD                            + MANGLE_TABLE,
			ECHO        => STANDARD + FILTER_TABLE,
			ECN         => STANDARD                            + MANGLE_TABLE,
			HL          => STANDARD                            + MANGLE_TABLE,
			IDLETIMER   => STANDARD,
			IPMARK      => STANDARD                            + MANGLE_TABLE,
			LOG         => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			LOGMARK     => STANDARD                            + MANGLE_TABLE,
			MARK        => STANDARD + FILTER_TABLE             + MANGLE_TABLE,
			MASQUERADE  => STANDARD                + NAT_TABLE,
			MIRROR      => STANDARD + FILTER_TABLE,
			NETMAP      => STANDARD                + NAT_TABLE,,
			NFLOG       => STANDARD                            + MANGLE_TABLE + RAW_TABLE,
			NFQUEUE     => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			NOTRACK     => STANDARD                                           + RAW_TABLE,
			QUEUE       => STANDARD + FILTER_TABLE,
			RATEEST     => STANDARD                            + MANGLE_TABLE,
			RAWDNAT     => STANDARD                                           + RAW_TABLE,
			RAWSNAT     => STANDARD                                           + RAW_TABLE,
			REDIRECT    => STANDARD                + NAT_TABLE,
			REJECT      => STANDARD + FILTER_TABLE,
			RETURN      => STANDARD                            + MANGLE_TABLE + RAW_TABLE,
			SAME        => STANDARD,
			SECMARK     => STANDARD                            + MANGLE_TABLE,
			SET         => STANDARD                            + MANGLE_TABLE + RAW_TABLE,
			SNAT        => STANDARD                + NAT_TABLE,
			STEAL       => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			SYSRQ       => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			TARPIT      => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			TCPMSS      => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			TCPOPTSTRIP => STANDARD                            + MANGLE_TABLE,
			TEE         => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
			TOS         => STANDARD                            + MANGLE_TABLE,
			TPROXY      => STANDARD                            + MANGLE_TABLE,
			TRACE       => STANDARD                                           + RAW_TABLE,
			TTL         => STANDARD                            + MANGLE_TABLE,
			ULOG        => STANDARD + FILTER_TABLE + NAT_TABLE + MANGLE_TABLE + RAW_TABLE,
		        );

our %ipset_exists;

#
# Rules are stored in an internal form
#
#     {   mode       => CAT_MODE if rule is not part of a conditional block or loop
#                    => CMD_MODE if the rule contains a shell command or if it
#                                part of a loop or conditional block. If it is a
#                                shell command, the text of the command is in
#                                the cmd
#         cmd        => Shell command, if mode == CMD_MODE and cmdlevel == 0
#         cmdlevel   => nesting level within loops and conditional blocks.
#                       determines indentation
#         simple     => true|false. If true, there are no matches or options
#         jump       => 'j' or 'g' (determines whether '-j' or '-g' is included)
#                       Omitted, if target is ''.
#         target     => Rule target, if jump is 'j' or 'g'.
#         targetopts => Target options. Only included if non-empty
#         <option>   => iptables/ip6tables -A options (e.g., i => eth0)
#         <match>    => iptables match. Value may be a scalar or array.
#                       if an array, multiple "-m <match>"s will be generated
#    }
#
# The following constants and hash are used to classify keys in a rule hash
#
use constant { UNIQUE      => 1,
	       TARGET      => 2,
	       EXCLUSIVE   => 4,
	       MATCH       => 8,
	       CONTROL     => 16,
	       COMPLEX     => 32,
	       NFACCT      => 64,
	       EXPENSIVE   => 128,
	       RECENT      => 256,
	   };

our %opttype = ( rule          => CONTROL,
		 cmd           => CONTROL,

		 dhcp          => CONTROL,

		 mode          => CONTROL,
		 cmdlevel      => CONTROL,
		 simple        => CONTROL,
		 matches       => CONTROL,
		 complex       => CONTROL,
		 t             => CONTROL,

		 i             => UNIQUE,
		 s             => UNIQUE,
		 o             => UNIQUE,
		 d             => UNIQUE,
		 p             => UNIQUE,
		 dport         => UNIQUE,
		 sport         => UNIQUE,
		 'icmp-type'   => UNIQUE,
		 'icmpv6-type' => UNIQUE,

		 comment       => CONTROL,

		 policy        => MATCH,
		 state         => EXCLUSIVE,
		 'conntrack --ctstate' =>
		                  EXCLUSIVE,

		 nfacct        => NFACCT,
		 recent        => RECENT,

		 set           => EXPENSIVE,
		 geoip         => EXPENSIVE,

		 conntrack     => COMPLEX,

		 jump          => TARGET,
		 target        => TARGET,
		 targetopts    => TARGET,
	       );

our %aliases = ( protocol        => 'p',
		 source          => 's',
		 destination     => 'd',
		 jump            => 'j',
		 goto            => 'g',
		 'in-interface'  => 'i',
		 'out-interface' => 'o',
		 dport           => 'dport',
		 sport           => 'sport',
		 'icmp-type'     => 'icmp-type',
		 'icmpv6-type'   => 'icmpv6-type',
	       );

our @unique_options = ( qw/p dport sport icmp-type icmpv6-type s d i o/ );

our %isocodes;

use constant { ISODIR => '/usr/share/xt_geoip/LE' };

our %switches;

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
sub initialize( $$$ ) {
    ( $family, my $hard, $export ) = @_;

    %chain_table = ( raw    =>  {},
		     rawpost => {},
		     mangle =>  {},
		     nat    =>  {},
		     filter =>  {} );

    $raw_table     = $chain_table{raw};
    $rawpost_table = $chain_table{rawpost};
    $nat_table     = $chain_table{nat};
    $mangle_table  = $chain_table{mangle};
    $filter_table  = $chain_table{filter};
    %renamed       = ();
    #
    # Used to sequence chain names in each table.
    #
    %chainseq = () if $hard;
    #
    # Used to suppress duplicate match specifications for old iptables binaries.
    #
    $iprangematch = 0;
    #
    # Keep track of which interfaces have active 'address', 'addresses', 'networks', etc. variables
    #
    %interfaceaddr      = ();
    %interfaceaddrs     = ();
    %interfacenets      = ();
    %interfacemacs      = ();
    %interfacebcasts    = ();
    %interfaceacasts    = ();
    %interfacegateways  = ();
    %address_variables  = ();

    $global_variables   = 0;
    $idiotcount         = 0;
    $idiotcount1        = 0;
    $hashlimitset       = 0;
    $ipset_rules        = 0 if $hard;

    %ipset_exists       = ();

    %isocodes  = ();
    %nfobjects = ();
    %switches  = ();

    %terminating = ( ACCEPT       => 1,
		     DROP         => 1,
		     RETURN       => 1,
		     QUEUE        => 1,
		     CLASSIFY     => 1,
		     DNAT         => 1,
		     MASQUERADE   => 1,
		     NETMAP       => 1,
		     NFQUEUE      => 1,
		     NOTRACK      => 1,
		     REDIRECT     => 1,
		     RAWDNAT      => 1,
		     RAWSNAT      => 1,
		     REJECT       => 1,
		     SAME         => 1,
		     SNAT         => 1,
		     TPROXY       => 1,
		     reject       => 1,
		   );
    #
    # The chain table is initialized via a call to initialize_chain_table() after the configuration and capabilities have been determined.
    #
}

#
# Functions to manipulate cmdlevel
#
sub incr_cmd_level( $ ) {
    my $chain = $_[0];
    $chain->{cmdlevel}++;
    $chain->{optflags} |= ( DONT_OPTIMIZE | DONT_MOVE );
}

sub decr_cmd_level( $ ) {
    assert( --$_[0]->{cmdlevel} >= 0, $_[0] );
}

#
# Mark an action as terminating
#
sub make_terminating( $ ) {
    $terminating{$_[0]} = 1;
}

#
# Transform the passed iptables rule into an internal-form hash reference.
# Most of the compiler has been converted to use the new form natively.
# A few parts, mostly those dealing with expand_rule(), still generate
# iptables command strings which are converted into the new form by
# transform_rule()
#
# First a helper for recording an nfacct object name
#
sub record_nfobject( $ ) {
    my @value = split ' ', $_[0];
    $nfobjects{$value[-1]} = 1;
}

#
# Validate and register an nfacct object name
#

sub validate_nfobject( $;$ ) {
    my ( $name, $allowbang ) = @_;

    fatal_error "Invalid nfacct object name ($name)" unless $name =~ /^[-\w%&@~]+(!)?$/ && ( $allowbang || ! $1 );
    $nfobjects{$_} = 1;
}

#
# Get a rule option's type
#
sub get_opttype( $$ ) { # $option, $default
    $opttype{$_[0]} || $_[1];
}

#
# Next a helper for setting an individual option
#
sub set_rule_option( $$$ ) {
    my ( $ruleref, $option, $value ) = @_;

    assert( defined $value && reftype $ruleref , $option, $ruleref );

    $ruleref->{simple} = 0;
    $ruleref->{complex} = 1 if reftype $value;

    my $opttype = get_opttype( $option, MATCH );

    if ( $opttype == COMPLEX ) {
	#
	# Consider each subtype as a separate type
	#
	my ( $invert, $subtype, $val, $rest ) = split ' ', $value;

	if ( $invert eq '!' ) {
	    assert( ! supplied $rest );
	    $option = join( ' ', $option, $invert, $subtype );
	    $value  = $val;
	} else {
	    assert( ! supplied $val );
	    $option  = join( ' ', $option, $invert );
	    $value   = $subtype;
	}

	$opttype = EXCLUSIVE;
    }

    if ( exists $ruleref->{$option} ) {
	assert( defined( my $value1 = $ruleref->{$option} ) , $ruleref );

	if ( $opttype & ( MATCH | NFACCT | RECENT | EXPENSIVE ) ) {
	    if ( $globals{KLUDGEFREE} ) {
		unless ( reftype $value1 ) {
		    unless ( reftype $value ) {
			return if $value1 eq $value;
		    }

		    $ruleref->{$option} = [ $ruleref->{$option} ];
		}

		push @{$ruleref->{$option}}, ( reftype $value ? @$value : $value );
		push @{$ruleref->{matches}}, $option;
		$ruleref->{complex} = 1;

		record_nfobject( $value ) if $opttype == NFACCT;
	    } else {
		assert( ! reftype $value );
		$ruleref->{$option} = join(' ', $value1, $value ) unless $value1 eq $value;
	    }
	} elsif ( $opttype == EXCLUSIVE ) {
	    $ruleref->{$option} .= ",$value";
	} elsif ( $opttype  == CONTROL ) {
	    $ruleref->{$option} = $value;
	} elsif ( $opttype == UNIQUE ) {
	    #
	    # Shorewall::Rules::perl_action_tcp_helper() can produce rules that have two -p specifications.
	    # The first will have a modifier like '! --syn' while the second will not.  We want to retain
	    # the first while 
	    if ( $option eq 'p' ) {
		my ( $proto ) = split( ' ', $ruleref->{p} );
		return if $proto eq $value;
	    }

	    fatal_error "Multiple $option settings in one rule is prohibited";
	} else {
	    assert($opttype == TARGET, $opttype );
	}
    } else {
	$ruleref->{$option} = $value;
	push @{$ruleref->{matches}}, $option;
	record_nfobject( $value ) if $opttype == NFACCT;
    }
}

sub transform_rule( $;\$ ) {
    my ( $input, $completeref ) = @_;
    my $ruleref  = { mode => CAT_MODE, matches => [], target => '' };
    my $simple   = 1;
    my $target   = '';
    my $jump     = '';

    $input =~ s/^\s*//;

    while ( $input ) {
	my $option;
	my $invert = '';

	if ( $input =~ s/^(!\s+)?-([psdjgiomt])\s+// ) {
	    #
	    # Normal case of single-character
	    $invert = '!' if $1;
	    $option = $2;
	} elsif ( $input =~ s/^(!\s+)?--([^\s]+)\s*// ) {
	    $invert = '!' if $1;
	    my $opt = $option = $2;
	    fatal_error "Unrecognized iptables option ($opt}" unless $option = $aliases{$option};
	} else {
	    fatal_error "Unrecognized iptables option string ($input)";
	}

	if ( $option eq 'j' or $option eq 'g' ) {
	    $ruleref->{jump} = $jump = $option;
	    $input =~ s/([^\s]+)\s*//;
	    $ruleref->{target} = $target = $1;
	    $option = 'targetopts';
	} else {
	    $simple = 0;
	    if ( $option eq 'm' ) {
		$input =~ s/([\w-]+)\s*//;
		$option = $1;
	    }
	}

	my $params = $invert;

      PARAM:
	{
	    while ( $input ne '' && $input !~ /^(?:!|-[psdjgiomt])\s/ ) {
		last PARAM if $input =~ /^--([^\s]+)/ && $aliases{$1 || '' };
		$input =~ s/^([^\s]+)\s*//;
		my $token = $1;
		$params = $params eq '' ? $token : join( ' ' , $params, $token);
	    }

	    if ( $input =~ /^(?:!\s+--([^\s]+)|!\s+[^-])/ ) {
		last PARAM if $aliases{$1 || ''};
		$params = $params eq '' ? '!' : join( ' ' , $params, '!' );
		$input =~ s/^!\s+//;
		redo PARAM;
	    }
	}

	set_rule_option( $ruleref, $option, $params );
    }

    if ( ( $ruleref->{simple} = $simple ) && $completeref ) {
	$$completeref = 1 if $jump eq 'g' || $terminating{$target};
    }

    if ( $ruleref->{targetopts} && $targets{$target} ) {
	fatal_error "The $target target does not accept options" unless $targets{$target} & OPTIONS;
    }

    $ruleref;
}

#
#  A couple of small functions for other modules to use to manipulate rules
#
sub rule_target( $ ) {
    shift->{target};
}

sub clear_rule_target( $ ) {
    my $ruleref = shift;

    assert( reftype $ruleref , $ruleref );

    delete $ruleref->{jump};
    delete $ruleref->{targetopts};
    $ruleref->{target} = '';

    1;
}

sub set_rule_target( $$$ ) {
    my ( $ruleref, $target, $opts) = @_;

    assert( reftype $ruleref , $ruleref );

    $ruleref->{jump}     = 'j';
    $ruleref->{target}   = $target;
    $ruleref->{targetopts} = $opts if defined $opts;

    1;
}

#
# Convert an irule into iptables input
#
# First, a helper function that formats a single option
#
sub format_option( $$ ) {
    my ( $option, $value ) = @_;

    assert( ! reftype $value );

    my $rule = '';

    $value =~ s/\s*$//;

    $rule .= join( ' ' , ' -m', $option, $value );

    $rule;
}

#
# And one that 'pops' an option value
#
sub pop_match( $$ ) {
    my ( $ruleref, $option ) = @_;
    my $value = $ruleref->{$option};

    reftype $value ? shift @{$ruleref->{$option}} : $value;
}

sub clone_irule( $ );

sub format_rule( $$;$ ) {
    my ( $chainref, $rulerefp, $suppresshdr ) = @_;

    return $rulerefp->{cmd} if exists $rulerefp->{cmd};

    my $rule = $suppresshdr ? '' : "-A $chainref->{name}";
    #
    # The code the follows can be destructive of the rule so we clone it
    #
    my $ruleref = $rulerefp->{complex} ? clone_irule( $rulerefp ) : $rulerefp;
    my $nfacct  = $rulerefp->{nfacct};
    my $recent  = $rulerefp->{recent};
    my $expensive;

    for ( @{$ruleref->{matches}} ) {
	my $type = get_opttype( $_, 0 );

	next if $type & ( CONTROL | TARGET );

	if ( $type == UNIQUE ) {
	    my $value = $ruleref->{$_};

	    $rule .= ' !' if $value =~ s/^! //;

	    if ( length == 1 ) {
		$rule .= join( '' , ' -', $_, ' ', $value );
	    } else {
		$rule .= join( '' , ' --', $_, ' ', $value );
	    }

	    next;
	} elsif ( $type == EXPENSIVE ) {
	    #
	    # Only emit expensive matches now if there are '-m nfacct' or '-m recent' matches in the rule
	    #
	    if ( $nfacct || $recent ) {
		$rule .= format_option( $_, pop_match( $ruleref, $_ ) );
	    } else {
		$expensive = 1;
	    }
	} else {
	    $rule .= format_option( $_, pop_match( $ruleref, $_ ) );
	}
    }
    #
    # Emit expensive matches last unless we had '-m nfacct' or '-m recent' matches in the rule.
    #
    if ( $expensive ) {
	for ( grep( get_opttype( $_, 0 ) == EXPENSIVE, @{$ruleref->{matches}} ) ) {
	    $rule .= format_option( $_, pop_match( $ruleref, $_ ) );
	}
    }

    if ( $ruleref->{target} ) {
	$rule .= join( ' ', " -$ruleref->{jump}", $ruleref->{target} );
	$rule .= join( '', ' ', $ruleref->{targetopts} ) if $ruleref->{targetopts};
    }

    $rule .= join( '', ' -m comment --comment "', $ruleref->{comment}, '"' ) if $ruleref->{comment};

    $rule;
}

#
# Check two rules to determine if the second rule can be merged into the first.
#
sub compatible( $$ ) {
    my ( $ref1, $ref2 ) = @_;
    my ( $val1, $val2 );

    for ( @unique_options ) {
	if ( defined( $val1 = $ref1->{$_} ) && defined( $val2 = $ref2->{$_} ) ) {
	    unless ( $val1 eq $val2 ) {
		#
		# Values are different -- be sure that $val1 is a leading subset of $val2;
		#
		my @val1 = split ' ', $val1;
		my @val2 = split ' ', $val2;

		return 0 if @val1 > @val2; # $val1 is more specific than $val2

		for ( my $i = 0; $i < @val1; $i++ ) {
		    return 0 unless $val1[$i] eq $val2[$i];
		}
	    }
	}
    }
    #
    # Don't combine chains where each specifies '-m policy'
    #
    return ! ( $ref1->{policy} && $ref2->{policy} );
}

#
# Merge two rules - If the target of the merged rule is a chain, a reference to its
#                   chain table entry is returned. It is the caller's responsibility to
#                   ensure that the rules being merged are compatible.
#
#                   It is also the caller's responsibility to handle reference counting.
#                   If the target is a builtin, '' is returned.
#
sub merge_rules( $$$ ) {
    my ( $tableref, $toref, $fromref ) = @_;

    my $target = $fromref->{target};

    for my $option ( @unique_options ) {
	if ( exists $fromref->{$option} ) {
	    push( @{$toref->{matches}}, $option ) unless exists $toref->{$option};
	    $toref->{$option} = $fromref->{$option};
	}
    }

    for my $option ( grep ! $opttype{$_} || $_ eq 'nfacct' || $_ eq 'recent', sort { $b cmp $a } keys %$fromref ) {
	set_rule_option( $toref, $option, $fromref->{$option} );
    }

    unless ( $toref->{state} ) {
	set_rule_option ( $toref, 'state',   $fromref->{state} ) if $fromref->{state};
    }

    unless ( $toref->{'conntrack --ctstate'} ) {
	set_rule_option( $toref,
			 'conntrack --ctstate',
			 $fromref->{'conntrack --ctstate'} ) if $fromref->{'conntrack --ctstate'};
    }

    set_rule_option( $toref, 'policy', $fromref->{policy} ) if exists $fromref->{policy};

    for my $option ( grep( get_opttype( $_, 0 ) == EXPENSIVE, sort keys %$fromref ) ) {
	set_rule_option( $toref, $option, $fromref->{$option} );
    }

    unless ( $toref->{comment} ) {
	$toref->{comment} = $fromref->{comment} if exists $fromref->{comment};
    }

    $toref->{target} = $target;

    if ( my $targetref = $tableref->{$target} ) {
	return $targetref;
    } else {
	$toref->{targetopts} = $fromref->{targetopts} if $fromref->{targetopts};
	$toref->{jump}       = 'j';
	return '';
    }
}

#
# Trace a change to the chain table
#
sub trace( $$$$ ) {
    my ($chainref, $action, $rulenum, $message) = @_;

    my $heading = $rulenum ?
	sprintf "                NF-(%s)-> %s:%s:%d", $action, $chainref->{table}, $chainref->{name}, $rulenum :
	sprintf "                NF-(%s)-> %s:%s", $action, $chainref->{table}, $chainref->{name};

    my $length = length $heading;

    $message = format_rule( $chainref, $message ) if reftype $message;

    if ( $length < 48 ) {
	print $heading . ' ' x ( 48 - $length) . "$message\n";
    } else {
	print $heading . ' ' x 8 * ( ( $length + 8 ) / 8 ) . "$message\n";
    }
}

#
# Add run-time commands to a chain. Arguments are:
#
#    Chain reference , Command, ...
#
sub add_commands ( $$;@ ) {
    my $chainref    = shift @_;

    if ( $debug ) {
	my $rulenum = @{$chainref->{rules}};
	trace( $chainref, 'T', ++$rulenum, "$_\n" ) for @_;
    }

    push @{$chainref->{rules}}, { mode     => CMD_MODE,
				  cmd      => $_ ,
				  cmdlevel => $chainref->{cmdlevel} ,
				  target   => '', # Insure that all rules have a target
				} for @_;

    $chainref->{referenced} = 1;
    $chainref->{optflags} |= ( DONT_OPTIMIZE | DONT_MOVE );
}

#
# Transform the passed rule and add it to the end of the passed chain's rule list.
#
sub push_rule( $$ ) {
    my $chainref = $_[0];

    return $dummyrule if $chainref->{complete};

    my $complete = 0;
    my $ruleref  = transform_rule( $_[1], $complete );

    $ruleref->{comment} = shortlineinfo($chainref->{origin}) || $comment;
    $ruleref->{mode}    = CMD_MODE if $ruleref->{cmdlevel} = $chainref->{cmdlevel};

    push @{$chainref->{rules}}, $ruleref;
    $chainref->{referenced} = 1;
    $chainref->{optflags} |= RETURNS_DONT_MOVE if ( $ruleref->{target} || '' ) eq 'RETURN';
    trace( $chainref, 'A', @{$chainref->{rules}}, "-A $chainref->{name} $_[1] $ruleref->{comment}" ) if $debug;

    $chainref->{complete} = 1 if $complete;

    $ruleref;
}

#
# Add a Transformed rule
#
sub add_trule( $$ ) {
    my ( $chainref, $ruleref ) = @_;

    assert( reftype $ruleref , $ruleref );
    push @{$chainref->{rules}}, $ruleref;
    $chainref->{referenced} = 1;
    $chainref->{optflags} |= RETURNS_DONT_MOVE if ( $ruleref->{target} || '' ) eq 'RETURN';

    trace( $chainref, 'A', @{$chainref->{rules}}, format_rule( $chainref, $ruleref ) ) if $debug;

    $ruleref;
}

#
# Return the number of ports represented by the passed list
#
sub port_count( $ ) {
    ( $_[0] =~ tr/,:/,:/ ) + 1;
}

#
# Post-process a rule having a port list. Split the rule into multiple rules if necessary
# to work within the 15-element limit imposed by iptables/Netfilter.
#
# The third argument ($dport) indicates what type of list we are spltting:
#
#      $dport == 1     Destination port list
#      $dport == 0     Source port list
#
# When expanding a Destination port list, each resulting rule is checked for the presence
# of a Source port list; if one is present, the function calls itself recursively with
# $dport == 0.
#
# The function calls itself recursively so we need a prototype.
#
sub handle_port_list( $$$$$$ );

sub handle_port_list( $$$$$$ ) {
    my ($chainref, $rule, $dport, $first, $ports, $rest) = @_;

    our $splitcount;

    if ( port_count( $ports ) > 15 ) {
	#
	# More than 15 ports specified
	#
	my @ports = split '([,:])', $ports;

	while ( @ports ) {
	    my $count = 0;
	    my $newports = '';

	    while ( @ports && $count < 15 ) {
		my ($port, $separator) = ( shift @ports, shift @ports );

		$separator ||= '';

		if ( ++$count == 15 ) {
		    if ( $separator eq ':' ) {
			unshift @ports, $port, ':';
			chop $newports;
			last;
		    } else {
			$newports .= $port;
		    }
		} else {
		    $newports .= "${port}${separator}";
		}
	    }

	    my $newrule = join( '', $first, $newports, $rest );

	    if ( $dport && $newrule =~  /^(.* --sports\s+)([^ ]+)(.*)$/ ) {
		handle_port_list( $chainref, $newrule, 0, $1, $2, $3 );
	    } else {
		push_rule ( $chainref, $newrule );
		$splitcount++;
	    }
	}
    } elsif ( $dport && $rule =~  /^(.* --sports\s+)([^ ]+)(.*)$/ ) {
	handle_port_list( $chainref, $rule, 0, $1, $2, $3 );
    } else {
	push_rule ( $chainref, $rule );
	$splitcount++;
    }
}

#
# This much simpler function splits a rule with an icmp type list into discrete rules
#
sub handle_icmptype_list( $$$$ ) {
    my ($chainref, $first, $types, $rest) = @_;
    my @ports = split ',', $types;
    our $splitcount;
    push_rule ( $chainref, join ( '', $first, shift @ports, $rest ) ), $splitcount++ while @ports;
}

#
# Add a rule to a chain. Arguments are:
#
#    Chain reference , Rule [, Expand-long-port-lists ]
#
sub add_rule($$;$) {
    my ($chainref, $rule, $expandports) = @_;

    our $splitcount;

    assert( ! reftype $rule , $rule );

    return $dummyrule if $chainref->{complete};

    $iprangematch = 0;
    #
    # Pre-processing the port lists as was done in Shorewall-shell results in port-list
    # processing driving the rest of rule generation.
    #
    # By post-processing each rule generated by expand_rule(), we avoid all of that
    # messiness and replace it with the following localized messiness.

    if ( $expandports ) {
	if ( $rule =~  /^(.* --dports\s+)([^ ]+)(.*)$/ ) {
	    #
	    # Rule has a --dports specification
	    #
	    handle_port_list( $chainref, $rule, 1, $1, $2, $3 )
	} elsif ( $rule =~  /^(.* --sports\s+)([^ ]+)(.*)$/ ) {
	    #
	    # Rule has a --sports specification
	    #
	    handle_port_list( $chainref, $rule, 0, $1, $2, $3 )
	} elsif ( $rule =~  /^(.* --ports\s+)([^ ]+)(.*)$/ ) {
	    #
	    # Rule has a --ports specification
	    #
	    handle_port_list( $chainref, $rule, 0, $1, $2, $3 )
	} elsif ( $rule =~ /^(.* --icmp(?:v6)?-type\s*)([^ ]+)(.*)$/ ) {
	    #
	    # ICMP rule -- split it up if necessary
	    #
	    my ( $first, $types, $rest ) = ($1, $2, $3 );

	    if ( $types =~ /,/ ) {
		handle_icmptype_list( $chainref, $first, $types, $rest );
	    } else {
		push_rule( $chainref, $rule );
		$splitcount++;
	    }
	} else {
	    push_rule ( $chainref, $rule );
	    $splitcount++;
	}
    } else {
	push_rule( $chainref, $rule );
    }
}

#
# New add_rule implementation
#
sub push_matches {

    my $ruleref = shift;
    my $dont_optimize = 0;

    while ( @_ ) {
	my ( $option, $value ) = ( shift, shift );

	assert( defined $value && ! reftype $value );

	if ( exists $ruleref->{$option} ) {
	    my $curvalue = $ruleref->{$option};
	    if ( $globals{KLUDGEFREE} ) {
		$ruleref->{$option} = [ $curvalue ] unless reftype $curvalue;
		push @{$ruleref->{$option}}, reftype $value ? @$value : $value;
		push @{$ruleref->{matches}}, $option;
		$ruleref->{complex} = 1;
	    } else {
		$ruleref->{$option} = join( '', $curvalue, $value );
	    }
	} else {
	    $ruleref->{$option} = $value;
	    $dont_optimize ||= $option =~ /^[piosd]$/ && $value =~ /^!/;
	    push @{$ruleref->{matches}}, $option;
	}

    }

    DONT_OPTIMIZE if $dont_optimize;
}

sub push_irule( $$ ) {
    my ( $chainref, $ruleref ) = @_;

    push @{$chainref->{rules}}, $ruleref;

    trace( $chainref, 'A', @{$chainref->{rules}}, format_rule( $chainref, $ruleref ) ) if $debug;

    $ruleref;
}

sub create_irule( $$$;@ ) {
    my ( $chainref, $jump, $target, @matches ) = @_;

    ( $target, my $targetopts ) = split ' ', $target, 2;

    my $ruleref       = { matches => [] };

    $ruleref->{mode} = ( $ruleref->{cmdlevel} = $chainref->{cmdlevel} ) ? CMD_MODE : CAT_MODE;

    if ( $jump ) {
	$ruleref->{jump}       = $jump;
	$ruleref->{target}     = $target;
	$chainref->{optflags} |= RETURNS_DONT_MOVE if $target eq 'RETURN';
	$ruleref->{targetopts} = $targetopts if $targetopts;
    } else {
	$ruleref->{target} = '';
    }

    $ruleref->{comment} = shortlineinfo($chainref->{origin}) || $ruleref->{comment} || $comment;

    $iprangematch = 0;

    $chainref->{referenced} = 1;

    unless ( $ruleref->{simple} = ! @matches ) {
	$chainref->{optflags} |= push_matches( $ruleref, @matches );
    }

    $ruleref;
}

#
# Clone an existing rule. Only the rule hash itself is cloned; reference values are shared between the new rule
# reference and the old.
#
sub clone_irule( $ ) {
    my $oldruleref = $_[0];
    my $newruleref = {};

    while ( my ( $key, $value ) = each %$oldruleref ) {
	if ( reftype $value ) {
	    my @array = @$value;
	    $newruleref->{$key} = \@array;
	} else {
	    $newruleref->{$key} = $value;
	}
    }

    $newruleref;
}

sub handle_port_ilist( $$$ );

sub handle_port_ilist( $$$ ) {
    my ($chainref, $ruleref, $dport) = @_;

    our $splitcount;

    my $ports = $ruleref->{$dport ? 'dports' : 'sports'};

    if ( $ports && port_count( $ports ) > 15 ) {
	#
	# More than 15 ports specified
	#
	my @ports = split '([,:])', $ports;

	while ( @ports ) {
	    my $count = 0;
	    my $newports = '';

	    while ( @ports && $count < 15 ) {
		my ($port, $separator) = ( shift @ports, shift @ports );

		$separator ||= '';

		if ( ++$count == 15 ) {
		    if ( $separator eq ':' ) {
			unshift @ports, $port, ':';
			chop $newports;
			last;
		    } else {
			$newports .= $port;
		    }
		} else {
		    $newports .= "${port}${separator}";
		}
	    }

	    my $newruleref = clone_irule( $ruleref );

	    $newruleref->{$dport} = $newports;

	    if ( $dport ) {
		handle_port_ilist( $chainref, $newruleref, 0 );
	    } else {
		push_irule( $chainref, $newruleref );
		$splitcount++;
	    }
	}
    } elsif ( $dport ) {
	handle_port_ilist( $chainref, $ruleref, 0 );
    } else {
	push_irule ( $chainref, $ruleref );
	$splitcount++;
    }
}

#
# Compare two rule hash values. If a value is a reference, then it will be an array reference
#
sub compare_values( $$ ) {
    my ( $value1, $value2 ) = @_;

    return $value1 eq $value2 unless reftype $value1;

    if ( reftype $value2 && @$value1 == @$value2 ) {
	my $offset = 0;
	for ( @$value1 ) {
	    return 0 unless $_ eq $value2->[$offset++];
	}

	1;
    }
}

sub add_irule( $;@ ) {
    my ( $chainref, @matches ) = @_;

    push_irule( $chainref, create_irule( $chainref, '' => '', @matches ) );

}

#
# Make the first chain a referent of the second
#
sub add_reference ( $$ ) {
    my ( $fromref, $to ) = @_;

    my $toref = reftype $to ? $to : $chain_table{$fromref->{table}}{$to};

    assert($toref);

    $toref->{blacklistsection} ||= $fromref->{blacklistsection};

    $toref->{references}{$fromref->{name}}++;
}

#
# Delete a previously added reference
#
sub delete_reference( $$ ) {
    my ( $fromref, $to ) = @_;

    my $toref = reftype $to ? $to : $chain_table{$fromref->{table}}{$to};

    assert( $toref );

    delete $toref->{references}{$fromref->{name}} unless --$toref->{references}{$fromref->{name}} > 0;
}

#
# Insert a rule into a chain. Arguments are:
#
#    Chain reference , Rule Number, Rule
#
# In the first function, the rule number is zero-relative. In the second function,
# the rule number is one-relative.
#
sub insert_rule1($$$)
{
    my ($chainref, $number, $rule) = @_;

    my $ruleref = transform_rule( $rule );

    $ruleref->{comment} = shortlineinfo($chainref->{origin}) || $comment;

    assert( ! ( $ruleref->{cmdlevel} = $chainref->{cmdlevel}) , $chainref->{name} );
    $ruleref->{mode} = CAT_MODE;

    splice( @{$chainref->{rules}}, $number, 0, $ruleref );

    trace( $chainref, 'I', ++$number, $ruleref ) if $debug;

    $iprangematch = 0;

    $chainref->{referenced} = 1;

    $ruleref;
}

sub insert_rule($$$) {
    my ($chainref, $number, $rule) = @_;

    insert_rule1( $chainref, $number - 1, $rule );
}

sub insert_irule( $$$$;@ ) {
    my ( $chainref, $jump, $target, $number, @matches ) = @_;

    my $rulesref = $chainref->{rules};
    my $ruleref  = {};

    $ruleref->{mode} = ( $ruleref->{cmdlevel} = $chainref->{cmdlevel} ) ? CMD_MODE : CAT_MODE;

    if ( $jump ) {
	$jump = 'j' if $jump eq 'g' && ! have_capability 'GOTO_TARGET';
	( $target, my $targetopts ) = split ' ', $target, 2;
	$ruleref->{jump}       = $jump;
	$ruleref->{target}     = $target;
	$ruleref->{targetopts} = $targetopts if $targetopts;
    }

    unless ( $ruleref->{simple} = ! @matches ) {
	$chainref->{optflags} |= push_matches( $ruleref, @matches );
    }

    
    $ruleref->{comment} = shortlineinfo( $chainref->{origin} ) || $ruleref->{comment} || $comment;

    if ( $number >= @$rulesref ) {
	#
	# Avoid failure in spice if we insert beyond the end of the chain
	#
	$number = @$rulesref;
	push @$rulesref, $ruleref;
    } else {
	splice( @$rulesref, $number, 0, $ruleref );
    }

    trace( $chainref, 'I', ++$number, format_rule( $chainref, $ruleref ) ) if $debug;

    $iprangematch = 0;

    $chainref->{referenced} = 1;

    $ruleref;
}

# Do final work to 'delete' a chain. We leave it in the chain table but clear
# the 'referenced', 'rules', and 'references' members.
#
sub delete_chain( $ ) {
    my $chainref = shift;

    $chainref->{referenced}  = 0;
    $chainref->{rules}       = [];
    $chainref->{references}  = {};
    trace( $chainref, 'X', undef, '' ) if $debug;
    progress_message "  Chain $chainref->{name} deleted";
}

#
# This variety first deletes all references to the chain before deleting it.
#
sub delete_chain_and_references( $ ) {
    my $chainref = shift;
    #
    #  We're going to delete this chain but first, we must delete all references to it.
    #
    my $tableref = $chain_table{$chainref->{table}};
    my $name     = $chainref->{name};

    while ( my ( $chain, $references ) = each %{$chainref->{references}} ) {
	#
	# Delete all rules from $chain that have $name as their target
	#
	my $chain1ref = $tableref->{$chain};
	$chain1ref->{rules} = [ grep ( ( $_->{target} || '' ) ne $name, @{$chain1ref->{rules}} ) ];
    }
    #
    # Now decrement the reference count of all targets of this chain's rules
    #
    for ( grep $_, ( map( $_->{target}, @{$chainref->{rules}} ) ) ) {
	decrement_reference_count( $tableref->{$_}, $name );
    }

    delete_chain $chainref;
}

#
# Insert a tunnel rule into the passed chain. Tunnel rules are inserted sequentially
# at the beginning of the 'NEW' section.
#
sub add_tunnel_rule ( $;@ ) {
    my $chainref = shift;

    insert_irule( $chainref, j => 'ACCEPT', $chainref->{new}++, @_ );
}

#
# Adjust reference counts after moving a rule from $name1 to $name2
#
sub adjust_reference_counts( $$$ ) {
    my ($toref, $name1, $name2) = @_;

    if ( $toref ) {
	delete $toref->{references}{$name1} unless --$toref->{references}{$name1} > 0;
	$toref->{references}{$name2}++;
    }
}

#
# Adjust reference counts after copying a jump with target $toref to chain $chain
#
sub increment_reference_count( $$ ) {
    my ($toref, $chain) = @_;

    $toref->{references}{$chain}++ if $toref;
}

sub decrement_reference_count( $$ ) {
    my ($toref, $chain) = @_;

    if ( $toref && $toref->{referenced} ) {
	assert($toref->{references}{$chain} > 0 , $toref, $chain );
	delete $toref->{references}{$chain}    unless --$toref->{references}{$chain};
	delete_chain_and_references ( $toref ) unless ( keys %{$toref->{references}} );
    }
}

#
# Move the rules from one chain to another
#
# The rules generated by interface options are added to the interfaces's input chain and
# forward chain. Shorewall::Rules::generate_matrix() may decide to move those rules to
# the head of a rules chain.
#
sub move_rules( $$ ) {
    my ($chain1, $chain2 ) = @_;

    if ( $chain1->{referenced} ) {
	my $name1     = $chain1->{name};
	my $name2     = $chain2->{name};
	my $rules     = $chain2->{rules};
	my $count     = @{$chain1->{rules}};
	my $tableref  = $chain_table{$chain1->{table}};
	my $filtered;
	my $filtered1 = $chain1->{filtered};
	my $filtered2 = $chain2->{filtered};
	my @filtered1;
	my @filtered2;
	my $rule;
	#
	# We allow '+' in chain names and '+' is an RE meta-character. Escape it.
	#
	for ( @{$chain1->{rules}} ) {
	    adjust_reference_counts( $tableref->{$_->{target}}, $name1, $name2 ) if $_->{target};
	}
	#
	# We set aside the filtered rules for the time being
	#
	$filtered = $filtered1;

	push @filtered1 , shift @{$chain1->{rules}} while $filtered--;

	$chain1->{filtered} = 0;

	$filtered = $filtered2;
	push @filtered2 , shift @{$chain2->{rules}} while $filtered--;

	if ( $debug ) {
	    my $rule = $filtered2;
	    trace( $chain2, 'A', ++$rule, $_ ) for @{$chain1->{rules}};
	}

	unshift @$rules, @{$chain1->{rules}};

	$chain2->{referenced} = 1;

	#
	# In a firewall->x policy chain, multiple DHCP ACCEPT rules can be moved to the head of the chain.
	# This hack avoids that.
	#
	shift @{$rules} while @{$rules} > 1 && $rules->[0]{dhcp} && $rules->[1]{dhcp};
	#
	# Now insert the filter rules at the head of the chain
	#

	if ( $filtered1 ) {
	    if ( $debug ) {
		$rule = $filtered2;
		$filtered = 0;
		trace( $chain2, 'I', ++$rule, $filtered1[$filtered++] ) while $filtered < $filtered1;
	    }

	    splice @{$rules}, 0, 0, @filtered1;
	}

	#
	# Restore the filters originally in chain2 but drop duplicates of those from $chain1
	#
      FILTER:
	while ( @filtered2 ) {
	    $filtered = pop @filtered2;

	    for ( $rule = 0; $rule < $filtered1; $rule++ ) {
		$filtered2--, next FILTER if ${$rules}[$rule] eq $filtered;
	    }

	    unshift @{$rules}, $filtered;
	}

	$chain2->{filtered} = $filtered1 + $filtered2;

	delete_chain $chain1;

	$count;
    }
}

#
# Replace the jump at the end of one chain (chain2) with the rules from another chain (chain1).
#
sub copy_rules( $$;$ ) {
    my ($chain1, $chain2, $nojump ) = @_;

    my $name1      = $chain1->{name};
    my $name       = $name1;
    my $name2      = $chain2->{name};
    my @rules1     = @{$chain1->{rules}};
    my $rules2     = $chain2->{rules};
    my $count      = @{$chain1->{rules}};
    my $tableref   = $chain_table{$chain1->{table}};
    #
    # We allow '+' in chain names and '+' is an RE meta-character. Escape it.
    #
    pop @$rules2 unless $nojump; # Delete the jump to chain1
    #
    # Chain2 is now a referent of all of Chain1's targets
    #
    for ( @rules1 ) {
	increment_reference_count( $tableref->{$_->{target}}, $name2 ) if $_->{target};
    }

    if ( $debug ) {
	my $rule = @$rules2;
	trace( $chain2, 'A', ++$rule, $_ ) for @rules1;
    }

    push @$rules2, @rules1;

    progress_message "  $count rules from $chain1->{name} appended to $chain2->{name}" if $count;

    unless ( $nojump || --$chain1->{references}{$name2} ) {
	delete $chain1->{references}{$name2};
	delete_chain_and_references( $chain1 ) unless keys %{$chain1->{references}};
    }
}

#
# Name of canonical chain between an ordered pair of zones
#
sub rules_chain ($$) {
    my $name = join "$config{ZONE2ZONE}", @_;
    $renamed{$name} || $name;
}

#
# Name of the blacklist chain between an ordered pair of zones
#
sub blacklist_chain($$) {
    &rules_chain(@_) . '~';
}

#
# Name of the established chain between an ordered pair of zones
#
sub established_chain($$) {
    '^' . &rules_chain(@_)
}

#
# Name of the related chain between an ordered pair of zones
#
sub related_chain($$) {
    '+' . &rules_chain(@_);
}

#
# Name of the invalid chain between an ordered pair of zones
#
sub invalid_chain($$) {
    '_' . &rules_chain(@_);
}

#
# Name of the untracked chain between an ordered pair of zones
#
sub untracked_chain($$) {
    '&' . &rules_chain(@_);
}

#
# Create the base for a chain involving the passed interface -- we make this a function so it will be
# easy to change the mapping should the need ever arrive.
#
sub chain_base( $ ) {
    $_[0];
}

#
# Forward Chain for an interface
#
sub forward_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_fwd';
}

#
# Forward Chain for a zone
#
sub zone_forward_chain($) {
    $_[0] . '_frwd';
}

#
# Returns true if we're to use the interface's forward chain
#
sub use_forward_chain($$) {
    my ( $interface, $chainref ) = @_;
    my @loopback_zones = loopback_zones;

    return 0 if $interface eq loopback_interface && ! @loopback_zones;

    my $interfaceref = find_interface($interface);
    my $nets = $interfaceref->{nets};

    return 1 if @{$chainref->{rules}} && ( $config{OPTIMIZE} & OPTIMIZE_USE_FIRST );
    #
    # Use it if we already have jumps to it
    #
    return 1 if keys %{$chainref->{references}};
    #
    # We must use the interfaces's chain if the interface is associated with multiple zones
    #
    return 1 if ( keys %{interface_zones $interface} ) > 1;
    #
    # Use interface's chain if there are multiple nets on the interface
    #
    return 1 if $nets > 1;
    #
    # Use interface's chain if it is a bridge with ports
    #
    return 1 if $interfaceref->{ports};

    my $zone = $interfaceref->{zone};

    return 1 unless $zone;
    #
    # Interface associated with a single zone -- Must use the interface chain if
    #                                            the zone has  multiple interfaces
    #                                            and this interface has option rules
    $interfaceref->{options}{use_forward_chain} && keys %{ zone_interfaces( $zone ) } > 1;
}

#
# Input Option Chain for an interface
#
sub input_option_chain($) {
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_iop';
}

#
# Output Option Chain for an interface
#
sub output_option_chain($) {
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_oop';
}

#
# Forward Option Chain for an interface
#
sub forward_option_chain($) {
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_fop';
}

#
# Input Chain for an interface
#
sub input_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_in';
}

#
# Input Chain for a zone
#
sub zone_input_chain($) {
    $_[0] . '_input';
}

#
# Returns true if we're to use the interface's input chain
#
sub use_input_chain($$) {
    my ( $interface, $chainref ) = @_;
    my $interfaceref = find_interface($interface);
    my $nets = $interfaceref->{nets};

    return 1 if @{$chainref->{rules}} && ( $config{OPTIMIZE} & OPTIMIZE_USE_FIRST );
    #
    # We must use the interfaces's chain if the interface is associated with multiple Zones
    #
    return 1 if ( keys %{interface_zones $interface} ) > 1;
    #
    # Use interface's chain if there are multiple nets on the interface
    #
    return 1 if $nets > 1;
    #
    # Use interface's chain if it is a bridge with ports
    #
    return 1 if $interfaceref->{ports};
    #
    # Don't need it if it isn't associated with any zone
    #
    return 0 unless $nets;

    my $zone = $interfaceref->{zone};

    return 1 unless $zone;
    #
    # Interface associated with a single zone -- Must use the interface chain if
    #                                            the zone has  multiple interfaces
    #                                            and this interface has option rules
    #
    return 1 if $interfaceref->{options}{use_input_chain} && keys %{ zone_interfaces( $zone ) } > 1;
    #
    # Interface associated with a single zone -- use the zone's input chain if it has one
    #
    return 0 if $chainref;
    #
    # Use the <zone>->fw rules chain if it is referenced.
    #
    $chainref = $filter_table->{rules_chain( $zone, firewall_zone )};

    ! ( $chainref->{referenced} || $chainref->{is_policy} )
}

#
# Output Chain for an interface
#
sub output_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_out';
}

#
# Prerouting Chain for an interface
#
sub prerouting_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_pre';
}

#
# Postouting Chain for an interface
#
sub postrouting_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_post';
}

#
# Output Chain for a zone
#
sub zone_output_chain($) {
    $_[0] . '_output';
}

#
# Returns true if we're to use the interface's output chain
#
sub use_output_chain($$) {
    my ( $interface, $chainref)  = @_;
    my $interfaceref = find_interface($interface);
    my $nets = $interfaceref->{nets};

    return 1 if @{$chainref->{rules}} && ( $config{OPTIMIZE} & OPTIMIZE_USE_FIRST );
    #
    # We must use the interfaces's chain if the interface is associated with multiple Zones
    #
    return 1 if ( keys %{interface_zones $interface} ) > 1;
    #
    # Use interface's chain if there are multiple nets on the interface
    #
    return 1 if $nets > 1;
    #
    # Use interface's chain if it is a bridge with ports
    #
    return 1 if $interfaceref->{ports};
    #
    # Don't need it if it isn't associated with any zone
    #
    return 0 unless $nets;
    #
    # Interface associated with a single zone -- use the zone's output chain if it has one
    #
    return 0 if $chainref;
    #
    # Use the fw-><zone> rules chain if it is referenced.
    #
    $chainref = $filter_table->{rules_chain( firewall_zone , $interfaceref->{zone} )};

    ! ( $chainref->{referenced} || $chainref->{is_policy} )
}

#
# Masquerade Chain for an interface
#
sub masq_chain($)
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_masq';
}

#
# Syn_flood_chain -- differs from the other _chain functions in that the argument is a chain table reference
#
sub syn_flood_chain ( $ ) {
    '@' . $_[0]->{synchain};
}

#
# MAC Verification Chain for an interface
#
sub mac_chain( $ )
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_mac';
}

sub macrecent_target($)
{
     $config{MACLIST_TTL} ? $_[0] . '_rec' : 'RETURN';
}

#
# DNAT Chain from a zone
#
sub dnat_chain( $ )
{
    $_[0] . '_dnat';
}

#
# Notrack Chain from a zone
#
sub notrack_chain( $ )
{
    $_[0] . '_ctrk';
}

#
# Load Chain for a provider
#
sub load_chain( $ ) {
    '~' . $_[0];
}

#
# SNAT Chain to an interface
#
sub snat_chain( $ )
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_snat';
}

#
# ECN Chain to an interface
#
sub ecn_chain( $ )
{
    my $interface = shift;
    ( $config{USE_PHYSICAL_NAMES} ? chain_base( get_physical( $interface ) ) : $interface ) . '_ecn';
}

#
# First chains for an interface
#
sub first_chains( $ ) #$1 = interface
{
    my $c = $_[0];

    ( forward_chain( $c ), input_chain( $c ) );
}

#
# Option chains for an interface
#
sub option_chains( $ ) #$1 = interface
{
    my $c = $_[0];

    ( forward_option_chain( $c ), input_option_chain( $c ) );
}

#
# Returns true if the passed name is that of a Shorewall-generated chain
#
sub reserved_name( $ ) {
    my $chain = shift;

    $builtin_target{$chain} || $config_files{$chain} || $chain =~ /^account(?:fwd|in|ing|out)$/;
}

#
# Create a new chain and return a reference to it.
#
sub new_chain($$)
{
    my ($table, $chain) = @_;

    assert( $chain_table{$table} && ! ( $chain_table{$table}{$chain} || $builtin_target{ $chain } ) );

    my $chainref = { name           => $chain,
		     rules          => [],
		     table          => $table,
		     loglevel       => '',
		     log            => 1,
		     cmdlevel       => 0,
		     references     => {},
		     filtered       => 0,
		     optflags       => 0,
		   };

    trace( $chainref, 'N', undef, '' ) if $debug;

    $chain_table{$table}{$chain} = $chainref;
}

#
# Find a chain
#
sub find_chain($$) {
    my ($table, $chain) = @_;

    assert( $table && $chain && $chain_table{$table} );

    $chain_table{$table}{$chain};
}

#
# Create a chain if it doesn't exist already
#
sub ensure_chain($$)
{
    &find_chain( @_ ) || &new_chain( @_ );
}

#
# Add a jump from the chain represented by the reference in the first argument to
# the target in the second argument. The third argument determines if a GOTO may be
# used rather than a jump. The optional fourth argument specifies any matches to be
# included in the rule and must end with a space character if it is non-null. The
# optional 5th argument causes long port lists to be split. The optional 6th
# argument, if passed, gives the 0-relative index where the jump is to be inserted.
#
sub add_jump( $$$;$$$ ) {
    my ( $fromref, $to, $goto_ok, $predicate, $expandports, $index ) = @_;

    return $dummyrule if $fromref->{complete};

    $predicate |= '';

    my $toref;
    #
    # The second argument may be a scalar (chain name or builtin target) or a chain reference
    #
    if ( reftype $to ) {
	$toref = $to;
	$to    = $toref->{name};
    } else {
	#
	# Ensure that we have the chain unless it is a builtin like 'ACCEPT'
	#
	my ( $target ) = split ' ', $to;
	$toref = $chain_table{$fromref->{table}}{$target};
	fatal_error "Unknown rule target ($to)" unless $toref || $builtin_target{$target};
    }

    #
    # If the destination is a chain, mark it referenced
    #
    $toref->{referenced} = 1, add_reference( $fromref, $toref ) if $toref;

    my $param = $goto_ok && $toref && have_capability( 'GOTO_TARGET' ) ? 'g' : 'j';

    $fromref->{optflags} |= DONT_OPTIMIZE if $predicate =~ /! -[piosd] /;

    if ( defined $index ) {
	assert( ! $expandports );
	insert_rule1( $fromref, $index, join( '', $predicate, "-$param $to" ));
    } else {
	add_rule ($fromref, join( '', $predicate, "-$param $to" ), $expandports || 0 );
    }
}

#
# This function is used by expand_rule() to generate jumps that require splitting long port lists
#
# The global $splitcount is incremented each time that a rule is inserted in the split path.
# Rules in excess of the minimum (1) are accounted for here.
#
sub add_expanded_jump( $$$$ ) {
    my ( $chainref, $toref, $goto, $rule ) = @_;
    return $dummyrule if $chainref->{complete};
    our $splitcount = 0;
    add_jump( $chainref, $toref, $goto, $rule, 1 );
    add_reference( $chainref, $toref ) while --$splitcount > 0;
}

sub add_ijump_internal( $$$$;@ ) {
    my ( $fromref, $jump, $to, $expandports, @matches ) = @_;

    return $dummyrule if $fromref->{complete};

    our $splitcount;

    my $toref;
    my $ruleref;
    #
    # The second argument may be a scalar (chain name or builtin target) or a chain reference
    #
    if ( reftype $to ) {
	$toref = $to;
	$to    = $toref->{name};
    } else {
	#
	# Ensure that we have the chain unless it is a builtin like 'ACCEPT'
	#
	my ( $target ) = split ' ', $to;
	$toref = $chain_table{$fromref->{table}}{$target};
	fatal_error "Unknown rule target ($to)" unless $toref || $builtin_target{$target};
    }

    #
    # If the destination is a chain, mark it referenced
    #
    if ( $toref ) {
	$toref->{referenced} = 1;
	add_reference $fromref, $toref;
	$jump = 'j' unless have_capability 'GOTO_TARGET';
	$ruleref = create_irule ($fromref, $jump => $to, @matches );
    } else {
	$ruleref = create_irule( $fromref, 'j' => $to, @matches );
    }

    if ( $ruleref->{simple} ) {
	$fromref->{complete} = 1 if $jump eq 'g' || $terminating{$to};
    }

    $expandports ? handle_port_ilist( $fromref, $ruleref, 1 ) : push_irule( $fromref, $ruleref );
}

sub add_ijump( $$$;@ ) {
    my ( $fromref, $jump, $to, @matches ) = @_;
    add_ijump_internal( $fromref, $jump, $to, 0, @matches );
}

sub insert_ijump( $$$$;@ ) {
    my ( $fromref, $jump, $to, $index, @matches ) = @_;

    my $toref;
    #
    # The second argument may be a scalar (chain name or builtin target) or a chain reference
    #
    if ( reftype $to ) {
	$toref = $to;
	$to    = $toref->{name};
    } else {
	#
	# Ensure that we have the chain unless it is a builtin like 'ACCEPT'
	#
	$toref = ensure_chain( $fromref->{table} , $to ) unless $builtin_target{$to} || $to =~ / --/; #If the target has options, it must be a builtin.
    }

    #
    # If the destination is a chain, mark it referenced
    #
    if ( $toref ) {
	$toref->{referenced} = 1;
	add_reference $fromref, $toref;
	$jump = 'j' unless have_capability 'GOTO_TARGET';
	insert_irule ($fromref, $jump => $to, $index, @matches );
    } else {
	insert_irule( $fromref, 'j' => $to, $index, @matches );
    }
}

#
# Delete jumps previously added via add_ijump. If the target chain is empty, reset its
# referenced flag
#
sub delete_jumps ( $$ ) {
    my ( $fromref, $toref ) = @_;
    my $to    = $toref->{name};
    my $from  = $fromref->{name};
    my $rules = $fromref->{rules};
    my $refs  = $toref->{references}{$from};

    #
    # The 'from' chain may have had no references and has been deleted already so
    # we need to check
    #
    if ( $fromref->{referenced} ) {
	#
	#
	# A C-style for-loop with indexing seems to work best here, given that we are
	# deleting elements from the array over which we are iterating.
	#
	for ( my $rule = 0; $rule <= $#{$rules}; $rule++ ) {
	    if (  $rules->[$rule]->{target} eq $to ) {
		trace( $fromref, 'D', $rule + 1, $rules->[$rule] ) if $debug;
		splice(  @$rules, $rule, 1 );
		last unless --$refs > 0;
		$rule--;
	    }
	}

	assert( ! $refs , $from, $to );
    }

    delete $toref->{references}{$from};

    unless ( @{$toref->{rules}} ) {
	$toref->{referenced} = 0;
	trace ( $toref, 'X', undef, '' ) if $debug;
    }
}

sub reset_optflags( $$ ) {
    my ( $chain, $flags ) = @_;

    my $chainref = reftype $chain ? $chain : $filter_table->{$chain};

    $chainref->{optflags} ^= ( $flags & $chainref->{optflags} );

    trace( $chainref, "O${flags}", undef, '' ) if $debug;

    $chainref;
}

sub set_optflags( $$ ) {
    my ( $chain, $flags ) = @_;

    my $chainref = reftype $chain ? $chain : $filter_table->{$chain};

    $chainref->{optflags} |= $flags;

    trace( $chainref, "!O${flags}", undef, '' ) if $debug;

    $chainref;
}

#
# Return true if the passed chain has a RETURN rule.
#

sub has_return( $ ) {
    $_[0]->{optflags} & RETURNS;
}

#
# Reset the dont_optimize flag for a chain
#
sub allow_optimize( $ ) {
    reset_optflags( shift, DONT_OPTIMIZE );
}

#
# Reset the dont_delete flags for a chain
#
sub allow_delete( $ ) {
    reset_optflags( shift, DONT_DELETE );
}

#
# Reset the dont_move flag for a chain
#
sub allow_move( $ ) {
    reset_optflags( shift, DONT_MOVE );
}

#
# Set the dont_optimize flag for a chain
#
sub dont_optimize( $ ) {
    set_optflags( shift, DONT_OPTIMIZE );
}

#
# Set the dont_optimize and dont_delete flags for a chain
#
sub dont_delete( $ ) {
    set_optflags( shift, DONT_OPTIMIZE | DONT_DELETE );
}

#
# Set the dont_move flag for a chain
#
sub dont_move( $ ) {
    set_optflags( shift, DONT_MOVE );
}

#
# Create a filter chain if necessary.
#
# Return a reference to the chain's table entry.
#
sub ensure_filter_chain( $$ )
{
    my ($chain, $populate) = @_;

    my $chainref = ensure_chain 'filter', $chain;

    $chainref->{referenced} = 1;

    $chainref;
}

#
# Create an accounting chain if necessary and return a reference to its table entry.
#
sub ensure_accounting_chain( $$$ )
{
    my ($chain, $ipsec, $restriction ) = @_;

    my $table = $config{ACCOUNTING_TABLE};

    my $chainref = $chain_table{$table}{$chain};

    if ( $chainref ) {
	fatal_error "Non-accounting chain ($chain) used in an accounting rule" unless $chainref->{accounting};
	$chainref->{restriction} |= $restriction;
    } else {
	fatal_error "Chain name ($chain) too long" if length $chain > 29;
	fatal_error "Invalid Chain name ($chain)" unless $chain =~ /^[-\w]+$/ && ! ( $builtin_target{$chain} || $config_files{$chain} );
	$chainref = new_chain $table , $chain;
	$chainref->{accounting}  = 1;
	$chainref->{referenced}  = 1;
	$chainref->{restriction} = $restriction;
	$chainref->{restricted}  = NO_RESTRICT;
	$chainref->{ipsec}       = $ipsec;
	$chainref->{optflags}   |= ( DONT_OPTIMIZE | DONT_MOVE | DONT_DELETE ) unless $config{OPTIMIZE_ACCOUNTING};

	if ( $config{CHAIN_SCRIPTS} ) {
	    unless ( $chain eq 'accounting' ) {
		my $file = find_file $chain;

		if ( -f $file ) {
		    progress_message "Running $file...";

		    my ( $level, $tag ) = ( '', '' );

		    unless ( my $return = eval `cat $file` ) {
			fatal_error "Couldn't parse $file: $@" if $@;
			fatal_error "Couldn't do $file: $!"    unless defined $return;
			fatal_error "Couldn't run $file"       unless $return;
		    }
		}
	    }
	}
    }

    $chainref;
}

#
# Return a list of references to accounting chains
#
sub accounting_chainrefs() {
    grep $_->{accounting} , values %$filter_table;
}

sub ensure_mangle_chain($) {
    my $chain = $_[0];

    my $chainref = ensure_chain 'mangle', $chain;
    $chainref->{referenced} = 1;
    $chainref;
}

sub ensure_nat_chain($) {
    my $chain = $_[0];

    my $chainref = ensure_chain 'nat', $chain;
    $chainref->{referenced} = 1;
    $chainref;
}

sub ensure_raw_chain($) {
    my $chain = $_[0];

    my $chainref = ensure_chain 'raw', $chain;
    $chainref->{referenced} = 1;
    $chainref;
}

sub ensure_rawpost_chain($) {
    my $chain = $_[0];

    my $chainref = ensure_chain 'rawpost', $chain;
    $chainref->{referenced} = 1;
    $chainref;
}

#
# Add a builtin chain
#
sub new_builtin_chain($$$)
{
    my ( $table, $chain, $policy ) = @_;

    my $chainref = new_chain $table, $chain;
    $chainref->{referenced}  = 1;
    $chainref->{policy}      = $policy;
    $chainref->{builtin}     = 1;
    $chainref->{optflags}    = DONT_DELETE;
    $chainref;
}

sub new_standard_chain($) {
    my $chainref = new_chain 'filter' ,$_[0];
    $chainref->{referenced} = 1;
    $chainref;
}

sub new_nat_chain($) {
    my $chainref = new_chain 'nat' ,$_[0];
    $chainref->{referenced} = 1;
    $chainref;
}

sub new_manual_chain($) {
    my $chain = $_[0];
    fatal_error "Chain name ($chain) too long" if length $chain > 29;
    fatal_error "Invalid Chain name ($chain)" unless $chain =~ /^[-\w]+$/ && ! ( $builtin_target{$chain} || $config_files{$chain} );
    fatal_error "Duplicate Chain Name ($chain)" if $targets{$chain} || $filter_table->{$chain};
    $targets{$chain} = CHAIN;
    ( my $chainref = ensure_filter_chain( $chain, 0) )->{manual} = 1;
    $chainref;
}

sub ensure_manual_chain($) {
    my $chain = $_[0];
    my $chainref = $filter_table->{$chain} || new_manual_chain($chain);
    fatal_error "$chain exists and is not a manual chain" unless $chainref->{manual};
    $chainref;
}

sub log_irule_limit( $$$$$$$@ );

sub ensure_blacklog_chain( $$$$$ ) {
    my ( $target, $disposition, $level, $tag, $audit ) = @_;

    unless ( $filter_table->{blacklog} ) {
	my $logchainref = new_manual_chain 'blacklog';

	$target =~ s/A_//;
	$target = 'reject' if $target eq 'REJECT';

	log_irule_limit( $level , $logchainref , 'blacklst' , $disposition , $globals{LOGILIMIT} , $tag, 'add' );

	add_ijump( $logchainref, j => 'AUDIT', targetopts => '--type ' . lc $target ) if $audit;
	add_ijump( $logchainref, g => $target );
    }

    'blacklog';
}

sub ensure_audit_blacklog_chain( $$$ ) {
    my ( $target, $disposition, $level ) = @_;

    unless ( $filter_table->{A_blacklog} ) {
	my $logchainref = new_manual_chain 'A_blacklog';

	log_irule_limit( $level , $logchainref , 'blacklst' , $disposition , $globals{LOGILIMIT} , '', 'add' );

	add_ijump( $logchainref, j => 'AUDIT', targetopts => '--type ' . lc $target );

	$target =~ s/^A_//;
 
	add_ijump( $logchainref, g => $target );
    }

    'A_blacklog';
}

#
# Create and populate the passed AUDIT chain if it doesn't exist. Return chain name
#

sub ensure_audit_chain( $;$$$ ) {
    my ( $target, $action, $tgt, $table ) = @_;

    my $save_comment = push_comment;

    $table = $table || 'filter';

    my $ref = $chain_table{$table}{$target};

    unless ( $ref ) {
	$ref = new_chain( $table, $target );

	unless ( $action ) {
	    $action = $target;
	    $action =~ s/^A_//;
	}

	$tgt ||= $action;

	add_ijump $ref, j => 'AUDIT', targetopts => '--type ' . lc $action;

	if ( $tgt eq 'REJECT' ) {
	    add_ijump $ref , g => 'reject';
	} else {
	    add_ijump $ref , j => $tgt;
	}
    }

    pop_comment( $save_comment );

    return $target;
}

#
# Return the appropriate target based on whether the second argument is 'audit'
#

sub require_audit($$;$) {
    my ($action, $audit, $tgt ) = @_;

    return $action unless supplied $audit && $audit ne '-';

    my $target = 'A_' . $action;

    fatal_error "Invalid parameter ($audit)" unless $audit eq 'audit';

    require_capability 'AUDIT_TARGET', 'audit', 's';

    return ensure_audit_chain $target, $action, $tgt;
}

#
# Add all builtin chains to the chain table -- it is separate from initialize() because it depends on capabilities and configuration.
# The function also initializes the target table with the pre-defined targets available for the specfied address family.
#
sub initialize_chain_table($) {
    my $full = shift;

    if ( $family == F_IPV4 ) {
	#
	#   As new targets (Actions, Macros and Manual Chains) are discovered, they are added to the table
	#
	%targets = ('ACCEPT'          => STANDARD,
		    'ACCEPT+'         => STANDARD  + NONAT,
		    'ACCEPT!'         => STANDARD,
		    'A_ACCEPT'        => STANDARD  + AUDIT,
		    'A_ACCEPT+'       => STANDARD  + NONAT + AUDIT,
		    'A_ACCEPT!'       => STANDARD  + AUDIT,
		    'NONAT'           => STANDARD  + NONAT + NATONLY,
		    'AUDIT'           => STANDARD  + AUDIT + OPTIONS,
		    'DROP'            => STANDARD,
		    'DROP!'           => STANDARD,
		    'A_DROP'          => STANDARD + AUDIT,
		    'A_DROP!'         => STANDARD + AUDIT,
		    'REJECT'          => STANDARD + OPTIONS,
		    'REJECT!'         => STANDARD + OPTIONS,
		    'A_REJECT'        => STANDARD + AUDIT,
		    'A_REJECT!'       => STANDARD + AUDIT,
		    'DNAT'            => NATRULE  + OPTIONS,
		    'DNAT-'           => NATRULE  + NATONLY,
		    'REDIRECT'        => NATRULE  + REDIRECT + OPTIONS,
		    'REDIRECT-'       => NATRULE  + REDIRECT + NATONLY,
		    'LOG'             => STANDARD + LOGRULE  + OPTIONS,
		    'CONTINUE'        => STANDARD,
		    'CONTINUE!'       => STANDARD,
		    'COUNT'           => STANDARD,
		    'QUEUE'           => STANDARD + OPTIONS,
		    'QUEUE!'          => STANDARD,
		    'NFLOG'           => STANDARD + LOGRULE + NFLOG + OPTIONS,
		    'NFQUEUE'         => STANDARD + NFQ + OPTIONS,
		    'NFQUEUE!'        => STANDARD + NFQ,
		    'ULOG'            => STANDARD + LOGRULE + NFLOG + OPTIONS,
		    'ADD'             => STANDARD + SET,
		    'DEL'             => STANDARD + SET,
		    'WHITELIST'       => STANDARD,
		    'HELPER'          => STANDARD + HELPER + NATONLY, #Actually RAWONLY
		    'INLINE'          => INLINERULE,
		    'IPTABLES'        => IPTABLES,
		    'TARPIT'          => STANDARD + TARPIT + OPTIONS,
		   );

	for my $chain ( qw(OUTPUT PREROUTING) ) {
	    new_builtin_chain( 'raw', $chain, 'ACCEPT' )->{insert} = 0;
	}

	new_builtin_chain 'rawpost', 'POSTROUTING', 'ACCEPT';

	for my $chain ( qw(INPUT OUTPUT FORWARD) ) {
	    new_builtin_chain 'filter', $chain, 'DROP';
	}

	for my $chain ( qw(PREROUTING POSTROUTING OUTPUT) ) {
	    new_builtin_chain 'nat', $chain, 'ACCEPT';
	}

	for my $chain ( qw(PREROUTING INPUT OUTPUT ) ) {
	    new_builtin_chain 'mangle', $chain, 'ACCEPT';
	}

	if ( have_capability( 'MANGLE_FORWARD' ) ) {
	    for my $chain ( qw( FORWARD POSTROUTING ) ) {
		new_builtin_chain 'mangle', $chain, 'ACCEPT';
	    }
	}
    } else {
	#
	#   As new targets (Actions, Macros and Manual Chains) are discovered, they are added to the table
	#
	%targets = ('ACCEPT'          => STANDARD,
		    'ACCEPT+'         => STANDARD  + NONAT,
		    'ACCEPT!'         => STANDARD,
		    'A_ACCEPT+'       => STANDARD  + NONAT + AUDIT,
		    'A_ACCEPT!'       => STANDARD  + AUDIT,
		    'AUDIT'           => STANDARD  + AUDIT + OPTIONS,
		    'A_ACCEPT'        => STANDARD  + AUDIT,
		    'NONAT'           => STANDARD  + NONAT + NATONLY,
		    'DROP'            => STANDARD,
		    'DROP!'           => STANDARD,
		    'A_DROP'          => STANDARD + AUDIT,
		    'A_DROP!'         => STANDARD + AUDIT,
		    'REJECT'          => STANDARD + OPTIONS,
		    'REJECT!'         => STANDARD + OPTIONS,
		    'A_REJECT'        => STANDARD + AUDIT,
		    'A_REJECT!'       => STANDARD + AUDIT,
		    'DNAT'            => NATRULE  + OPTIONS,
		    'DNAT-'           => NATRULE  + NATONLY,
		    'REDIRECT'        => NATRULE  + REDIRECT + OPTIONS,
		    'REDIRECT-'       => NATRULE  + REDIRECT + NATONLY,
		    'LOG'             => STANDARD + LOGRULE  + OPTIONS,
		    'CONTINUE'        => STANDARD,
		    'CONTINUE!'       => STANDARD,
		    'COUNT'           => STANDARD,
		    'QUEUE'           => STANDARD + OPTIONS,
		    'QUEUE!'          => STANDARD,
		    'NFLOG'           => STANDARD + LOGRULE + NFLOG + OPTIONS,
		    'NFQUEUE'         => STANDARD + NFQ + OPTIONS,
		    'NFQUEUE!'        => STANDARD + NFQ,
		    'ULOG'            => STANDARD + LOGRULE + NFLOG,
		    'ADD'             => STANDARD + SET,
		    'DEL'             => STANDARD + SET,
		    'WHITELIST'       => STANDARD,
		    'HELPER'          => STANDARD + HELPER + NATONLY, #Actually RAWONLY
		    'INLINE'          => INLINERULE,
		    'IP6TABLES'       => IPTABLES,
		    'TARPIT'          => STANDARD + TARPIT + OPTIONS,
		   );

	for my $chain ( qw(OUTPUT PREROUTING) ) {
	    new_builtin_chain( 'raw', $chain, 'ACCEPT' )->{insert} = 0;
	}

	new_builtin_chain 'rawpost', 'POSTROUTING', 'ACCEPT';

	for my $chain ( qw(INPUT OUTPUT FORWARD) ) {
	    new_builtin_chain 'filter', $chain, 'DROP';
	}

	for my $chain ( qw(PREROUTING POSTROUTING OUTPUT) ) {
	    new_builtin_chain 'nat', $chain, 'ACCEPT';
	}

	for my $chain ( qw(PREROUTING INPUT OUTPUT FORWARD POSTROUTING ) ) {
	    new_builtin_chain 'mangle', $chain, 'ACCEPT';
	}
    }

    if ( $full ) {
	#
	# Create this chain early in case it is needed by Policy actions
	#
	new_standard_chain 'reject';
    }

    my $ruleref = transform_rule( $globals{LOGLIMIT} );

    $globals{iLOGLIMIT} =
	( $ruleref->{hashlimit} ? [ hashlimit => $ruleref->{hashlimit} ] :
	  $ruleref->{limit}     ? [ limit     => $ruleref->{limit}     ] : [] );
}

#
# Delete redundant ACCEPT rules from the end of a policy chain whose policy is ACCEPT
#
sub optimize_chain( $ ) {
    my $chainref = shift;

    if ( $chainref->{referenced} ) {
	my $rules     = $chainref->{rules};
	my $count     = 0;
	my $rulecount = @$rules - 1;

	my $lastrule = pop @$rules; # Pop the plain -j ACCEPT rule at the end of the chain

	while ( @$rules && $rules->[-1]->{target} eq 'ACCEPT' ) {
	    my $rule = pop @$rules;

	    trace( $chainref, 'D', $rulecount , $rule ) if $debug;
	    $count++;
	    $rulecount--;
	}

	if ( @${rules} ) {
	    push @$rules, $lastrule;
	    my $type = $chainref->{builtin} ? 'builtin' : 'policy';
	    progress_message "  $count ACCEPT rules deleted from $type chain $chainref->{name}" if $count;
	} elsif ( $chainref->{builtin} ) {
	    $chainref->{policy} = 'ACCEPT';
	    trace( $chainref, 'P', undef, 'ACCEPT' ) if $debug;
	    $count++;
	    progress_message "  $count ACCEPT rules deleted from builtin chain $chainref->{name}";
	} else {
	    #
	    # The chain is now empty -- change all references to ACCEPT
	    #
	    $count = 0;

	    for my $fromref ( map $filter_table->{$_} , keys %{$chainref->{references}} ) {
		my $rule = 0;
		for ( @{$fromref->{rules}} ) {
		    $rule++;
		    if ( $_->{target} eq $chainref->{name} ) {
			$_->{target} = 'ACCEPT';
			$_->{jump}   = 'j';
			$count++;
			trace( $chainref, 'R', $rule, $_ ) if $debug;
		    }
		}
	    }

	    progress_message "  $count references to ACCEPT policy chain $chainref->{name} replaced";
	    delete_chain $chainref;
	}
    }
}

#
# Delete the references to the passed chain
#
sub delete_references( $ ) {
    my $toref = shift;
    my $table    = $toref->{table};
    my $count    = 0;
    my $rule;

    for my $fromref ( map $chain_table{$table}{$_} , keys %{$toref->{references}} ) {
	delete_jumps ($fromref, $toref );
    }

    if ( $count ) {
	progress_message "  $count references to empty chain $toref->{name} deleted";
    } else {
	progress_message "  Empty chain $toref->{name} deleted";
    }
    #
    # Make sure the above loop found all references
    #
    assert ( ! $toref->{referenced}, $toref->{name} );

    $count;
}

#
# Calculate a digest for the passed chain and store it in the {digest} member.
#
sub calculate_digest( $ ) {
    my $chainref = shift;
    my $digest = '';

    for ( @{$chainref->{rules}} ) {
	if ( $digest ) {
	    $digest .= ' |' . format_rule( $chainref, $_, 1 );
	} else {
	    $digest = format_rule( $chainref, $_, 1 );
	}
    }

    $chainref->{digest} = sha1_hex $digest;
}

#
# Replace jumps to the passed chain with jumps to the passed target
#
sub replace_references( $$$$;$ ) {
    my ( $chainref, $target, $targetopts, $comment, $digest ) = @_;
    my $tableref  = $chain_table{$chainref->{table}};
    my $count     = 0;
    my $name      = $chainref->{name};

    assert defined $target;

    my $targetref = $tableref->{$target};

    for my $fromref ( map $tableref->{$_} , keys %{$chainref->{references}} ) {
	if ( $fromref->{referenced} ) {
	    my $rule = 0;
	    for ( @{$fromref->{rules}} ) {
		$rule++;
		if ( $_->{target} eq $name ) {
		    $_->{target}     = $target;
		    $_->{targetopts} = $targetopts if $targetopts;
		    $_->{comment}    = $comment unless $_->{comment};

		    if ( $targetref ) {
			add_reference ( $fromref, $targetref );
		    } else {
			$_->{jump}   = 'j';
		    }

		    $count++;
		    trace( $fromref, 'R', $rule, $_ ) if $debug;
		}
	    }
	    #
	    # The chain has been modified, so the digest is now stale
	    #
	    calculate_digest( $fromref ) if $digest;
	    #
	    # The passed chain is no longer referenced by chain $fromref
	    #
	    delete $chainref->{references}{$fromref->{name}};
	}
    }
    #
    # The passed chain is no longer referenced by the target chain
    #
    delete $targetref->{references}{$chainref->{name}} if $targetref;

    progress_message "  $count references to chain $chainref->{name} replaced" if $count;

    delete_chain $chainref;
}

#
# Replace jumps to the passed chain with jumps to the target of the passed rule while merging
# options and matches
#
sub replace_references1( $$ ) {
    my ( $chainref, $ruleref ) = @_;
    my $tableref  = $chain_table{$chainref->{table}};
    my $count     = 0;
    my $name      = $chainref->{name};
    my $target    = $ruleref->{target};
    my $delete    = 1;

    for my $fromref ( map $tableref->{$_} , keys %{$chainref->{references}} ) {
	my $rule    = 0;
	my $skipped = 0;
	if ( $fromref->{referenced} ) {
	    for ( @{$fromref->{rules}} ) {
		$rule++;
		if ( $_->{target} eq $name ) {
		    if ( compatible( $_ , $ruleref ) ) {
			#
			# The target is the passed chain -- merge the two rules into one
			#
			if ( my $targetref = merge_rules( $tableref, $_, $ruleref ) ) {
			    add_reference( $fromref, $targetref );
			    delete_reference( $fromref, $chainref );
			}

			$count++;
			trace( $fromref, 'R', $rule, $_ ) if $debug;
		    } else {
			$skipped++;
		    }
		}
	    }
	}

	if ( $skipped ) {
	    $delete = 0;
	} else {
	    delete $tableref->{$target}{references}{$chainref->{name}} if $tableref->{$target};
	}
    }

    progress_message "  $count references to chain $chainref->{name} replaced" if $count;

    delete_chain $chainref if $delete;

    $count;
}

#
# The passed builtin chain has a single rule. If the target is a user chain without 'dont"move', copy the rules from the
# chain to the builtin and return true; otherwise, do nothing and return false.
#
sub conditionally_copy_rules( $$ ) {
    my ( $chainref, $basictarget ) = @_;

    my $targetref = $chain_table{$chainref->{table}}{$basictarget};

    if ( $targetref && ! ( $targetref->{optflags} & DONT_MOVE ) ) {
	#
	# Move is safe -- start with an empty rule list
	#
	$chainref->{rules} = [];
	copy_rules( $targetref, $chainref );
	1;
    }
}

#
# The passed chain is branched to with a rule containing '-s'. If the chain has any rule that also contains '-s' then
# mark the chain as "don't optimize".
#
sub check_optimization( $ ) {

    if ( $config{OPTIMIZE} & 4 ) {
	my $chainref = shift;

	for ( @{$chainref->{rules}} ) {
	    dont_optimize $chainref, return 0 if $_->{s};
	}
    }

    1;
}

#
# Perform Optimization
#
# When an unreferenced chain is found, it is deleted unless its 'dont_delete' flag is set.
#
sub optimize_level0() {
    for my $table ( qw/raw rawpost mangle nat filter/ ) {
	my $tableref = $chain_table{$table};
	next unless $tableref;

	my $progress = 1;

	while ( $progress ) {
	    my @chains  = grep $_->{referenced}, values %$tableref;
	    my $chains  = @chains;

	    $progress = 0;

	    for my $chainref ( @chains ) {
		#
		# If the chain isn't branched to, then delete it
		#
		unless ( $chainref->{optflags} & DONT_DELETE || keys %{$chainref->{references}} ) {
		    delete_chain_and_references $chainref, $progress = 1 if $chainref->{referenced};
		}
	    }
	}
    }
}

sub optimize_level4( $$ ) {
    my ( $table, $tableref ) = @_;
    my $progress = 1;
    my $passes   = 0;
    #
    # Make repeated passes through each table looking for short chains (those with less than 2 entries)
    #
    # When an empty chain is found, delete the references to it.
    # When a chain with a single entry is found, replace it's references by its contents
    #
    # The search continues until no short chains remain
    # Chains with 'DONT_OPTIMIZE' are exempted from optimization
    #

    while ( $progress ) {
	$progress = 0;
	$passes++;

	my @chains  = grep $_->{referenced}, sort { $a->{name} cmp $b->{name} } values %$tableref;
	my $chains  = @chains;

	progress_message "\n Table $table pass $passes, $chains referenced chains, level 4a...";

	for my $chainref ( @chains ) {
	    my $optflags = $chainref->{optflags};
	    #
	    # If the chain isn't branched to, then delete it
	    #
	    unless ( ( $optflags & DONT_DELETE ) || keys %{$chainref->{references}} ) {
		delete_chain_and_references $chainref if $chainref->{referenced};
		next;
	    }

	    unless ( $optflags & DONT_OPTIMIZE ) {
		my $numrules = @{$chainref->{rules}};

		if ( $numrules == 0 ) {
		    #
		    # No rules in this chain
		    #
		    if ( $chainref->{builtin} ) {
			#
			# Built-in -- mark it 'dont_optimize' so we ignore it in follow-on passes
			#
			$chainref->{optflags} |= DONT_OPTIMIZE;
		    } else {
			#
			# Not a built-in -- we can delete it and it's references
			#
			delete_references $chainref;
			$progress = 1;
		    }
		} else {
		    #
		    # The chain has rules -- determine if it is terminating
		    #
		    my $name    = $chainref->{name};
		    my $lastref = $chainref->{rules}[-1];

		    unless ( $chainref->{optflags} & RETURNS || $terminating{$name} ) {
			$progress = 1 if $terminating{$name} = ( ( $terminating{$lastref->{target} || ''} ) || ( $lastref->{jump} || '' ) eq 'g' );
		    }

		    if ( $numrules == 1) {
			#
			# Chain has a single rule
			#
			my $firstrule = $lastref;

			if ( $firstrule ->{simple} ) {
			    #
			    # Easy case -- the rule is a simple jump
			    #
			    if ( $chainref->{builtin} ) {
				#
				# A built-in chain. If the target is a user chain without 'dont_move',
				# we can copy its rules to the built-in
				#
				if ( conditionally_copy_rules $chainref, $firstrule->{target} ) {
				    #
				    # Target was a user chain -- rules moved
				    #
				    $progress = 1;
				} else {
				    #
				    # Target was a built-in. Ignore this chain in follow-on passes
				    #
				    $chainref->{optflags} |= DONT_OPTIMIZE;
				}
			    } elsif ( ( $firstrule->{target} || '' ) eq 'RETURN' ) {
				#
				# A chain with a single 'RETURN' rule -- get rid of it
				#
				delete_chain_and_references( $chainref );
				$progress = 1;
			    } else {
				#
				# Replace all references to this chain with references to the target
				#
				replace_references( $chainref,
						    $firstrule->{target},
						    $firstrule->{targetopts},
						    $firstrule->{comment} );
				$progress = 1;
			    }
			} elsif ( $firstrule->{target} ) {
			    if ( $firstrule->{target} eq 'RETURN' ) {
				#
				# A chain with a single 'RETURN' rule -- get rid of it
				#
				delete_chain_and_references( $chainref );
				$progress = 1;
			    } elsif ( $chainref->{builtin} || ! $globals{KLUDGEFREE} || $firstrule->{policy} ) {
				#
				# This case requires a new rule merging algorithm. Ignore this chain for
				# now on.
				#
				$chainref->{optflags} |= DONT_OPTIMIZE;
			    } elsif ( ! ( $chainref->{optflags} & DONT_MOVE ) ) {
				#
				# Replace references to this chain with the target and add the matches
				#
				$progress = 1 if replace_references1 $chainref, $firstrule;
			    }
			}
		    } else {
			#
			# Chain has more than one rule. If the last rule is a simple jump, then delete
			# all immediately preceding rules that have the same target
			#
			my $rulesref = $chainref->{rules};

			if ( ( $lastref->{target} || '' ) eq 'RETURN' ) {
			    #
			    # The last rule is a RETURN -- get rid of it
			    #
			    pop @$rulesref;
			    $lastref = $rulesref->[-1];
			    $progress = 1;
			}

			if ( $lastref->{simple} && $lastref->{target} && ! $lastref->{targetopts} ) {
			    my $target = $lastref->{target};
			    my $count  = 0;
			    my $rule   = @$rulesref - 1;

			    pop @$rulesref; #Pop the last simple rule

			    while ( @$rulesref ) {
				my $rule1ref = $rulesref->[-1];

				last unless ( $rule1ref->{target} || '' ) eq $target && ! ( $rule1ref->{targetopts} || $rule1ref->{nfacct} || $rule1ref->{recent} );

				trace ( $chainref, 'D', $rule, $rule1ref ) if $debug;

				pop @$rulesref;
				$progress = 1;
				$count++;
				$rule--;
			    }

			    if ( @$rulesref || ! $chainref->{builtin} || $target !~ /^(?:ACCEPT|DROP|REJECT)$/ ) {
				push @$rulesref, $lastref; # Restore the last simple rule
			    } else {
				#
				#empty builtin chain -- change it's policy
				#
				$chainref->{policy} = $target;
				trace( $chainref, 'P', undef, 'ACCEPT' ) if $debug;
				$count++;
			    }

			    progress_message "   $count $target rules deleted from chain $name" if $count;
			}
		    }
		}
	    }
	}
    }

    #
    # In this loop, we look for chains that end in an unconditional jump. The jump is replaced by
    # the target's rules, provided that the target chain is short (< 4 rules) or has only one
    # reference. This prevents multiple copies of long chains being created.
    #
    $progress = 1;

    while ( $progress ) {
	$progress = 0;
	$passes++;

	my @chains  = grep $_->{referenced}, values %$tableref;
	my $chains  = @chains;

	progress_message "\n Table $table pass $passes, $chains referenced chains, level 4b...";

	for my $chainref ( @chains ) {
	    my $lastrule = $chainref->{rules}[-1];

	    if ( defined $lastrule && $lastrule->{simple} ) {
		#
		# Last rule is a simple branch
		my $targetref = $tableref->{$lastrule->{target}};

		if ( $targetref &&
		     ($targetref->{optflags} & DONT_MOVE) == 0 &&
		     ( keys %{$targetref->{references}} < 2 || @{$targetref->{rules}} < 4 ) ) {
		    copy_rules( $targetref, $chainref );
		    $progress = 1;
		}
	    }
	}
    }

    #
    # Identify short chains with a single reference and replace the reference with the chain rules
    #
    my @chains  = grep ( $_->{referenced}   &&
			 ! $_->{optflags}   &&
			 @{$_->{rules}} < 4 &&
			 keys %{$_->{references}} == 1 , values %$tableref );

    if ( my $chains  = @chains ) {
	$passes++;

	progress_message "\n Table $table pass $passes, $chains short chains, level 4b...";

	for my $chainref ( @chains ) {
	    my $name = $chainref->{name};
	    for my $sourceref ( map $tableref->{$_}, keys %{$chainref->{references}} ) {
		my $name1 = $sourceref->{name};

		if ( $chainref->{references}{$name1} == 1 ) {
		    my $rulenum  = 0;
		    my $rulesref = $sourceref->{rules};
		    my $rules    = @{$chainref->{rules}};

		    for ( @$rulesref ) {
			if ( $_->{simple} && ( $_->{target} || '' ) eq $name ) {
			    trace( $sourceref, 'D', $rulenum  + 1, $_ ) if $debug;
			    splice @$rulesref, $rulenum, 1, @{$chainref->{rules}};
			    while ( my $ruleref = shift @{$chainref->{rules}} ) {
				trace ( $sourceref, 'I', $rulenum++, $ruleref ) if $debug;
				my $target = $ruleref->{target};

				if ( $target && ( my $targetref = $tableref->{$target} ) ) {
				    #
				    # The rule target is a chain
				    #
				    add_reference( $sourceref, $targetref );
				    delete_reference( $chainref, $targetref );
				}
			    }

			    delete $chainref->{references}{$name1};
			    delete_chain $chainref;
			    last;
			}
			$rulenum++;
		    }
		}
	    }
	}
    }

    $passes;
}

#
# Compare two chains. Sort in reverse order except within names that have the
# same first character, which are sorted in forward order.
#
sub level8_compare( $$ ) {
    my ( $name1, $name2 ) = ( $_[0]->{name}, $_[1]->{name} );

    if ( substr( $name1, 0, 1 ) eq substr( $name2, 0, 1 ) ) {
	$name1 cmp $name2;
    } else {
	$name2 cmp $name1;
    }
}

#
# Delete duplicate chains replacing their references
#
sub optimize_level8( $$$ ) {
    my ( $table, $tableref , $passes ) = @_;
    my $progress = 1;
    my $chainseq = 0;

    %renamed = ();

    while ( $progress ) {
	my @chains   = ( sort { level8_compare($a, $b) } ( grep $_->{referenced} && ! $_->{builtin}, values %{$tableref} ) );
	my @chains1  = @chains;
	my $chains   = @chains;
	my %rename;
	my %combined;

	$progress = 0;

	progress_message "\n Table $table pass $passes, $chains referenced user chains, level 8...";

	$passes++;

	calculate_digest( $_ ) for ( grep ! $_->{digest}, @chains );

	for my $chainref ( @chains ) {
	    my $rules    = $chainref->{rules};
	    #
	    # Shift the current $chainref off of @chains1
	    #
	    shift @chains1;
	    #
	    # Skip empty chains
	    #
	    for my $chainref1 ( @chains1 ) {
		next unless @{$chainref1->{rules}};
		next if $chainref1->{optflags} & DONT_DELETE;
		if ( $chainref->{digest} eq $chainref1->{digest} ) {
		    progress_message "  Chain $chainref1->{name} combined with $chainref->{name}";
		    $progress = 1;
		    replace_references $chainref1, $chainref->{name}, undef, '', 1;

		    unless ( $chainref->{name} =~ /^~/ || $chainref1->{name} =~ /^%/ ) {
			#
			# For simple use of the BLACKLIST section, we can end up with many identical
			# chains. To distinguish them from other renamed chains, we keep track of
			# these chains via the 'blacklistsection' member.
			#
			$rename{ $chainref->{name} } = $chainref->{blacklistsection} ? '~blacklist' : '~comb';
		    }

		    $combined{ $chainref1->{name} } = $chainref->{name};
		}
	    }
	}

	if ( $progress ) {
	    my @rename = sort keys %rename;
	    #
	    # First create aliases for each renamed chain and change the {name} member.
	    #
	    for my $oldname ( @rename ) {
		my $newname = $renamed{ $oldname } = $rename{ $oldname } . $chainseq++;

		trace( $tableref->{$oldname}, 'RN', 0, " Renamed $newname" ) if $debug;
		$tableref->{$newname} = $tableref->{$oldname};
		$tableref->{$oldname}{name} = $newname;
		progress_message "  Chain $oldname renamed to $newname";
	    }
	    #
	    # Next, map the combined names
	    #
	    while ( my ( $oldname, $combinedname ) = each %combined ) {
		$renamed{$oldname} = $renamed{$combinedname} || $combinedname;
	    }
	    #
	    # Now adjust the references to point to the new name
	    #
	    while ( my ($chain, $chainref ) = each %$tableref ) {
		my %references = %{$chainref->{references}};

		if ( my $newname = $renamed{$chainref->{policychain} || ''} ) {
		    $chainref->{policychain} = $newname;
		}

		while ( my ( $chain1, $chainref1 ) = each %references ) {
		    if ( my $newname = $renamed{$chainref->{references}{$chain1}} ) {
			$chainref->{references}{$newname} = $chainref->{references}{$chain1};
			delete $chainref->{references}{$chain1};
		    }
		}
	    }
	    #
	    # Delete the old names from the table
	    #
	    delete $tableref->{$_} for @rename;
	    #
	    # And fix up the rules
	    #
	    for my $chainref ( values %$tableref ) {
		my $rulenum = 0;

		for ( @{$chainref->{rules}} ) {
		    $rulenum++;

		    if ( my $newname = $renamed{$_->{target}} ) {
			$_->{target} = $newname;
			delete $chainref->{digest};
			trace( $chainref, 'R', $rulenum, $_ ) if $debug;
		    }
		}
	    }
	}
    }

    $passes;

}

#
# Returns a comma-separated list of destination ports from the passed rule
#
sub get_dports( $ ) {
    my $ruleref = shift;

    my $ports = $ruleref->{dport} || '';

    unless ( $ports ) {
	if ( my $multiref = $ruleref->{multiport} ) {
	    if ( reftype $multiref ) {
		for ( @$multiref ) {
		    if ( /^--dports (.*)/ ) {
			if ( $ports ) {
			    $ports .= ",$1";
			} else {
			    $ports = $1;
			}
		    }
		}
	    } else {
		$ports = $1 if $multiref =~ /^--dports (.*)/;
	    }
	}
    }

    $ports;
}

#
# Returns a comma-separated list of multiport source ports from the passed rule
#
sub get_multi_sports( $ ) {
    my $ports = '';

    if ( my $multiref = $_[0]->{multiport} ) {
	if ( reftype $multiref ) {
	    for ( @$multiref ) {
		if ( /^--sports (.*)/ ) {
		    if ( $ports ) {
			$ports .= ",$1";
		    } else {
			$ports = $1;
		    }
		}
	    }
	} else {
	    $ports = $1 if $multiref =~ /^--sports (.*)/;
	}
    }

    $ports;
}

#
# Return an array of keys for the passed rule. 'dport' and 'comment' are omitted;
#
sub get_keys( $ ) {
    sort grep $_ ne 'dport' && $_ ne 'comment',  keys %{$_[0]};
}

#
# The arguments are a list of rule references; function returns a similar list with adjacent compatible rules combined
#
# Adjacent rules are compatible if:
#
#   - They all specify destination ports
#   - All of the rest of their members are identical with the possible exception of 'comment'.
#
#  Adjacent distinct comments are combined, separated by ', '. Redundant adjacent comments are dropped.
#
sub combine_dports {
    my @rules;
    my $rulenum  = 1;
    my $chainref = shift;
    my $baseref  = shift;

    while ( $baseref ) {
	{
	    my $ruleref;
	    my $ports1;
	    my $basenum = $rulenum;

	    if ( $ports1 = get_dports( $baseref ) ) {
		my $proto        = $baseref->{p};
		my @keys1        = get_keys( $baseref );
		my @ports        = ( split ',', $ports1 );
		my $ports        = port_count( $ports1 );
		my $origports    = @ports;
		my $comment      = $baseref->{comment} || '';
		my $lastcomment  = $comment;
		my $multi_sports = get_multi_sports( $baseref );

	      RULE:

		while ( ( $ruleref = shift ) && $ports < 15 ) {
		    my $ports2;

		    $rulenum++;

		    if ( ( $ports2 = get_dports( $ruleref ) ) && $ruleref->{p} eq $proto ) {
			#
			# We have a candidate
			#
			my $comment2 = $ruleref->{comment} || '';

			last if $comment2 ne $lastcomment && length( $comment ) + length( $comment2 ) > 253;

			my @keys2 = get_keys( $ruleref );

			last unless @keys1 == @keys2 ;

			my $keynum = 0;

			for my $key ( @keys1 ) {
			    last RULE unless $key eq $keys2[$keynum++];
			    next if compare_values( $baseref->{$key}, $ruleref->{$key} );
			    last RULE unless $key eq 'multiport' && $multi_sports eq get_multi_sports( $ruleref );
			}

			next RULE if $ports1 eq $ports2;

			last if ( $ports += port_count( $ports2 ) ) > 15;

			if ( $comment2 ) {
			    if ( $comment ) {
				$comment .= ", $comment2" unless $comment2 eq $lastcomment;
			    } else {
				$comment = 'Others and ';
				last if length( $comment ) + length( $comment2 ) > 255;
				$comment .= $comment2;
			    }

			    $lastcomment = $comment2;
			} else {
			    if ( $comment ) {
				unless ( ( $comment2 = ' and others' ) eq $lastcomment ) {
				    last if length( $comment ) + length( $comment2 ) > 255;
				    $comment .= $comment2;
				}
			    }

			    $lastcomment = $comment2;
			}

			push @ports, split ',', $ports2;

			trace( $chainref, 'D', $rulenum, $ruleref ) if $debug;

		    } else {
			last;
		    }
		}

		if ( @ports > $origports ) {
		    delete $baseref->{dport} if $baseref->{dport};

		    if ( $multi_sports ) {
			$baseref->{multiport} = [ '--sports ' . $multi_sports , '--dports ' . join(',', @ports ) ];
		    } else {
			$baseref->{'multiport'} = '--dports ' . join( ',' , @ports  );
		    }

		    my @matches = @{$baseref->{matches}};

		    $baseref->{matches} = [];

		    my $switched = 0;

		    for ( @matches ) {
			if ( $_ eq 'dport' || $_ eq 'sport' ) {
			    push @{$baseref->{matches}}, 'multiport' unless $switched++;
			} else {
			    push @{$baseref->{matches}}, $_;
			}
		    }

		    $baseref->{comment} = $comment if $comment;

		    trace ( $chainref, 'R', $basenum, $baseref ) if $debug;
		}
	    }

	    push @rules, $baseref;

	    $baseref = $ruleref ? $ruleref : shift;
	}
    }

    \@rules;
}

#
# When suppressing duplicate rules, care must be taken to avoid suppressing non-adjacent duplicates 
# using any of these matches, because an intervening rule could modify the result of the match
# of the second duplicate
#
my %bad_match = ( 'conntrack --ctstate' => 1, 
		  dscp                  => 1,
		  ecn                   => 1,
		  mark                  => 1,
		  set                   => 1,
		  tos                   => 1,
		  u32                   => 1 );
#
# Delete duplicate rules from the passed chain.
#
#   The arguments are a reference to the chain followed by references to each 
#   of its rules.
#
sub delete_duplicates {
    my @rules;
    my $chainref  = shift;
    my $lastrule  = @_;
    my $baseref   = pop;
    my $ruleref;

    while ( @_ ) {
	my $docheck;
	my $duplicate = 0;

	if ( $baseref->{mode} == CAT_MODE ) {
	    my $ports1;
	    my @keys1    = sort( grep $_ ne 'comment', keys( %$baseref ) );
	    my $rulenum  = @_;
	    my $adjacent = 1;
		
	    {
	      RULE:

		while ( --$rulenum >= 0 ) {
		    $ruleref = $_[$rulenum];

		    last unless $ruleref->{mode} == CAT_MODE;

		    my @keys2 = sort(grep $_ ne 'comment', keys( %$ruleref ) );

		    next unless @keys1 == @keys2 ;

		    my $keynum = 0;

		    if ( $adjacent > 0 ) {
			#
			# There are no non-duplicate rules between this rule and the base rule
			#
			for my $key (  @keys1 ) {
			    next RULE unless $key eq $keys2[$keynum++];
			    next RULE unless compare_values( $baseref->{$key}, $ruleref->{$key} );
			}
		    } else {
			#
			# There are non-duplicate rules between this rule and the base rule
			#
			for my $key ( @keys1 ) {
			    next RULE unless $key eq $keys2[$keynum++];
			    next RULE unless compare_values( $baseref->{$key}, $ruleref->{$key} );
			    last RULE if $bad_match{$key};
			}
		    }
		    #
		    # This rule is a duplicate
		    #
		    $duplicate = 1;
		    #
		    # Increment $adjacent so that the continue block won't set it to zero
		    #
		    $adjacent++;

		} continue {
		    $adjacent--;
		}
	    }
	}

	if ( $duplicate ) {
	    trace( $chainref, 'D', $lastrule, $baseref ) if $debug;
	} else {
	    unshift @rules, $baseref;
	}

	$baseref = pop @_;
	$lastrule--;
    }

    unshift @rules, $baseref if $baseref;

    \@rules;
}

#
# Get the 'conntrack' state(s) for the passed rule reference
#
sub get_conntrack( $ ) {
    my $ruleref = $_[0];
    if ( my $states = $ruleref->{'conntrack --ctstate'} ) {
	#
	# Normalize the rule and return the states.
	#
	delete $ruleref->{targetopts} unless $ruleref->{targetopts};
	$ruleref->{simple} = ''       unless $ruleref->{simple};
	return $states 
    }

    '';
}

#
# Return an array of keys for the passed rule. 'conntrack' and 'comment' are omitted;
#
sub get_keys1( $ ) {
    sort grep $_ ne 'conntrack --ctstate' && $_ ne 'comment',  keys %{$_[0]};
}

#
# The arguments are a list of rule references; function returns a similar list with adjacent compatible rules combined
#
# Adjacent rules are compatible if:
#
#   - They all specify conntrack match
#   - All of the rest of their members are identical with the possible exception of 'comment'.
#
#  Adjacent distinct comments are combined, separated by ', '. Redundant adjacent comments are dropped.
#
sub combine_states {
    my @rules;
    my $rulenum  = 1;
    my $chainref = shift;
    my $baseref  = shift;

    while ( $baseref ) {
	{
	    my $ruleref;
	    my $conntrack;
	    my $basenum = $rulenum;

	    if ( my $conntrack1 = get_conntrack( $baseref ) ) {
		my @keys1         = get_keys1( $baseref );
		my @states        = ( split ',', $conntrack1 );
		my %states;

		$states{$_} = 1 for @states;

		my $origstates  = @states;
		my $comment     = $baseref->{comment} || '';
		my $lastcomment = $comment;

	      RULE:

		while ( ( $ruleref = shift ) ) {
		    my $conntrack2;

		    $rulenum++;

		    if ( $conntrack2 = get_conntrack( $ruleref ) ) {
			#
			# We have a candidate
			#
			my $comment2 = $ruleref->{comment} || '';

			last if $comment2 ne $lastcomment && length( $comment ) + length( $comment2 ) > 253;

			my @keys2 = get_keys1( $ruleref );

			last unless @keys1 == @keys2 ;

			my $keynum = 0;

			for my $key ( @keys1 ) {
			    last RULE unless $key eq $keys2[$keynum++];
			    last RULE unless compare_values( $baseref->{$key}, $ruleref->{$key} );
			}
			
			if ( $comment2 ) {
			    if ( $comment ) {
				$comment .= ", $comment2" unless $comment2 eq $lastcomment;
			    } else {
				$comment = 'Others and ';
				last if length( $comment ) + length( $comment2 ) > 255;
				$comment .= $comment2;
			    }

			    $lastcomment = $comment2;
			} else {
			    if ( $comment ) {
				unless ( ( $comment2 = ' and others' ) eq $lastcomment ) {
				    last if length( $comment ) + length( $comment2 ) > 255;
				    $comment .= $comment2;
				}
			    }

			    $lastcomment = $comment2;
			}

			for ( split ',', $conntrack2 ) {
			    unless ( $states{$_} ) {
				push @states, $_;
				$states{$_} = 1;
			    }
			}

			trace( $chainref, 'D', $rulenum, $ruleref ) if $debug;

		    } else {
			#
			# Rule doesn't have the conntrack match
			#
			last;
		    }
		}

		if ( @states > $origstates ) {
		    $baseref->{'conntrack --ctstate'} = join( ',', @states );
		    trace ( $chainref, 'R', $basenum, $baseref ) if $debug;
		}
	    }

	    push @rules, $baseref;

	    $baseref = $ruleref ? $ruleref : shift;
	}
    }

    \@rules;
}

sub optimize_level16( $$$ ) {
    my ( $table, $tableref , $passes ) = @_;
    my @chains   = ( grep $_->{referenced}, values %{$tableref} );
    my @chains1  = @chains;
    my $chains   = @chains;

    progress_message "\n Table $table pass $passes, $chains referenced user chains, level 16...";

    for my $chainref ( @chains ) {
	$chainref->{rules} = delete_duplicates( $chainref, @{$chainref->{rules}} );
    }

    $passes++;
    
    for my $chainref ( @chains ) {
	$chainref->{rules} = combine_dports( $chainref, @{$chainref->{rules}} );
    }

    ++$passes;

    if ( have_capability 'CONNTRACK_MATCH' ) {
	for my $chainref ( @chains ) {
	    $chainref->{rules} = combine_states( $chainref, @{$chainref->{rules}} );
	}
    }
	
}

#
# Return an array of valid Netfilter tables
#
sub valid_tables() {
    my @table_list;

    push @table_list, 'raw'     if have_capability( 'RAW_TABLE' );
    push @table_list, 'rawpost' if have_capability( 'RAWPOST_TABLE' );
    push @table_list, 'nat'     if have_capability( 'NAT_ENABLED' );
    push @table_list, 'mangle'  if have_capability( 'MANGLE_ENABLED' ) && $config{MANGLE_ENABLED};
    push @table_list, 'filter'; #MUST BE LAST!!!

    @table_list;
}

sub optimize_ruleset() {

    for my $table ( valid_tables ) {

	my $tableref = $chain_table{$table};
	my $passes   = 0;
	my $optimize = $config{OPTIMIZE};

	$passes = optimize_level4(  $table, $tableref )           if $optimize & 4;
	$passes = optimize_level8(  $table, $tableref , $passes ) if $optimize & 8;
	$passes = optimize_level16( $table, $tableref , $passes ) if $optimize & 16;

	progress_message "  Table $table Optimized -- Passes = $passes";
	progress_message '';
    }
}

#
# Helper for set_mss
#
sub set_mss1( $$ ) {
    my ( $chain, $mss ) =  @_;
    my $chainref = ensure_chain 'filter', $chain;

    if ( $chainref->{policy} ne 'NONE' ) {
	my $match = have_capability( 'TCPMSS_MATCH' ) ? "-m tcpmss --mss $mss: " : '';
	insert_rule1 $chainref, 0, "-p tcp --tcp-flags SYN,RST SYN ${match}-j TCPMSS --set-mss $mss"
    }
}

#
# Set up rules to set MSS to and/or from zone "$zone"
#
sub set_mss( $$$ ) {
    my ( $zone, $mss, $direction) = @_;

    for my $z ( all_zones ) {
	if ( $direction eq '_in' ) {
	    set_mss1 rules_chain( ${zone}, ${z} ) , $mss;
	} elsif ( $direction eq '_out' ) {
	    set_mss1 rules_chain( ${z}, ${zone} ) , $mss;
	} else {
	    set_mss1 rules_chain( ${z}, ${zone} ) , $mss;
	    set_mss1 rules_chain( ${zone}, ${z} ) , $mss;
	}
    }
}

#
# Interate over all zones with 'mss=' settings adding TCPMSS rules as appropriate.
#
sub imatch_source_dev( $;$ );
sub imatch_dest_dev( $;$ );
sub imatch_source_net( $;$\$ );
sub imatch_dest_net( $;$ );

sub newmsschain( ) {
    my $seq = $chainseq{filter}++;
    "~mss${seq}";
}

sub setup_zone_mss() {
    for my $zone ( all_zones ) {
	my $zoneref = find_zone( $zone );

	set_mss( $zone, $zoneref->{options}{in_out}{mss}, ''     ) if $zoneref->{options}{in_out}{mss};
	set_mss( $zone, $zoneref->{options}{in}{mss},     '_in'  ) if $zoneref->{options}{in}{mss};
	set_mss( $zone, $zoneref->{options}{out}{mss},    '_out' ) if $zoneref->{options}{out}{mss};

	my $hosts = find_zone_hosts_by_option( $zone, 'mss' );

	for my $hostref ( @$hosts ) {
	    my $mss         = $hostref->[4];
	    my @mssmatch    = have_capability( 'TCPMSS_MATCH' ) ? ( tcpmss => "--mss $mss:" ) : ();
	    my @sourcedev   = imatch_source_dev $hostref->[0];
	    my @destdev     = imatch_dest_dev   $hostref->[0];
	    my @source      = imatch_source_net $hostref->[2];
	    my @dest        = imatch_dest_net   $hostref->[2];
	    my @ipsecin     = (have_ipsec ? ( policy => "--pol $hostref->[1] --dir in"  ) : () );
	    my @ipsecout    = (have_ipsec ? ( policy => "--pol $hostref->[1] --dir out" ) : () );

	    my $chainref = new_chain 'filter', newmsschain;
	    my $target   = source_exclusion( $hostref->[3], $chainref );

	    add_ijump $chainref, j => 'TCPMSS', targetopts => "--set-mss $mss", p => 'tcp --tcp-flags SYN,RST SYN';

	    for my $zone1 ( all_zones ) {
		add_ijump ensure_chain( 'filter', rules_chain( $zone, $zone1 ) ),  j => $target , @sourcedev, @source, p => 'tcp --tcp-flags SYN,RST SYN', @mssmatch, @ipsecin ;
		add_ijump ensure_chain( 'filter', rules_chain( $zone1, $zone ) ),  j => $target , @destdev,   @dest,   p => 'tcp --tcp-flags SYN,RST SYN', @mssmatch, @ipsecout ;
	    }
	}
    }
}

sub newexclusionchain( $ ) {
    my $seq = $chainseq{$_[0]}++;
    "~excl${seq}";
}

sub newlogchain( $ ) {
    my $seq = $chainseq{$_[0]}++;
    "~log${seq}";
}

#
# If there is already a logging chain associated with the passed rules chain that matches these
# parameters, then return a reference to it.
#
# Otherwise, create such a chain and store a reference in chainref's 'logchains' hash. Return the
# reference.
#
sub logchain( $$$$$$ ) {
    my ( $chainref, $loglevel, $logtag, $exceptionrule, $disposition, $target ) = @_;
    my $key = join( ':', $loglevel, $logtag, $exceptionrule, $disposition, $target );
    my $logchainref = $chainref->{logchains}{$key};

    unless ( $logchainref ) {
	$logchainref = $chainref->{logchains}{$key} = new_chain $chainref->{table}, newlogchain( $chainref->{table} ) ;
	#
	# Now add the log rule and target rule without matches to the log chain.
	#
	log_irule_limit(
		       $loglevel ,
		       $logchainref ,
		       $chainref->{name} ,
		       $disposition ,
		       [] ,
		       $logtag,
		       'add' );
	add_jump( $logchainref, $target, 0, $exceptionrule );
    }

    $logchainref;
}

sub newnonatchain() {
    my $seq = $chainseq{nat}++;
    "nonat${seq}";
}

#
# If the passed exclusion array is non-empty then:
#
#       Create a new exclusion chain in the table of the passed chain
#           (Note: If the chain is not in the filter table then a
#                  reference to the chain's chain table entry must be
#                  passed).
#
#       Add RETURN rules for each element of the exclusion array
#
#       Add a jump to the passed chain
#
#       Return the exclusion chain. The type of the returned value
#                                   matches what was passed (reference
#                                   or name).
#
# Otherwise
#
#       Return the passed chain.
#
# There are two versions of the function; one for source exclusion and
# one for destination exclusion.
#
sub source_exclusion( $$ ) {
    my ( $exclusions, $target ) = @_;

    return $target unless @$exclusions;

    my $table = reftype $target ? $target->{table} : 'filter';

    my $chainref = dont_move new_chain( $table , newexclusionchain( $table ) );

    add_ijump( $chainref, j => 'RETURN', imatch_source_net( $_ ) ) for @$exclusions;
    add_ijump( $chainref, g => $target );

    reftype $target ? $chainref : $chainref->{name};
}

sub split_host_list( $$;$ );

sub source_iexclusion( $$$$$;@ ) {
    my $chainref   = shift;
    my $jump       = shift;
    my $target     = shift;
    my $targetopts = shift;
    my $source     = shift;
    my $table      = $chainref->{table};

    my @exclusion;

    if ( $source =~ /^([^!]+)!([^!]+)$/ ) {
	$source = $1;
	@exclusion = split_host_list( $2, $config{DEFER_DNS_RESOLUTION} );

	my $chainref1 = dont_move new_chain( $table , newexclusionchain( $table ) );

	add_ijump( $chainref1 , j => 'RETURN', imatch_source_net( $_ ) ) for @exclusion;

	if ( $targetopts ) {
	    add_ijump( $chainref1, $jump => $target, targetopts => $targetopts );
	} else {
	    add_ijump( $chainref1, $jump => $target );
	}

	add_ijump( $chainref , j => $chainref1, imatch_source_net( $source ),  @_ );
    } elsif ( $targetopts ) {
	add_ijump( $chainref,
		   $jump      => $target,
		   targetopts => $targetopts,
		   imatch_source_net( $source ),
		   @_ );
    } else {
	add_ijump( $chainref, $jump => $target, imatch_source_net( $source ), @_ );
    }
}

sub dest_exclusion( $$ ) {
    my ( $exclusions, $target ) = @_;

    return $target unless @$exclusions;

    my $table = reftype $target ? $target->{table} : 'filter';

    my $chainref = dont_move new_chain( $table , newexclusionchain( $table ) );

    add_ijump( $chainref, j => 'RETURN', imatch_dest_net( $_ ) ) for @$exclusions;
    add_ijump( $chainref, g => $target );

    reftype $target ? $chainref : $chainref->{name};
}

sub dest_iexclusion( $$$$$;@ ) {
    my $chainref   = shift;
    my $jump       = shift;
    my $target     = shift;
    my $targetopts = shift;
    my $dest       = shift;
    my $table      = $chainref->{table};

    my @exclusion;

    if ( $dest =~ /^([^!]+)!([^!]+)$/ ) {
	$dest = $1;
	@exclusion = split_host_list( $2, $config{DEFER_DNS_RESOLUTION} );

	my $chainref1 = dont_move new_chain( $table , newexclusionchain( $table ) );

	add_ijump( $chainref1 , j => 'RETURN', imatch_dest_net( $_ ) ) for @exclusion;

	if ( $targetopts ) {
	    add_ijump( $chainref1, $jump => $target, targetopts => $targetopts, @_ );
	} else {
	    add_ijump( $chainref1, $jump => $target, @_ );
	}

	add_ijump( $chainref , j => $chainref1, imatch_dest_net( $dest ), @_ );
    } elsif ( $targetopts ) {
	add_ijump( $chainref, $jump => $target, imatch_dest_net( $dest ), targetopts => $targetopts , @_ );
    } else {
	add_ijump( $chainref, $jump => $target, imatch_dest_net( $dest ), @_ );
    }
}

sub clearrule() {
    $iprangematch = 0;
}

#
# Generate a state match
#
sub state_match( $ ) {
    my $state = shift;

    if ( $state eq 'ALL' ) {
	''
    } else {
	have_capability( 'CONNTRACK_MATCH' ) ? ( "-m conntrack --ctstate $state " ) : ( "-m state --state $state " );
    }
}

sub state_imatch( $ ) {
    my $state = shift;

    unless ( $state eq 'ALL' ) {
	have_capability( 'CONNTRACK_MATCH' ) ? ( 'conntrack --ctstate' => $state ) : ( state => "--state $state" );
    } else {
	();
    }
}

#
# Handle parsing of PROTO, DEST PORT(S) , SOURCE PORTS(S). Returns the appropriate match string.
#
# If the optional argument is true, port lists > 15 result in a fatal error.
#
sub do_proto( $$$;$ )
{
    my ($proto, $ports, $sports, $restricted ) = @_;

    my $output = '';

    $proto  = '' if $proto  eq '-';
    $ports  = '' if $ports  eq '-';
    $sports = '' if $sports eq '-';

    if ( $proto ne '' ) {

	my $synonly  = ( $proto =~ s/:syn$//i );
	my $invert   = ( $proto =~ s/^!// ? '! ' : '' );
	my $protonum = resolve_proto $proto;

	if ( defined $protonum ) {
	    #
	    # Protocol is numeric and <= 255 or is defined in /etc/protocols or NSS equivalent
	    #
	    fatal_error "'!0' not allowed in the PROTO column" if $invert && ! $protonum;

	    my $pname = proto_name( $proto = $protonum );
	    #
	    # $proto now contains the protocol number and $pname contains the canonical name of the protocol
	    #
	    unless ( $synonly ) {
		$output  = "${invert}-p ${proto} ";
	    } else {
		fatal_error '":syn" is only allowed with tcp' unless $proto == TCP && ! $invert;
		$output = "-p $proto --syn ";
	    }

	    fatal_error "SOURCE/DEST PORT(S) not allowed with PROTO !$pname" if $invert && ($ports ne '' || $sports ne '');

	  PROTO:
	    {
		if ( $proto == TCP || $proto == UDP || $proto == SCTP || $proto == DCCP || $proto == UDPLITE ) {
		    my $multiport = ( $proto == UDPLITE );
		    my $srcndst   = 0;

		    if ( $ports ne '' ) {
			$invert = $ports =~ s/^!// ? '! ' : '';

			if ( $ports =~ /^\+/ ) {
			    $output .= $invert;
			    $output .= '-m set ';
			    $output .= get_set_flags( $ports, 'dst' );
			} else {
			    $sports = '', require_capability( 'MULTIPORT', "'=' in the SOURCE PORT(S) column", 's' ) if ( $srcndst = $sports eq '=' );

			    if ( $multiport || $ports =~ tr/,/,/ > 0 || $sports =~ tr/,/,/ > 0 ) {
				fatal_error "Port lists require Multiport support in your kernel/iptables" unless have_capability( 'MULTIPORT',1 );

				if ( port_count ( $ports ) > 15 ) {
				    if ( $restricted ) {
					fatal_error "A port list in this file may only have up to 15 ports";
				    } elsif ( $invert ) {
					fatal_error "An inverted port list may only have up to 15 ports";
				    }
				}

				$ports = validate_port_list $pname , $ports;
				$output .= ( $srcndst ? "-m multiport ${invert}--ports ${ports} " : "-m multiport ${invert}--dports ${ports} " );
				$multiport = 1;
			    }  else {
				fatal_error "Missing DEST PORT" unless supplied $ports;
				$ports   = validate_portpair $pname , $ports;
				$output .= ( $srcndst ? "-m multiport ${invert}--ports ${ports} " : "${invert}--dport ${ports} " );
			    }
			}
		    } else {
			$multiport ||= ( $sports =~ tr/,/,/ ) > 0 ;;
		    }

		    if ( $multiport && $proto != TCP && $proto != UDP ) {
			require_capability( 'EMULTIPORT', 'Protocol ' . ( $pname || $proto ), 's' );
		    }

		    if ( $sports ne '' ) {
			fatal_error "'=' in the SOURCE PORT(S) column requires one or more ports in the DEST PORT(S) column" if $sports eq '=';

			$invert = $sports =~ s/^!// ? '! ' : '';

			if ( $ports =~ /^\+/ ) {
			    $output .= $invert;
			    $output .= '-m set ';
			    $output .= get_set_flags( $ports, 'src' );
			} elsif ( $multiport ) {
			    if ( port_count( $sports ) > 15 ) {
				if ( $restricted ) {
				    fatal_error "A port list in this file may only have up to 15 ports";
				} elsif ( $invert ) {
				    fatal_error "An inverted port list may only have up to 15 ports";
				}
			    }

			    $sports = validate_port_list $pname , $sports;
			    $output .= "-m multiport ${invert}--sports ${sports} ";
			}  else {
			    fatal_error "Missing SOURCE PORT" unless supplied $sports;
			    $sports  = validate_portpair $pname , $sports;
			    $output .= "${invert}--sport ${sports} ";
			}
		    }

		    last PROTO;	}

		if ( $proto == ICMP ) {
		    fatal_error "ICMP not permitted in an IPv6 configuration" if $family == F_IPV6; #User specified proto 1 rather than 'icmp'
		    if ( $ports ne '' ) {
			$invert = $ports =~ s/^!// ? '! ' : '';

			my $types;

			if ( $ports =~ /,/ ) {
			    fatal_error "An inverted ICMP list may only contain a single type" if $invert;
			    fatal_error "An ICMP type list is not allowed in this context"     if $restricted;
			    $types = '';
			    for my $type ( split_list( $ports, 'ICMP type list' ) ) {
				$types = $types ? join( ',', $types, validate_icmp( $type ) ) : $type;
			    }
			} else {
			    $types = validate_icmp $ports;
			}

			$output .= "${invert}--icmp-type ${types} ";
		    }

		    fatal_error 'SOURCE PORT(S) not permitted with ICMP' if $sports ne '';

		    last PROTO; }

		if ( $proto == IPv6_ICMP ) {
		    fatal_error "IPv6_ICMP not permitted in an IPv4 configuration" if $family == F_IPV4;
		    if ( $ports ne '' ) {
			$invert = $ports =~ s/^!// ? '! ' : '';

			my $types;

			if ( $ports =~ /,/ ) {
			    fatal_error "An inverted ICMP list may only contain a single type" if $invert;
			    fatal_error "An ICMP type list is not allowed in this context"     if $restricted;
			    $types = '';
			    for my $type ( split_list( $ports, 'ICMP type list' ) ) {
				$types = $types ? join( ',', $types, validate_icmp6( $type ) ) : $type;
			    }
			} else {
			    $types = validate_icmp6 $ports;
			}

			$output .= "${invert}--icmpv6-type ${types} ";
		    }

		    fatal_error 'SOURCE PORT(S) not permitted with IPv6-ICMP' if $sports ne '';

		    last PROTO; }


		fatal_error "SOURCE/DEST PORT(S) not allowed with PROTO $pname" if $ports ne '' || $sports ne '';

	    } # PROTO

	} else {
	    fatal_error '":syn" is only allowed with tcp' if $synonly;

	    if ( $proto =~ /^(ipp2p(:(tcp|udp|all))?)$/i ) {
		my $p = $2 ? lc $3 : 'tcp';
		require_capability( 'IPP2P_MATCH' , "PROTO = $proto" , 's' );
		$proto = '-p ' . proto_name($p) . ' ';

		my $options = '';

		if ( $ports ne 'ipp2p' ) {
		    $options .= " --$_" for split /,/, $ports;
		}

		$options = have_capability( 'OLD_IPP2P_MATCH' ) ? ' --ipp2p' : ' --edk --kazaa --gnu --dc' unless $options;

		$output .= "${proto}-m ipp2p${options} ";
	    } else {
		fatal_error "Invalid/Unknown protocol ($proto)"
	    }
	}
    } else {
	#
	# No protocol
	#
	fatal_error "SOURCE/DEST PORT(S) not allowed without PROTO" if $ports ne '' || $sports ne '';
    }

    $output;
}


sub do_mac( $ ) {
    my $mac = $_[0];

    $mac =~ s/^(!?)~//;
    my $invert = ( $1 ? '! ' : '');
    $mac =~ tr/-/:/;

    fatal_error "Invalid MAC address ($mac)" unless $mac =~ /^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/;

    "-m mac ${invert}--mac-source $mac ";
}

sub do_iproto( $$$ )
{
    my ($proto, $ports, $sports ) = @_;

    my @output = ();

    my $restricted = 1;

    $proto  = '' if $proto  eq '-';
    $ports  = '' if $ports  eq '-';
    $sports = '' if $sports eq '-';

    if ( $proto ne '' ) {

	my $synonly  = ( $proto =~ s/:syn$//i );
	my $invert   = ( $proto =~ s/^!// ? '! ' : '' );
	my $protonum = resolve_proto $proto;

	if ( defined $protonum ) {
	    #
	    # Protocol is numeric and <= 255 or is defined in /etc/protocols or NSS equivalent
	    #
	    fatal_error "'!0' not allowed in the PROTO column" if $invert && ! $protonum;

	    my $pname = proto_name( $proto = $protonum );
	    #
	    # $proto now contains the protocol number and $pname contains the canonical name of the protocol
	    #
	    unless ( $synonly ) {
		@output = ( p => "${invert}${proto}" );
	    } else {
		fatal_error '":syn" is only allowed with tcp' unless $proto == TCP && ! $invert;
		@output = ( p => "$proto --syn" );
	    }

	    fatal_error "SOURCE/DEST PORT(S) not allowed with PROTO !$pname" if $invert && ($ports ne '' || $sports ne '');

	  PROTO:
	    {
		if ( $proto == TCP || $proto == UDP || $proto == SCTP || $proto == DCCP || $proto == UDPLITE ) {
		    my $multiport = ( $proto == UDPLITE );
		    my $srcndst   = 0;

		    if ( $ports ne '' ) {
			$invert  = $ports =~ s/^!// ? '! ' : '';

			if ( $ports =~ /^\+/ ) {
			    push @output , set => ${invert} . get_set_flags( $ports, 'dst' );
			} else {
			    $sports = '', require_capability( 'MULTIPORT', "'=' in the SOURCE PORT(S) column", 's' ) if ( $srcndst = $sports eq '=' );

			    if ( $multiport || $ports =~ tr/,/,/ > 0 || $sports =~ tr/,/,/ > 0 ) {
				fatal_error "Port lists require Multiport support in your kernel/iptables" unless have_capability( 'MULTIPORT' , 1 );

				if ( port_count ( $ports ) > 15 ) {
				    if ( $restricted ) {
					fatal_error "A port list in this file may only have up to 15 ports";
				    } elsif ( $invert ) {
					fatal_error "An inverted port list may only have up to 15 ports";
				    }
				}

				$ports = validate_port_list $pname , $ports;
				push @output, multiport => ( $srcndst ? "${invert}--ports ${ports} " : "${invert}--dports ${ports} " );
				$multiport = 1;
			    }  else {
				fatal_error "Missing DEST PORT" unless supplied $ports;
				$ports   = validate_portpair $pname , $ports;

				if ( $srcndst ) {
				    push @output, multiport => "${invert}--ports ${ports}";
				} else {
				    push @output, dport => "${invert}${ports}";
				}
			    }
			}
		    } else {
			$multiport ||= ( ( $sports =~ tr/,/,/ ) > 0 );
		    }

		    if ( $sports ne '' ) {
			fatal_error "'=' in the SOURCE PORT(S) column requires one or more ports in the DEST PORT(S) column" if $sports eq '=';
			$invert = $sports =~ s/^!// ? '! ' : '';

			if ( $ports =~ /^\+/ ) {
			    push @output, set => ${invert} . get_set_flags( $ports, 'src' );
			} elsif ( $multiport ) {
			    if ( port_count( $sports ) > 15 ) {
				if ( $restricted ) {
				    fatal_error "A port list in this file may only have up to 15 ports";
				} elsif ( $invert ) {
				    fatal_error "An inverted port list may only have up to 15 ports";
				}
			    }

			    $sports = validate_port_list $pname , $sports;
			    push @output, multiport => "${invert}--sports ${sports}";
			}  else {
			    fatal_error "Missing SOURCE PORT" unless supplied $sports;
			    $sports  = validate_portpair $pname , $sports;
			    push @output, sport => "${invert}${sports}";
			}
		    }

		    last PROTO;	}

		if ( $proto == ICMP ) {
		    fatal_error "ICMP not permitted in an IPv6 configuration" if $family == F_IPV6; #User specified proto 1 rather than 'icmp'
		    if ( $ports ne '' ) {
			$invert = $ports =~ s/^!// ? '! ' : '';

			my $types;

			if ( $ports =~ /,/ ) {
			    fatal_error "An inverted ICMP list may only contain a single type" if $invert;
			    fatal_error "An ICMP type list is not allowed in this context"     if $restricted;
			    $types = '';
			    for my $type ( split_list( $ports, 'ICMP type list' ) ) {
				$types = $types ? join( ',', $types, validate_icmp( $type ) ) : $type;
			    }
			} else {
			    $types = validate_icmp $ports;
			}

			push @output, 'icmp-type' => "${invert}${types}";
		    }

		    fatal_error 'SOURCE PORT(S) not permitted with ICMP' if $sports ne '';

		    last PROTO; }

		if ( $proto == IPv6_ICMP ) {
		    fatal_error "IPv6_ICMP not permitted in an IPv4 configuration" if $family == F_IPV4;
		    if ( $ports ne '' ) {
			$invert = $ports =~ s/^!// ? '! ' : '';

			my $types;

			if ( $ports =~ /,/ ) {
			    fatal_error "An inverted ICMP list may only contain a single type" if $invert;
			    fatal_error "An ICMP type list is not allowed in this context"     if $restricted;
			    $types = '';
			    for my $type ( split_list( $ports, 'ICMP type list' ) ) {
				$types = $types ? join( ',', $types, validate_icmp6( $type ) ) : $type;
			    }
			} else {
			    $types = validate_icmp6 $ports;
			}

			push @output, 'icmpv6-type' => "${invert}${types}";
		    }

		    fatal_error 'SOURCE PORT(S) not permitted with IPv6-ICMP' if $sports ne '';

		    last PROTO; }

		fatal_error "SOURCE/DEST PORT(S) not allowed with PROTO $pname" if $ports ne '' || $sports ne '';

	    } # PROTO

	} else {
	    fatal_error '":syn" is only allowed with tcp' if $synonly;

	    if ( $proto =~ /^(ipp2p(:(tcp|udp|all))?)$/i ) {
		my $p = $2 ? lc $3 : 'tcp';
		require_capability( 'IPP2P_MATCH' , "PROTO = $proto" , 's' );
		$proto = '-p ' . proto_name($p) . ' ';

		my $options = '';

		if ( $ports ne 'ipp2p' ) {
		    $options .= " --$_" for split /,/, $ports;
		}

		$options = have_capability( 'OLD_IPP2P_MATCH' ) ? ' --ipp2p' : ' --edk --kazaa --gnu --dc' unless $options;

		push @output, ipp2p => "${proto}${options}";
	    } else {
		fatal_error "Invalid/Unknown protocol ($proto)"
	    }
	}
    } else {
	#
	# No protocol
	#
	fatal_error "SOURCE/DEST PORT(S) not allowed without PROTO" if $ports ne '' || $sports ne '';
    }

    @output;
}

sub do_imac( $ ) {
    my $mac = $_[0];

    $mac =~ s/^(!?)~//;
    my $invert = ( $1 ? '! ' : '');
    $mac =~ tr/-/:/;

    fatal_error "Invalid MAC address ($mac)" unless $mac =~ /^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/;

    ( mac => "${invert}--mac-source $mac" );
}

#
# Mark validation functions
#
sub verify_mark( $ ) {
    my $mark  = $_[0];
    my $limit = $globals{EXCLUSION_MASK};
    my $mask  = $globals{TC_MASK};
    my $value = numeric_value( $mark );

    fatal_error "Invalid Mark or Mask value ($mark)"
	unless defined( $value ) && $value < $limit;

    if ( $value > $mask ) {
	#
	# Not a valid TC mark -- must be a provider mark or a user mark
	#
	fatal_error "Invalid Mark or Mask value ($mark)"
	    unless( ( $value & $globals{PROVIDER_MASK} ) == $value ||
		    ( $value & $globals{USER_MASK} ) == $value ||
		    ( $value & $globals{ZONE_MASK} ) == $value );
    }
}

sub validate_mark( $ ) {
    my $mark = shift;
    my $val;
    fatal_error "Missing MARK" unless supplied $mark;

    if ( $mark =~ '/' ) {
	my @marks = split '/', $mark;
	fatal_error "Invalid MARK ($mark)" unless @marks == 2;
	verify_mark $_ for @marks;
	$val = $marks[0];
    } else {
	verify_mark $mark;
	$val = $mark;
    }

    return numeric_value $val if defined( wantarray );
}

sub verify_small_mark( $ ) {
    my $val = validate_mark ( (my $mark) = $_[0] );
    fatal_error "Mark value ($mark) too large" if numeric_value( $mark ) > $globals{SMALL_MAX};
    $val;
}

#
# Generate an appropriate -m [conn]mark match string for the contents of a MARK column
#

sub do_test ( $$ )
{
    my ($testval, $mask) = @_;

    my $originaltestval = $testval;

    return '' unless defined $testval and $testval ne '-';

    $mask = '' unless defined $mask;

    my $invert = $testval =~ s/^!// ? '! ' : '';

    if ( $config{ZONE_BITS} ) {
	$testval = join( '/', in_hex( zone_mark( $testval ) ), in_hex( $globals{ZONE_MASK} ) ) unless $testval =~ /^\d/ || $testval =~ /:/;
    }

    my $match  = $testval =~ s/:C$// ? "-m connmark ${invert}--mark" : "-m mark ${invert}--mark";

    fatal_error "Invalid MARK value ($originaltestval)" if $testval eq '/';

    validate_mark $testval;

    $testval = join( '/', $testval, in_hex($mask) ) unless ( $testval =~ '/' );

    "$match $testval ";
}

my %norate = ( DROP => 1, REJECT => 1 );

#
# Create a "-m limit" match for the passed LIMIT/BURST
#
sub do_ratelimit( $$ ) {
    my ( $rates, $action ) = @_;

    return '' unless $rates and $rates ne '-';

    fatal_error "Rate Limiting not available with $action" if $norate{$action};

    my @rates = split_list $rates, 'rate';

    if ( @rates == 2 ) {
	$rates[0] = 's:' . $rates[0];
	$rates[1] = 'd:' . $rates[1];
    } elsif ( @rates > 2 ) {
	fatal error "Only two rates may be specified";
    }

    my $limit = '';

    for my $rate ( @rates ) {
	#
	# "-m hashlimit" match for the passed LIMIT/BURST
	#
	if ( $rate =~ /^([sd]):{1,2}/ ) {
	    require_capability 'HASHLIMIT_MATCH', 'Per-ip rate limiting' , 's';

	    my $match = have_capability( 'OLD_HL_MATCH' ) ? 'hashlimit' : 'hashlimit-upto';
	    my $units;

	    $limit .= "-m hashlimit ";
	    
	    if ( $rate =~ /^[sd]:((\w*):)?((\d+)(\/(sec|min|hour|day))?):(\d+)$/ ) {
		fatal_error "Invalid Rate ($3)" unless $4;
		fatal_error "Invalid Burst ($7)" unless $7;
		$limit .= "--$match $3 --hashlimit-burst $7 --hashlimit-name ";
		$limit .= $2 ? $2 : 'shorewall' . $hashlimitset++;
		$limit .= ' --hashlimit-mode ';
		$units = $6;
	    } elsif ( $rate =~ /^[sd]:((\w*):)?((\d+)(\/(sec|min|hour|day))?)$/ ) {
		fatal_error "Invalid Rate ($3)" unless $4;
		$limit .= "--$match $3 --hashlimit-name ";
		$limit .= $2 ? $2 :  'shorewall' . $hashlimitset++;
		$limit .= ' --hashlimit-mode ';
		$units = $6;
	    } else {
		fatal_error "Invalid rate ($rate)";
	    }

	    $limit .= $rate =~ /^s:/ ? 'srcip ' : 'dstip ';

	    if ( $units && $units ne 'sec' ) {
		my $expire = 60000; # 1 minute in milliseconds

		if ( $units ne 'min' ) {
		    $expire *= 60; #At least an hour
		    $expire *= 24 if $units eq 'day';
		}

		$limit .= "--hashlimit-htable-expire $expire ";
	    }
	} else {
	    if ( $rate =~ /^((\d+)(\/(sec|min|hour|day))?):(\d+)$/ ) {
		fatal_error "Invalid Rate ($1)" unless $2;
		fatal_error "Invalid Burst ($5)" unless $5;
		$limit = "-m limit --limit $1 --limit-burst $5 ";
	    } elsif ( $rate =~ /^(\d+)(\/(sec|min|hour|day))?$/ )  {
		fatal_error "Invalid Rate (${1}${2})" unless $1;
		$limit = "-m limit --limit $rate ";
	    } else {
		fatal_error "Invalid rate ($rate)";
	    }
	}
    }

    $limit;
}

#
# Create a "-m connlimit" match for the passed CONNLIMIT
#
sub do_connlimit( $ ) {
    my ( $limit ) = @_;

    return '' if $limit eq '-';

    require_capability 'CONNLIMIT_MATCH', 'A non-empty CONNLIMIT', 's';

    my $destination = $limit =~ s/^d:// ? '--connlimit-daddr ' : '';

    my $invert =  $limit =~ s/^!// ? '' : '! '; # Note Carefully -- we actually do 'connlimit-at-or-below'

    if ( $limit =~ /^(\d+):(\d+)$/ ) {
	fatal_error "Invalid Mask ($2)" unless $2 > 0 || $2 < 31;
	"-m connlimit ${invert}--connlimit-above $1 --connlimit-mask $2 $destination";
    } elsif ( $limit =~ /^(\d+)$/ )  {
	"-m connlimit ${invert}--connlimit-above $limit $destination";
    } else {
	fatal_error "Invalid connlimit ($limit)";
    }
}

sub do_time( $ ) {
    my ( $time ) = @_;

    return '' if $time eq '-';

    require_capability 'TIME_MATCH', 'A non-empty TIME', 's';

    my $result = '-m time ';

    for my $element (split /&/, $time ) {
	fatal_error "Invalid time element list ($time)" unless defined $element && $element;

	if ( $element =~ /^(timestart|timestop)=(\d{1,2}:\d{1,2}(:\d{1,2})?)$/ ) {
	    $result .= "--$1 $2 ";
	} elsif ( $element =~ /^weekdays=(.*)$/ ) {
	    my $days = $1;
	    for my $day ( split /,/, $days ) {
		fatal_error "Invalid weekday ($day)" unless $day =~ /^(Mon|Tue|Wed|Thu|Fri|Sat|Sun)$/ || ( $day =~ /^\d$/ && $day && $day <= 7);
	    }
	    $result .= "--weekday $days ";
	} elsif ( $element =~ /^monthdays=(.*)$/ ) {
	    my $days = $1;
	    for my $day ( split /,/, $days ) {
		fatal_error "Invalid day of the month ($day)" unless $day =~ /^\d{1,2}$/ && $day && $day <= 31;
	    }
	    $result .= "--monthday $days ";
	} elsif ( $element =~ /^(datestart|datestop)=(\d{4}(-\d{2}(-\d{2}(T\d{1,2}(:\d{1,2}){0,2})?)?)?)$/ ) {
	    $result .= "--$1 $2 ";
	} elsif ( $element =~ /^(utc|localtz|kerneltz)$/ ) {
	    $result .= "--$1 ";
	} else {
	    fatal_error "Invalid time element ($element)";
	}
    }

    $result;
}

sub resolve_id( $$ ) {
    my ( $id, $type ) = @_;

    if ( $globals{EXPORT} ) {
	require_capability 'OWNER_NAME_MATCH', "Specifying a $type name", 's';
    } else {
	my $num = $type eq 'user' ? getpwnam( $id ) : getgrnam( $id );
	fatal_error "Unknown $type ($id)" unless supplied $num && $num  >= 0;
	$id = $num;
    }

    $id;
}


#
# Create a "-m owner" match for the passed USER/GROUP
#
sub do_user( $ ) {
    my $user = $_[0];
    my $rule = '-m owner ';

    return '' unless defined $user and $user ne '-';

    require_capability 'OWNER_MATCH', 'A non-empty USER column', 's';

    assert( $user =~ /^(!)?(.*?)(:(.+))?$/ );
    my $invert = $1 ? '! ' : '';
    my $group  = supplied $4 ? $4 : '';

    if ( supplied $2 ) {
	$user  = $2;
	if ( $user =~ /^(\d+)(-(\d+))?$/ ) {
	    if ( supplied $2 ) {
		fatal_error "Invalid User Range ($user)" unless $3 >= $1;
	    }
	} else {
	    $user  = resolve_id( $user, 'user' );
	}

	$rule .= "${invert}--uid-owner $user ";
    }

    if ( $group ne '' ) {
	if ( $group =~ /^(\d+)(-(\d+))?$/ ) {
	    if ( supplied $2 ) {
		fatal_error "Invalid Group Range ($group)" unless $3 >= $1;
	    }
	} else {
	    $group = resolve_id( $group, 'group' );
	}

	$rule .= "${invert}--gid-owner $group ";
    }

    $rule;
}

#
# Create a "-m tos" match for the passed TOS
#
# This helper is also used during tos file processing
#
sub decode_tos( $$ ) {
    my ( $tos, $set ) = @_;

    if ( $tos eq '-' ) {
	fatal_error [ '',                                            # 0
		      'A value must be supplied in the TOS column',  # 1
		      'Invalid TOS() parameter (-)',                 # 2
		    ]->[$set] if $set;
	return '';
    }

    my $mask = have_capability( 'NEW_TOS_MATCH' ) ? 0xff : '';
    my $value;

    if ( $tos =~ m|^(.+)/(.+)$| ) {
	require_capability 'NEW_TOS_MATCH', 'A mask', 's';
	$value = numeric_value $1;
	$mask  = numeric_value $2;
    } elsif ( ! defined ( $value = numeric_value( $tos ) ) ) {
	$value = $tosmap{$tos};
	$mask  = '';
    }

    fatal_error( [ 'Invalid TOS column value',
		   'Invalid TOS column value',
		   'Invalid TOS() parameter', ]->[$set] . " ($tos)" )
	unless ( defined $value &&
		 $value <= 0xff &&
		 ( $mask eq '' ||
		   ( defined $mask &&
		     $mask <= 0xff ) ) );

    unless ( $mask eq '' ) {
	warning_message "Unmatchable TOS ($tos)" unless $set || $value & $mask;
    }

    $tos = $mask ? in_hex( $value) . '/' . in_hex( $mask ) . ' ' : in_hex( $value ) . ' ';

    $set ? " --set-tos $tos" : "-m tos --tos $tos ";

}

sub do_tos( $ ) {
    decode_tos( $_[0], 0 );
}

my %dir = ( O => 'original' ,
	    R => 'reply' ,
	    B => 'both' );

my %mode = ( P => 'packets' ,
	     B => 'bytes' ,
	     A => 'avgpkt' );

#
# Create a "-m connbytes" match for the passed argument
#
sub do_connbytes( $ ) {
    my $connbytes = $_[0];

    return '' if $connbytes eq '-';
    #                                                                    1     2      3        5       6
    fatal_error "Invalid CONNBYTES ($connbytes)" unless $connbytes =~ /^(!)? (\d+): (\d+)? ((:[ORB]) (:[PBA])?)?$/x;

    my $invert = $1 || ''; $invert = '! ' if $invert;
    my $min    = $2;       $min    = 0  unless defined $min;
    my $max    = $3;       $max    = '' unless defined $max; fatal_error "Invalid byte range ($min:$max)" if $max ne '' and $min > $max;
    my $dir    = $5 || 'B';
    my $mode   = $6 || 'B';

    $dir  =~ s/://;
    $mode =~ s/://;

    "-m connbytes ${invert}--connbytes $min:$max --connbytes-dir $dir{$dir} --connbytes-mode $mode{$mode} ";
}

#
# Validate a helper/protocol pair
#
sub validate_helper( $;$ ) {
    my ( $helper, $proto ) = @_;
    my $helper_base = $helper;
    $helper_base =~ s/-\d+$//;

    my $helper_proto = $helpers{$helper_base};

    if ( $helper_proto) {
	#
	#  Recognized helper
	#
	my $capability      = $helpers_map{defined $proto ? $helper : $helper_base};
	my $external_helper = lc $capability;
	
	$external_helper =~ s/_helper//;
	$external_helper =~ s/_/-/;

	fatal_error "The $external_helper helper is not enabled" unless $helpers_enabled{$external_helper};

	if ( supplied $proto ) {
	    require_capability $helpers_map{$helper}, "Helper $helper", 's';

	    my $protonum = -1;

	    fatal_error "Unknown PROTO ($proto)" unless defined ( $protonum = resolve_proto( $proto ) );

	    unless ( $protonum == $helper_proto ) {
		fatal_error "The $helper_base helper requires PROTO=" . (proto_name $helper_proto );
	    }
	}
    } else {
	fatal_error "Unrecognized helper ($helper_base)";
    }
}

#
# Create an "-m helper" match for the passed argument
#
sub do_helper( $ ) {
    my $helper = shift;

    return '' if $helper eq '-';

    validate_helper( $helper );

    if ( defined wantarray ) {
	$helper = $helpers_aliases{$helper} || $helper;
	qq(-m helper --helper $helper );
    }
}

#
# Create a "-m length" match for the passed LENGTH
#
sub do_length( $ ) {
    my $length = $_[0];

    return '' if $length eq '-';

    require_capability( 'LENGTH_MATCH' , 'A Non-empty LENGTH' , 's' );

    my ( $max, $min );

    if ( $length =~ /^\d+$/ ) {
	fatal_error "Invalid LENGTH ($length)" unless $length < 65536;
	$min = $max = $1;
    } else {
	if ( $length =~ /^:(\d+)$/ ) {
	    $min = 0;
	    $max = $1;
	} elsif ( $length =~ /^(\d+):$/ ) {
	    $min = $1;
	    $max = 65535;
	} elsif ( $length =~ /^(\d+):(\d+)$/ ) {
	    $min = $1;
	    $max = $2;
	} else {
	    fatal_error "Invalid LENGTH ($length)";
	}

	fatal_error "First length must be < second length" unless $min < $max;
    }

    "-m length --length $length ";
}

#
# Create a "-m -ipv6header" match for the passed argument
#
my %headers = ( hop          => 1,
		dst          => 1,
		route        => 1,
		frag         => 1,
		auth         => 1,
		esp          => 1,
		none         => 1,
		'hop-by-hop' => 1,
		'ipv6-opts'  => 1,
		'ipv6-route' => 1,
		'ipv6-frag'  => 1,
		ah           => 1,
		'ipv6-nonxt' => 1,
		'protocol'   => 1,
		0            => 1,
		43           => 1,
		44           => 1,
		50           => 1,
		51           => 1,
		59           => 1,
		60           => 1,
		255          => 1 );

sub do_headers( $ ) {
    my $headers = shift;

    return '' if $headers eq '-';

    require_capability 'HEADER_MATCH', 'A non-empty HEADER column', 's';

    my $invert = $headers =~ s/^!// ? '! ' : "";

    my $soft   = '--soft ';

    if ( $headers =~ s/^exactly:// ) {
	$soft = '';
    } else {
	$headers =~ s/^any://;
    }

    for ( split_list $headers, "Header" ) {
	if ( $_ eq 'proto' ) {
	    $_ = 'protocol';
	} else {
	    fatal_error "Unknown IPv6 Header ($_)" unless $headers{$_};
	}
    }

    "-m ipv6header ${invert}--header ${headers} ${soft} ";
}

sub do_probability( $ ) {
    my $probability = shift;

    return '' if $probability eq '-';

    require_capability 'STATISTIC_MATCH', 'A non-empty PROBABILITY column', 's';

    my $invert = $probability =~ s/^!// ? '! ' : "";

    fatal_error "Invalid PROBABILITY ($probability)" unless $probability =~ /^0?\.\d{1,8}$/;

    "-m statistic --mode random --probability $probability ";
}

#
# Generate a -m condition match
#
sub do_condition( $$ ) {
    my ( $condition, $chain ) = @_;

    return '' if $condition eq '-';

    my $invert = $condition =~ s/^!// ? '! ' : '';

    my $initialize;

    $initialize = $1 if $condition =~ s/(?:=([01]))?$//;

    require_capability 'CONDITION_MATCH', 'A non-empty SWITCH column', 's';

    $chain =~ s/[^\w-]//g;
    #                          $1    $2      -     $3
    while ( $condition =~ m( ^(.*?) @({)?(?:0|chain)(?(2)}) (.*)$ )x ) {
	$condition = join( '', $1, $chain, $3 );
    }

    fatal_error "Invalid switch name ($condition)" unless $condition =~ /^[a-zA-Z][-\w]*$/ && length $condition <= 30;

    if ( defined $initialize ) {
	if ( my $switchref = $switches{$condition} ) {
	    fatal_error "Switch $condition was previously initialized to $switchref->{setting} at $switchref->{where}" unless $switchref->{setting} == $initialize;
	} else {
	    $switches{$condition} = { setting => $initialize, where => currentlineinfo };
	}
    }

    "-m condition ${invert}--condition $condition "
	
}

#
# Generate a -m dscp match
#
sub do_dscp( $ ) {
    my $dscp = shift;

    return '' if $dscp eq '-';

    require_capability 'DSCP_MATCH', 'A non-empty DSCP column', 's';

    my $invert = $dscp =~ s/^!// ? '! ' : '';
    my $value  = numeric_value( $dscp );

    $value = $dscpmap{$dscp} unless defined $value;

    fatal_error( "Invalid DSCP ($dscp)" ) unless defined $value && $value < 0x3f && ! ( $value & 1 );

    "-m dscp ${invert}--dscp $value ";
}

#
# Return nfacct match
#
sub do_nfacct( $ ) {
    "-m nfacct --nfacct-name @_ ";
}

#
# Match Source Interface
#
sub match_source_dev( $;$ ) {
    my ( $interface, $nodev ) = @_;;
    my $interfaceref =  known_interface( $interface );
    $interface = $interfaceref->{physical} if $interfaceref;
    return '' if $interface eq '+';
    if ( $interfaceref && $interfaceref->{options}{port} ) {
	if ( $nodev ) {
	    "-m physdev --physdev-in $interface ";
	} else {
	    my $bridgeref = find_interface $interfaceref->{bridge};
	    "-i $bridgeref->{physical} -m physdev --physdev-in $interface ";
	}
    } else {
	"-i $interface ";
    }
}

sub imatch_source_dev( $;$ ) {
    my ( $interface, $nodev ) = @_;;
    my $interfaceref =  known_interface( $interface );
    $interface = $interfaceref->{physical} if $interfaceref;
    return () if $interface eq '+';
    if ( $interfaceref && $interfaceref->{options}{port} ) {
	if ( $nodev ) {
	    ( physdev => "--physdev-in $interface" );
	} else {
	    my $bridgeref = find_interface $interfaceref->{bridge};
	    ( i => $bridgeref->{physical}, physdev => "--physdev-in $interface" );
	}
    } else {
	( i => $interface );
    }
}

#
# Match Dest device
#
sub match_dest_dev( $;$ ) {
    my ( $interface, $nodev ) = @_;;
    my $interfaceref =  known_interface( $interface );
    $interface = $interfaceref->{physical} if $interfaceref;
    return '' if $interface eq '+';
    if ( $interfaceref && $interfaceref->{options}{port} ) {
	if ( $nodev ) {
	    if ( have_capability( 'PHYSDEV_BRIDGE' ) ) {
		"-m physdev --physdev-is-bridged --physdev-out $interface ";
	    } else {
		"-m physdev --physdev-out $interface ";
	    }
	} else {
	    my $bridgeref = find_interface $interfaceref->{bridge};

	    if ( have_capability( 'PHYSDEV_BRIDGE' ) ) {
		"-o $bridgeref->{physical} -m physdev --physdev-is-bridged --physdev-out $interface ";
	    } else {
		"-o $bridgeref->{physical} -m physdev --physdev-out $interface ";
	    }
	}
    } else {
	"-o $interface ";
    }
}

sub imatch_dest_dev( $;$ ) {
    my ( $interface, $nodev ) = @_;;
    my $interfaceref =  known_interface( $interface );
    $interface = $interfaceref->{physical} if $interfaceref;
    return () if $interface eq '+';
    if ( $interfaceref && $interfaceref->{options}{port} ) {
	if ( $nodev ) {
	    if ( have_capability( 'PHYSDEV_BRIDGE' ) ) {
		( physdev => "--physdev-is-bridged --physdev-out $interface" );
	    } else {
		( physdev => "--physdev-out $interface" );
	    }
	} else {
	    my $bridgeref = find_interface $interfaceref->{bridge};

	    if ( have_capability( 'PHYSDEV_BRIDGE' ) ) {
		( o => $bridgeref->{physical}, physdev => "--physdev-is-bridged --physdev-out $interface" );
	    } else {
		( o => $bridgeref->{physical}, physdev => "--physdev-out $interface" );
	    }
	}
    } else {
	( o => $interface );
    }
}

#
# Avoid generating a second '-m iprange' in a single rule.
#
sub iprange_match() {
    my $match = '';

    require_capability( 'IPRANGE_MATCH' , 'Address Ranges' , '' );
    unless ( $iprangematch ) {
	$match = '-m iprange ';
	$iprangematch = 1 unless $globals{KLUDGEFREE};
    }

    $match;
}

#
# Get set flags (ipsets).
#
sub get_set_flags( $$ ) {
    my ( $setname, $option ) = @_;
    my $options = $option;
    my $extensions = '';

    require_capability( 'IPSET_MATCH' , 'ipset names in Shorewall configuration files' , '' );

    $ipset_rules++;

    $setname =~ s/^!//; # Caller has already taken care of leading !

    my $rest = '';

    if ( $setname =~ /^(.*)\[([1-6])(?:,(.+))?\]$/ ) {
	$setname  = $1;
	my $count = $2;
	$rest     = $3;

	$options .= ",$option" while --$count > 0;
    } elsif ( $setname =~ /^(.*)\[((?:src|dst)(?:,(?:src|dst))*)*(,?.+)?\]$/ ) {
	$setname = $1;
	$rest = $3;

	if ( supplied $2 ) {
	    $options = $2;
	    if ( supplied $rest ) {
		fatal_error "Invalid Option List (${options}${rest})" unless $rest =~ s/^,//;
	    }
	}

	my @options = split /,/, $options;
	my %typemap = ( src => 'Source', dst => 'Destination' );

	if ( $config{IPSET_WARNINGS} ) {
	    warning_message( "The '$options[0]' ipset flag is used in a $option column" ), unless $options[0] eq $option;
	}
    }

    if ( supplied $rest ) {
	my @extensions = split_list($rest, 'ipset option');

	for ( @extensions ) {
	    my ($extension, $relop, $value) = split /(<>|=|<|>)/, $_;

	    my $match = $ipset_extensions{$extension};

	    fatal_error "Unknown ipset option ($extension)" unless defined $match;
	    
	    require_capability ( ( $extension eq 'nomatch' ?
				   'IPSET_MATCH_NOMATCH'    :
				   'IPSET_MATCH_COUNTERS' ),
				 "The '$extension' option",
				 's' );
	    if ( $match ) {
		fatal_error "The $extension option does not require a value" if supplied $relop || supplied $value;
		$extensions .= "$match ";
	    } else {
		my $val;
		fatal_error "The $extension option requires a value" unless supplied $value;
		fatal_error "Invalid number ($value)" unless defined ( $val = numeric_value($value) );
		$extension = "--$extension";

		if ( $relop eq '<' ) {
		    $extension .= '-lt';
		} elsif ( $relop eq '>' ) {
		    $extension .= '-gt';
		} elsif ( $relop eq '=' ) {
		    $extension .= '-eq';
		} else {
		    $extension = join( ' ', '!',  $extension );
		    $extension .= '-eq';
		}

		$extension = join( ' ', $extension, $value );

		$extensions .= "$extension ";
	    }
	}
    }

    $setname =~ s/^\+//;

    if ( $config{IPSET_WARNINGS} ) {
	unless ( $export || $> != 0 ) {
	    unless ( $ipset_exists{$setname} ) {
		warning_message "Ipset $setname does not exist" unless qt "ipset -L $setname";
	    }

	    $ipset_exists{$setname} = 1; # Suppress subsequent checks/warnings
	}
    }

    fatal_error "Invalid ipset name ($setname)" unless $setname =~ /^(6_)?[a-zA-Z][-\w]*/;

    have_capability( 'OLD_IPSET_MATCH' ) ? "--set $setname $options " : "--match-set $setname $options $extensions";

}

sub have_ipset_rules() {
    $ipset_rules;
}

sub get_interface_address( $ );

sub get_interface_gateway ( $;$ );

sub record_runtime_address( $$;$ ) {
    my ( $addrtype, $interface, $protect ) = @_;

    if ( $interface =~ /^{([a-zA-Z_]\w*)}$/ ) {
	fatal_error "Mixed required/optional usage of address variable $1" if ( $address_variables{$1} || $addrtype ) ne $addrtype;
	$address_variables{$1} = $addrtype;
	return '$' . "$1 ";
    }

    fatal_error "Unknown interface address variable (&$interface)" unless known_interface( $interface );
    fatal_error "Invalid interface address variable (&$interface)" if $interface =~ /\+$/;

    my $addr;

    if ( $addrtype eq '&' ) {
	$addr = get_interface_address( $interface );
    } else {
	$addr = get_interface_gateway( $interface, $protect );
    }

    $addr . ' ';

}

#
# If the passed address is a run-time address variable for an optional interface, then
# begin a conditional rule block that tests the address for nil. Returns 1 if a conditional
# block was opened. The caller stores the result, and if the result is true the caller
# invokes conditional_rule_end() when the conditional block is complete.
#
sub conditional_rule( $$ ) {
    my ( $chainref, $address ) = @_;

    if ( $address =~ /^!?([&%])(.+)$/ ) {
	my ($type, $interface) = ($1, $2);

	if ( my $ref = known_interface $interface ) {
	    if ( $ref->{options}{optional} ) {
		my $variable;
		if ( $type eq '&' ) {
		    $variable = get_interface_address( $interface );
		    add_commands( $chainref , "if [ $variable != " . NILIP . ' ]; then' );
		} else {
		    $variable = get_interface_gateway( $interface );
		    add_commands( $chainref , qq(if [ -n "$variable" ]; then) );
		}

		incr_cmd_level $chainref;
		return 1;
	    }
	} elsif ( $type eq '%' && $interface =~ /^{([a-zA-Z_]\w*)}$/ ) {
	    fatal_error "Mixed required/optional usage of address variable $1" if ( $address_variables{$1} || $type ) ne $type;
	    $address_variables{$1} = $type;
	    add_commands( $chainref , "if [ \$$1 != " . NILIP . ' ]; then' );
	    incr_cmd_level $chainref;
	    return 1;
	}
    }

    0;
}

#
# End a conditional in a chain begun by conditional_rule(). Should only be called
# if conditional_rule() returned true.
#

sub conditional_rule_end( $ ) {
    my $chainref = shift;
    decr_cmd_level $chainref;
    add_commands( $chainref , "fi\n" );
}

#
# Populate %isocodes from the GeoIP database directory
#
sub load_isocodes() {
    my $isodir = $config{GEOIPDIR} || ISODIR;

    fatal_error "GEOIPDIR ($isodir) does not exist" unless -d $isodir;

    my @codes = `ls $isodir/*$family 2>/dev/null`;

    fatal_error "$isodir contains no IPv${family} entries" unless @codes;

    $isocodes{substr(basename($_),0,2)} = 1 for @codes;
}

#
# Match a Source.
#
sub match_source_net( $;$\$ ) {
    my ( $net, $restriction, $macref ) = @_;

    $restriction |= NO_RESTRICT;

    if ( ( $family == F_IPV4 && $net =~ /^(!?)(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$/ ) ||
	 ( $family == F_IPV6 && $net =~  /^(!?)(.*:.*)-(.*:.*)$/ ) ) {
	my ($addr1, $addr2) = ( $2, $3 );
	$net =~ s/!// if my $invert = $1 ? '! ' : '';
	validate_range $addr1, $addr2;
	return iprange_match . "${invert}--src-range $net ";
    }

    if ( $net =~ /^!?~/ ) {
	fatal_error "A MAC address($net) cannot be used in this context" if $restriction >= OUTPUT_RESTRICT;
	$$macref = 1 if $macref;
	return do_mac $net;
    }

    if ( $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/ ) {
	my $result = join( '', '-m set ', $1 ? '! ' : '', get_set_flags( $2, 'src' ) );
	if ( $3 ) {
	    require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
	    for ( my @objects = split_list $3, 'nfacct' ) {
		validate_nfobject( $_ );
		$result .= do_nfacct( $_ );
	    }
	}

	return $result;
    }

    if ( $net =~ /^\+\[(.+)\]$/ ) {
	my $result = '';
	my @sets = split_host_list( $1, 1, 1 );

	fatal_error "Multiple ipset matches require the Repeat Match capability in your kernel and iptables" unless $globals{KLUDGEFREE};

	for $net ( @sets ) {
	    fatal_error "Expected ipset name ($net)" unless $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/;
	    $result .= join( '', '-m set ', $1 ? '! ' : '', get_set_flags( $2, 'src' ) );
	    if ( $3 ) {
		require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
		for ( my @objects = split_list $3, 'nfacct' ) {
		    validate_nfobject( $_ );
		    $result .= do_nfacct( $_ );
		}
	    }
	}

	return $result;
    }

    if ( $net =~ /^(!?)\^([A-Z\d]{2})$/ || $net =~ /^(!?)\^\[([A-Z,\d]+)\]$/) {
	fatal_error "A countrycode list may not be used in this context" if $restriction & ( OUTPUT_RESTRICT | POSTROUTE_RESTRICT );

	require_capability 'GEOIP_MATCH', 'A country-code', '';

	load_isocodes unless %isocodes;

	my @countries = split_list $2, 'country-code';

	fatal_error "Too many Country Codes ($2)" if @countries > 15;
 
	for ( @countries ) {
	    fatal_error "Unknown or invalid Country Code ($_)" unless $isocodes{$_};
	}

	return join( '', '-m geoip ', $1 ? '! ' : '', '--src-cc ', $2 , ' ');
    }

    if ( $net =~ s/^!// ) {
	if ( $net =~ /^([&%])(.+)/ ) {
	    return '! -s ' . record_runtime_address $1, $2;
	}

	$net = validate_net $net, 1;
	return "! -s $net ";
    }

    if ( $net =~ /^([&%])(.+)/ ) {
	return '-s ' . record_runtime_address $1, $2;
    }

    $net = validate_net $net, 1;
    $net eq ALLIP ? '' : "-s $net ";
}

sub imatch_source_net( $;$\$ ) {
    my ( $net, $restriction, $macref ) = @_;

    $restriction |= NO_RESTRICT;

    if ( ( $family == F_IPV4 && $net =~ /^(!?)(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$/ ) ||
	 ( $family == F_IPV6 && $net =~  /^(!?)(.*:.*)-(.*:.*)$/ ) ) {
	my ($addr1, $addr2) = ( $2, $3 );
	$net =~ s/!// if my $invert = $1 ? '! ' : '';
	validate_range $addr1, $addr2;
	require_capability( 'IPRANGE_MATCH' , 'Address Ranges' , '' );
	return ( iprange => "${invert}--src-range $net" );
    }

    if ( $net =~ /^!?~/ ) {
	fatal_error "A MAC address($net) cannot be used in this context" if $restriction >= OUTPUT_RESTRICT;
	$$macref = 1 if $macref;
	return do_imac $net;
    }

    if ( $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/ ) {
	my @result = ( set => join( '', $1 ? '! ' : '', get_set_flags( $2, 'src' ) ) );
	if ( $3 ) {
	    require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
	    for ( my @objects = split_list $3, 'nfacct' ) {
		validate_nfobject( $_ );
		push( @result, ( nfacct => "--nfacct-name $_" ) );
	    }
	}

	return @result;
    }

    if ( $net =~ /^\+\[(.+)\]$/ ) {
	my @result = ();
	my @sets = split_host_list( $1, 1, 1 );

	fatal_error "Multiple ipset matches requires the Repeat Match capability in your kernel and iptables" unless $globals{KLUDGEFREE};

	for $net ( @sets ) {
	    fatal_error "Expected ipset name ($net)" unless $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/;
	    push @result , ( set => join( '', $1 ? '! ' : '', get_set_flags( $2, 'src' ) ) );
	    if ( $3 ) {
		require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
		for ( my @objects = split_list $3, 'nfacct' ) {
		    validate_nfobject( $_ );
		    push( @result, ( nfacct => "--nfacct-name $_" ) );
		}
	    }
	}

	return @result;
    }

    if ( $net =~ /^(!?)\^([A-Z\d]{2})$/ || $net =~ /^(!?)\^\[([A-Z,\d]+)\]$/) {
	fatal_error "A countrycode list may not be used in this context" if $restriction & ( OUTPUT_RESTRICT | POSTROUTE_RESTRICT );

	require_capability 'GEOIP_MATCH', 'A country-code', '';

	load_isocodes unless %isocodes;

	my @countries = split_list $2, 'country-code';

	fatal_error "Too many Country Codes ($2)" if @countries > 15;
 
	for ( @countries ) {
	    fatal_error "Unknown or invalid Country Code ($_)" unless $isocodes{$_};
	}

	return ( geoip => , join( '', $1 ? '! ' : '', '--src-cc ', $2 ) );
    }

    if ( $net =~ s/^!// ) {
	if ( $net =~ /^([&%])(.+)/ ) {
	    return  ( s => '! ' . record_runtime_address( $1, $2, 1 ) );
	}

	$net = validate_net $net, 1;
	return ( s => "! $net " );
    }

    if ( $net =~ /^([&%])(.+)/ ) {
	return ( s =>  record_runtime_address( $1, $2, 1 ) );
    }

    $net = validate_net $net, 1;
    $net eq ALLIP ? () : ( s => $net );
}

#
# Match a Destination.
#
sub match_dest_net( $;$ ) {
    my ( $net, $restriction ) = @_;

    $restriction |= 0;

    if ( ( $family == F_IPV4 && $net =~ /^(!?)(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$/ ) ||
	 ( $family == F_IPV6 && $net =~  /^(!?)(.*:.*)-(.*:.*)$/ ) ) {
	my ($addr1, $addr2) = ( $2, $3 );
	$net =~ s/!// if my $invert = $1 ? '! ' : '';
	validate_range $addr1, $addr2;
	return iprange_match . "${invert}--dst-range $net ";
    }

    if ( $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/ ) {
	my $result = join( '', '-m set ', $1 ? '! ' : '',  get_set_flags( $2, 'dst' ) );
	if ( $3 ) {
	    require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
	    for ( my @objects = split_list $3, 'nfacct' ) {
		validate_nfobject( $_ );
		$result .= do_nfacct( $_ );
	    }
	}

	return $result;
    }

    if ( $net =~ /^\+\[(.+)\]$/ ) {
	my $result = '';
	my @sets = split_host_list( $1, 1, 1 );

	fatal_error "Multiple ipset matches requires the Repeat Match capability in your kernel and iptables" unless $globals{KLUDGEFREE};

	for $net ( @sets ) {
	    fatal_error "Expected ipset name ($net)" unless $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/;
	    $result .= join( '', '-m set ', $1 ? '! ' : '', get_set_flags( $2, 'dst' ) );

	    if ( $3 ) {
		require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
		for ( my @objects = split_list $3, 'nfacct' ) {
		    validate_nfobject( $_ );
		    $result .= do_nfacct( $_ );
		}
	    }
	}

	return $result;
    }

    if ( $net =~ /^(!?)\^([A-Z\d]{2})$/ || $net =~ /^(!?)\^\[([A-Z,\d]+)\]$/) {
	fatal_error "A countrycode list may not be used in this context" if $restriction & (PREROUTE_RESTRICT | INPUT_RESTRICT );

	require_capability 'GEOIP_MATCH', 'A country-code', '';

	load_isocodes unless %isocodes;

	my @countries = split_list $2, 'country-code';

	fatal_error "Too many Country Codes ($2)" if @countries > 15;
 
	for ( @countries ) {
	    fatal_error "Unknown or invalid Country Code ($_)" unless $isocodes{$_};
	}

	return join( '', '-m geoip ', $1 ? '! ' : '', '--dst-cc ', $2, ' ' );
    }

    if ( $net =~ s/^!// ) {
	if ( $net =~ /^([&%])(.+)/ ) {
	    return '! -d ' . record_runtime_address $1, $2;
	}

	$net = validate_net $net, 1;
	return "! -d $net ";
    }

    if ( $net =~ /^([&%])(.+)/ ) {
	return '-d ' . record_runtime_address $1, $2;
    }

    $net = validate_net $net, 1;
    $net eq ALLIP ? '' : "-d $net ";
}

sub imatch_dest_net( $;$ ) {
    my ( $net, $restriction ) = @_;

    $restriction |= NO_RESTRICT;

    if ( ( $family == F_IPV4 && $net =~ /^(!?)(\d+\.\d+\.\d+\.\d+)-(\d+\.\d+\.\d+\.\d+)$/ ) ||
	 ( $family == F_IPV6 && $net =~  /^(!?)(.*:.*)-(.*:.*)$/ ) ) {
	my ($addr1, $addr2) = ( $2, $3 );
	$net =~ s/!// if my $invert = $1 ? '! ' : '';
	validate_range $addr1, $addr2;
	require_capability( 'IPRANGE_MATCH' , 'Address Ranges' , '' );
	return ( iprange => "${invert}--dst-range $net" );
    }

    if ( $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/ ) {
	my @result = ( set => join( '', $1 ? '! ' : '', get_set_flags( $2, 'dst' ) ) );
	if ( $3 ) {
	    require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
	    for ( my @objects = split_list $3, 'nfacct' ) {
		validate_nfobject( $_ );
		push( @result, ( nfacct => "--nfacct-name $_" ) );
	    }
	}

	return @result;
    }

    if ( $net =~ /^\+\[(.+)\]$/ ) {
	my @result;
	my @sets = split_host_list( $1, 1, 1 );

	fatal_error "Multiple ipset matches requires the Repeat Match capability in your kernel and iptables" unless $globals{KLUDGEFREE};

	for $net ( @sets ) {
	    fatal_error "Expected ipset name ($net)" unless $net =~ /^(!?)(?:\+?)((?:6_)?[a-zA-Z][-\w]*(?:\[.*\])?)(?:\((.+)\))?$/;
	    push @result , ( set => join( '', $1 ? '! ' : '', get_set_flags( $2, 'dst' ) ) );
	    if ( $3 ) {
		require_capability 'NFACCT_MATCH', "An nfacct object list ($3)", 's';
		for ( my @objects = split_list $3, 'nfacct' ) {
		    validate_nfobject( $_ );
		    push( @result, ( nfacct => "--nfacct-name $_" ) );
		}
	    }
	}

	return \@result;
    }

    if ( $net =~ /^(!?)\^([A-Z\d]{2})$/ || $net =~ /^(!?)\^\[([A-Z,\d]+)\]$/) {
	fatal_error "A countrycode list may not be used in this context" if $restriction & (PREROUTE_RESTRICT | INPUT_RESTRICT );

	require_capability 'GEOIP_MATCH', 'A country-code', '';

	load_isocodes unless %isocodes;

	my @countries = split_list $2, 'country-code';

	fatal_error "Too many Country Codes ($2)" if @countries > 15;
 
	for ( @countries ) {
	    fatal_error "Unknown or invalid Country Code ($_)" unless $isocodes{$_};
	}

	return ( geoip => , join( '', $1 ? '! ' : '', '--dst-cc ', $2 ) );
    }

    if ( $net =~ s/^!// ) {
	if ( $net =~ /^([&%])(.+)/ ) {
	    return ( d => '! ' . record_runtime_address( $1, $2, 1 ) );
	}

	$net = validate_net $net, 1;
	return ( d => "! $net " );
    }

    if ( $net =~ /^([&%])(.+)/ ) {
	return ( d => record_runtime_address( $1, $2, 1 ) );
    }

    $net = validate_net $net, 1;
    $net eq ALLIP ? () : ( d =>  $net );
}

#
# Match original destination
#
sub match_orig_dest ( $ ) {
    my $net = $_[0];

    return '' if $net eq ALLIP;
    return '' unless have_capability( 'CONNTRACK_MATCH' );

    if ( $net =~ s/^!// ) {
	if ( $net =~ /^&(.+)/ ) {
	    $net = record_runtime_address '&', $1;
	} else {
	    $net = validate_net $net, 1;
	}

	have_capability( 'OLD_CONNTRACK_MATCH' ) ? "-m conntrack --ctorigdst ! $net " : "-m conntrack ! --ctorigdst $net ";
    } else {
	if ( $net =~ /^&(.+)/ ) {
	    $net = record_runtime_address '&', $1;
	} else {
	    $net = validate_net $net, 1;
	}

	$net eq ALLIP ? '' : "-m conntrack --ctorigdst $net ";
    }
}

#
# Match Source IPSEC
#
sub match_ipsec_in( $$ ) {
    my ( $zone , $hostref ) = @_;
    my @match;
    my $zoneref    = find_zone( $zone );

    unless ( $zoneref->{super} || $zoneref->{type} == VSERVER ) {
	my $match = '--dir in --pol ';
	my $optionsref = $zoneref->{options};

	if ( $zoneref->{type} & IPSEC ) {
	    $match .= "ipsec $optionsref->{in_out}{ipsec}$optionsref->{in}{ipsec}";
	} elsif ( have_ipsec ) {
	    $match .= "$hostref->{ipsec} $optionsref->{in_out}{ipsec}$optionsref->{in}{ipsec}";
	} else {
	    return ();
	}

	@match = ( policy => $match );
    }

    @match;
}

sub match_ipsec_out( $$ ) {
    my ( $zone , $hostref ) = @_;
    my @match;
    my $zoneref    = find_zone( $zone );
    my $optionsref = $zoneref->{options};

    unless ( $optionsref->{super} || $zoneref->{type} == VSERVER ) {
	my $match = '--dir out --pol ';

	if ( $zoneref->{type} & IPSEC ) {
	    $match .= "ipsec $optionsref->{in_out}{ipsec}$optionsref->{out}{ipsec}";
	} elsif ( have_ipsec ) {
	    $match .= "$hostref->{ipsec} $optionsref->{in_out}{ipsec}$optionsref->{out}{ipsec}"
	} else {
	    return ();
	}

	@match = ( policy => $match );
    }

    @match;
}

#
# Handle a unidirectional IPSEC Options
#
sub do_ipsec_options($$$)
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
    my ( $dir, $policy, $list ) = @_;
    my $options = "-m policy --pol $policy --dir $dir ";
    my $fmt;

    for my $e ( split_list $list, 'IPSEC option' ) {
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

	fatal_error "Invalid IPSEC Option ($e)" unless $fmt;

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
# Handle a bi-directional IPSEC column
#
sub do_ipsec($$) {
    my ( $dir, $ipsec ) = @_;

    if ( $ipsec eq '-' ) {
	return '';
    }

    fatal_error "Non-empty IPSEC column requires policy match support in your kernel and iptables"  unless have_capability( 'POLICY_MATCH' );

    my @options = split_list $ipsec, 'IPSEC options';

    if ( @options == 1 ) {
	if ( lc( $options[0] ) =~ /^(yes|ipsec)$/ ) {
	    return do_ipsec_options $dir, 'ipsec', '';
	}

	if ( lc( $options[0] ) =~ /^(no|none)$/ ) {
	    return do_ipsec_options $dir, 'none', '';
	}
    }

    do_ipsec_options $dir, 'ipsec', join( ',', @options );
}

#
# Generate a log message
#
sub log_rule_limit( $$$$$$$$ ) {
    my ($level, $chainref, $chn, $dispo, $limit, $tag, $command, $matches ) = @_;

    my $prefix = '';
    my $chain       = get_action_chain_name  || $chn;
    my $disposition = get_action_disposition || $dispo;

    $level = validate_level $level; # Do this here again because this function can be called directly from user exits.

    return 1 if $level eq '';

    $matches .= ' ' if $matches && substr( $matches, -1, 1 ) ne ' ';

    unless ( $matches =~ /-m limit / ) {
	$limit = $globals{LOGLIMIT} unless $limit && $limit ne '-';
	$matches .= $limit if $limit;
    }

    if ( $config{LOGFORMAT} =~ /^\s*$/ ) {
	if ( $level =~ '^ULOG' ) {
	    $prefix = "-j $level ";
	} elsif  ( $level =~ /^NFLOG/ ) {
	    $prefix = "-j $level ";
	} else {
	    my $flags = $globals{LOGPARMS};

	    if ( $level =~ /^(.+)\((.*)\)$/ ) {
		$level = $1;
		$flags = join( ' ', $flags, $2 ) . ' ';
		$flags =~ s/,/ /g;
	    }

	    $prefix = "-j LOG ${flags}--log-level $level ";
	}
    } else {
	if ( $tag ) {
	    if ( $config{LOGTAGONLY} && $tag ne ',' ) {
		if ( $tag =~ /^,/ ) {
		    ( $disposition = $tag ) =~ s/,//;
		} elsif ( $tag =~ /,/ ) {
		    ( $chain, $disposition ) = split ',', $tag;
		} else { 
		    $chain = $tag;
		}

		$tag   = '';
	    } else {
		$tag .= ' ';
	    }
	} else {
	    $tag = '' unless defined $tag;
	}

	$disposition =~ s/\s+.*//;

	if ( $globals{LOGRULENUMBERS} ) {
	    $prefix = (sprintf $config{LOGFORMAT} , $chain , $chainref->{log}++, $disposition ) . $tag;
	} else {
	    $prefix = (sprintf $config{LOGFORMAT} , $chain , $disposition) . $tag;
	}

	if ( length $prefix > 29 ) {
	    $prefix = substr( $prefix, 0, 28 ) . ' ';
	    warning_message "Log Prefix shortened to \"$prefix\"";
	}

	if ( $level =~ '^ULOG' ) {
	    $prefix = "-j $level --ulog-prefix \"$prefix\" ";
	} elsif  ( $level =~ /^NFLOG/ ) {
	    $prefix = "-j $level --nflog-prefix \"$prefix\" ";
	} elsif ( $level =~ '^LOGMARK' ) {
	    $prefix = join( '', substr( $prefix, 0, 12 ) , ':' ) if length $prefix > 13;
	    $prefix = "-j $level --log-prefix \"$prefix\" ";
	} else {
	    my $options = $globals{LOGPARMS};

	    if ( $level =~ /^(.+)\((.*)\)$/ ) {
		$level   = $1;
		$options = join( ' ', $options, $2 ) . ' ';
		$options =~ s/,/ /g;
	    }

	    $prefix = "-j LOG ${options}--log-level $level --log-prefix \"$prefix\" ";
	}
    }

    if ( $command eq 'add' ) {
	add_rule ( $chainref, $matches . $prefix , 1 );
    } else {
	insert_rule1 ( $chainref , 0 , $matches . $prefix );
    }
}

sub log_irule_limit( $$$$$$$@ ) {
    my ($level, $chainref, $chn, $dispo, $limit, $tag, $command, @matches ) = @_;

    my $prefix = '';
    my %matches;
    my $chain       = get_action_chain_name  || $chn;
    my $disposition = get_action_disposition || $dispo;

    $level = validate_level $level; # Do this here again because this function can be called directly from user exits.

    return 1 if $level eq '';

    %matches = @matches;

    unless ( $matches{limit} || $matches{hashlimit} ) {
	$limit = $globals{LOGILIMIT} unless @$limit;
	push @matches, @$limit if @$limit;
    }

    if ( $config{LOGFORMAT} =~ /^\s*$/ ) {
	if ( $level =~ '^ULOG' ) {
	    $prefix = "$level";
	} elsif  ( $level =~ /^NFLOG/ ) {
	    $prefix = "$level";
	} else {
	    my $flags = $globals{LOGPARMS};

	    if ( $level =~ /^(.+)\((.*)\)$/ ) {
		$level = $1;
		$flags = join( ' ', $flags, $2 ) . ' ';
		$flags =~ s/,/ /g;
	    }

	    $prefix = "LOG ${flags}--log-level $level";
	}
    } else {
	if ( $tag ) {
	    if ( $config{LOGTAGONLY} && $tag ne ',' ) {
		if ( $tag =~ /^,/ ) {
		    ( $disposition = $tag ) =~ s/,//;
		} elsif ( $tag =~ /,/ ) {
		    ( $chain, $disposition ) = split ',', $tag;
		} else { 
		    $chain = $tag;
		}

		$tag   = '';
	    } else {
		$tag .= ' ';
	    }
	} else {
	    $tag = '' unless defined $tag;
	}

	$disposition =~ s/\s+.*//;

	if ( $globals{LOGRULENUMBERS} ) {
	    $prefix = (sprintf $config{LOGFORMAT} , $chain , $chainref->{log}++, $disposition ) . $tag;
	} else {
	    $prefix = (sprintf $config{LOGFORMAT} , $chain , $disposition) . $tag;
	}

	if ( length $prefix > 29 ) {
	    $prefix = substr( $prefix, 0, 28 ) . ' ';
	    warning_message "Log Prefix shortened to \"$prefix\"";
	}

	if ( $level =~ '^ULOG' ) {
	    $prefix = "$level --ulog-prefix \"$prefix\"";
	} elsif  ( $level =~ /^NFLOG/ ) {
	    $prefix = "$level --nflog-prefix \"$prefix\"";
	} elsif ( $level =~ '^LOGMARK' ) {
	    $prefix = join( '', substr( $prefix, 0, 12 ) , ':' ) if length $prefix > 13;
	    $prefix = "$level --log-prefix \"$prefix\"";
	} else {
	    my $options = $globals{LOGPARMS};

	    if ( $level =~ /^(.+)\((.*)\)$/ ) {
		$level   = $1;
		$options = join( ' ', $options, $2 ) . ' ';
		$options =~ s/,/ /g;
	    }

	    $prefix = "LOG ${options}--log-level $level --log-prefix \"$prefix\"";
	}
    }

    if ( $command eq 'add' ) {
	add_ijump_internal ( $chainref, j => $prefix , 1, @matches );
    } else {
	insert_ijump ( $chainref, j => $prefix, 0 , @matches );
    }
}

sub log_rule( $$$$ ) {
    my ( $level, $chainref, $disposition, $matches ) = @_;

    log_rule_limit $level, $chainref, $chainref->{name} , $disposition, $globals{LOGLIMIT}, '', 'add', $matches;
}

sub log_irule( $$$;@ ) {
    my ( $level, $chainref, $disposition, @matches ) = @_;

    log_irule_limit $level, $chainref, $chainref->{name} , $disposition, $globals{LOGILIMIT} , '', 'add', @matches;
}

#
# If the destination chain exists, then at the end of the source chain add a jump to the destination.
#
sub addnatjump( $$;@ ) {
    my ( $source , $dest, @matches ) = @_;

    my $destref   = $nat_table->{$dest} || {};

    if ( $destref->{referenced} ) {
	add_ijump $nat_table->{$source} , j => $dest , @matches;
    } else {
	clearrule;
    }
}

#
# Split a comma-separated source or destination host list but keep [...] and (...) together. Used for spliting address lists
# where an element of the list might be +ipset[flag,...](obj) or +[ipset[flag,...](obj),...]. The second argument ($deferresolve)
# should be 'true' when the passed input list may include exclusion.
#
sub split_host_list( $$;$ ) {
    my ( $input, $deferresolve, $loose ) = @_;

    my @input = split_list $input, 'host';

    my $exclude = 0;

    my @result;

    if ( $input =~ /\[/ ) {
	while ( @input ) {
	    my $element = shift @input;

	    if ( $element =~ /\[/ ) {
		while ( $element =~ tr/[/[/ > $element =~ tr/]/]/ ) {
		    fatal_error "Missing ']' ($element)" unless @input;
		    $element .= ( ',' . shift @input );
		}

		unless ( $loose ) {
		    fatal_error "Invalid host list ($input)" if $exclude && $element =~ /!/;
		    $exclude ||= $element =~ /^!/ || $element =~ /\]!/;
		}

		fatal_error "Mismatched [...] ($element)" unless $element =~ tr/[/[/ == $element =~ tr/]/]/;
	    } else {
		$exclude ||= $element =~ /!/ unless $loose;
	    }

	    push @result, $element;
	}
    } else {
	@result = @input;
    }

    if ( $input =~ /\(/ ) {
	@input  = @result;
	@result = ();

	while ( @input ) {
	    my $element = shift @input;

	    if ( $element =~ /\(/ ) {
		while ( $element =~ tr/(/(/ > $element =~ tr/)/)/ ) {
		    fatal_error "Missing ')' ($element)" unless @input;
		    $element .= ( ',' . shift @input );
		}

		unless ( $loose ) {
		    fatal_error "Invalid host list ($input)" if $exclude && $element =~ /!/;
		    $exclude ||= $element =~ /^!/ || $element =~ /\)!/;
		}

		fatal_error "Mismatched (...) ($element)" unless $element =~ tr/(/(/ == $element =~ tr/)/)/;
	    } else {
		$exclude ||= $element =~ /!/ unless $loose;
	    }

	    push @result, $element;
	}
    }

    unless ( $deferresolve ) {
	my @result1;

	for ( @result ) {
	    if ( m|[-\+\[~/^&!]| ) {
		push @result1, $_;
	    } elsif ( /^.+\..+\./ ) {
		if ( valid_address( $_ ) ) {
		    push @result1, $_
		} else {
		    push @result1, resolve_dnsname( $_ );
		}
	    } else {
		push @result1, $_;
	    }
	}

	return @result1;
    }

    @result;
}

#
# Set up the IPTABLES-related run-time variables
#
sub set_chain_variables() {
    if ( $family == F_IPV4 ) {
	my $checkname = 0;
	my $iptables  = $config{IPTABLES};

	if ( $iptables ) {
	    emit( qq(IPTABLES="$iptables"),
		  '[ -x "$IPTABLES" ] || startup_error "IPTABLES=$IPTABLES does not exist or is not executable"',
		);
	    $checkname = 1 unless $iptables =~ '/';
	} else {
	    emit( '[ -z "$IPTABLES" ] && IPTABLES=$(mywhich iptables) # /sbin/shorewall exports IPTABLES',
		  '[ -n "$IPTABLES" -a -x "$IPTABLES" ] || startup_error "Can\'t find iptables executable"'
		);
	    $checkname = 1;
	}

	if ( $checkname ) {
	    emit ( '',
		   'case $IPTABLES in',
		   '    */*)',
		   '        ;;',
		   '    *)',
		   '        IPTABLES=./$IPTABLES',
		   '        ;;',
		   'esac',
		   '',
		   'IP6TABLES=${IPTABLES%/*}/ip6tables'
		 );
	} else {
	    $iptables =~ s|/[^/]*$|/ip6tables|;
	    emit ( "IP6TABLES=$iptables" );
	}

	emit( 'IPTABLES_RESTORE=${IPTABLES}-restore',
	      '[ -x "$IPTABLES_RESTORE" ] || startup_error "$IPTABLES_RESTORE does not exist or is not executable"' );
	emit( 'g_tool=$IPTABLES' );
    } else {
	if ( $config{IP6TABLES} ) {
	    emit( qq(IP6TABLES="$config{IP6TABLES}"),
		  '[ -x "$IP6TABLES" ] || startup_error "IP6TABLES=$IP6TABLES does not exist or is not executable"',
		);
	} else {
	    emit( '[ -z "$IP6TABLES" ] && IP6TABLES=$(mywhich ip6tables) # /sbin/shorewall6 exports IP6TABLES',
		  '[ -n "$IP6TABLES" -a -x "$IP6TABLES" ] || startup_error "Can\'t find ip6tables executable"'
		);
	}

	emit( 'IP6TABLES_RESTORE=${IP6TABLES}-restore',
	      '[ -x "$IP6TABLES_RESTORE" ] || startup_error "$IP6TABLES_RESTORE does not exist or is not executable"' );
	emit( 'g_tool=$IP6TABLES' );
    }

    if ( $config{IP} ) {
	emit( qq(IP="$config{IP}") ,
	      '[ -x "$IP" ] || startup_error "IP=$IP does not exist or is not executable"'
	    );
    } else {
	emit 'IP=ip';
    }

    if ( $config{TC} ) {
	emit( qq(TC="$config{TC}") ,
	      '[ -x "$TC" ] || startup_error "TC=$TC does not exist or is not executable"'
	    );
    } else {
	emit 'TC=tc';
    }

    if ( $config{IPSET} ) {
	emit( qq(IPSET="$config{IPSET}") ,
	      '[ -x "$IPSET" ] || startup_error "IPSET=$IPSET does not exist or is not executable"'
	    );
    } else {
	emit 'IPSET=ipset';
    }

}

#
# Emit code that marks the firewall as not started.
#
sub mark_firewall_not_started() {
    if ( $family == F_IPV4 ) {
	emit ( 'qt1 $IPTABLES -L shorewall -n && qt1 $IPTABLES -F shorewall && qt1 $IPTABLES -X shorewall' );
    } else {
	emit ( 'qt1 $IP6TABLES -L shorewall -n && qt1 $IP6TABLES -F shorewall && qt1 $IP6TABLES -X shorewall' );
    }
}

####################################################################################################################
# The following functions come in pairs. The first function returns the name of a run-time shell variable that
# will hold a piece of interface-oriented data detected at run-time. The second creates a code fragment to detect
# the information and stores it in a hash keyed by the interface name.
####################################################################################################################
#
# Returns the name of the shell variable holding the first address of the passed interface
#
sub interface_address( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_address';
    uc $variable;
}

#
# Record that the ruleset requires the first IP address on the passed interface
#
sub get_interface_address ( $ ) {
    my ( $logical ) = $_[0];

    my $interface = get_physical( $logical );
    my $variable = interface_address( $interface );
    my $function = interface_is_optional( $logical ) ? 'find_first_interface_address_if_any' : 'find_first_interface_address';

    $global_variables |= ALL_COMMANDS;

    $interfaceaddr{$interface} = "$variable=\$($function $interface)\n";

    "\$$variable";
}

#
# Returns the name of the shell variable holding the broadcast addresses of the passed interface
#
sub interface_bcasts( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_bcasts';
    uc $variable;
}

#
# Record that the ruleset requires the broadcast addresses on the passed interface
#
sub get_interface_bcasts ( $ ) {
    my ( $interface ) = get_physical $_[0];

    my $variable = interface_bcasts( $interface );

    $global_variables |= NOT_RESTORE;

    $interfacebcasts{$interface} = qq($variable="\$(get_interface_bcasts $interface) 255.255.255.255");

    "\$$variable";
}

#
# Returns the name of the shell variable holding the anycast addresses of the passed interface
#
sub interface_acasts( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_acasts';
    uc $variable;
}

#
# Record that the ruleset requires the anycast addresses on the passed interface
#
sub get_interface_acasts ( $ ) {
    my ( $interface ) = get_physical $_[0];

    $global_variables |= NOT_RESTORE;

    my $variable = interface_acasts( $interface );

    $interfaceacasts{$interface} = qq($variable="\$(get_interface_acasts $interface) ) . IPv6_MULTICAST;

    "\$$variable";
}

#
# Returns the name of the shell variable holding the gateway through the passed interface
#
sub interface_gateway( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_gateway';
    uc $variable;
}

#
# Record that the ruleset requires the gateway address on the passed interface
#
sub get_interface_gateway ( $;$ ) {
    my ( $logical, $protect ) = @_;

    my $interface = get_physical $logical;
    my $variable = interface_gateway( $interface );

    my $routine = $config{USE_DEFAULT_RT} ? 'detect_dynamic_gateway' : 'detect_gateway';

    $global_variables |= ALL_COMMANDS;

    if ( interface_is_optional $logical ) {
	$interfacegateways{$interface} = qq([ -n "\$$variable" ] || $variable=\$($routine $interface));
    } else {
	$interfacegateways{$interface} = qq([ -n "\$$variable" ] || $variable=\$($routine $interface)
[ -n "\$$variable" ] || startup_error "Unable to detect the gateway through interface $interface");
    }

    $protect ? "\${$variable:-" . NILIP . '}' : "\$$variable";
}

#
# Returns the name of the shell variable holding the addresses of the passed interface
#
sub interface_addresses( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_addresses';
    uc $variable;
}

#
# Record that the ruleset requires the IP addresses on the passed interface
#
sub get_interface_addresses ( $ ) {
    my ( $logical ) = $_[0];

    my $interface = get_physical( $logical );
    my $variable = interface_addresses( $interface );

    $global_variables |= NOT_RESTORE;

    if ( interface_is_optional $logical ) {
	$interfaceaddrs{$interface} = qq($variable=\$(find_interface_addresses $interface)\n);
    } else {
	$interfaceaddrs{$interface} = qq($variable=\$(find_interface_addresses $interface)
[ -n "\$$variable" ] || startup_error "Unable to determine the IP address(es) of $interface"
);
    }

    "\$$variable";
}

#
# Returns the name of the shell variable holding the networks routed out of the passed interface
#
sub interface_nets( $ ) {
    my $variable = 'sw_' . var_base( $_[0] ) . '_networks';
    uc $variable;
}

#
# Record that the ruleset requires the networks routed out of the passed interface
#
sub get_interface_nets ( $ ) {
    my ( $logical ) = $_[0];

    my $interface = physical_name( $logical );
    my $variable = interface_nets( $interface );

    $global_variables |= ALL_COMMANDS;

    if ( interface_is_optional $logical ) {
	$interfacenets{$interface} = qq($variable=\$(get_routed_networks $interface)\n);
    } else {
	$interfacenets{$interface} = qq($variable=\$(get_routed_networks $interface)
[ -n "\$$variable" ] || startup_error "Unable to determine the routes through interface \\"$interface\\""
);
    }

    "\$$variable";

}

#
# Returns the name of the shell variable holding the MAC address of the gateway for the passed provider out of the passed interface
#
sub interface_mac( $$ ) {
    my $variable = join( '_' , 'sw' , var_base( $_[0] ) , var_base( $_[1] ) , 'mac' );
    uc $variable;
}

#
# Record the fact that the ruleset requires MAC address of the passed gateway IP routed out of the passed interface for the passed provider number
#
sub get_interface_mac( $$$$ ) {
    my ( $ipaddr, $logical , $table, $mac ) = @_;

    my $interface = get_physical( $logical );
    my $variable = interface_mac( $interface , $table );

    $global_variables |= NOT_RESTORE;
    
    if ( $mac ) {
	$interfacemacs{$table} = qq($variable=$mac);
    } else {
	if ( interface_is_optional $logical ) {
	    $interfacemacs{$table} = qq($variable=\$(find_mac $ipaddr $interface)\n);
	} else {
	    $interfacemacs{$table} = qq($variable=\$(find_mac $ipaddr $interface)
[ -n "\$$variable" ] || startup_error "Unable to determine the MAC address of $ipaddr through interface \\"$interface\\""
);

       }
    }

    "\$$variable";
}

sub have_global_variables() {
    have_capability( 'ADDRTYPE' ) ? $global_variables : $global_variables | NOT_RESTORE;
}

sub have_address_variables() {
    ( keys %interfaceaddr || keys %interfacemacs || keys %interfacegateways );
}

#
# Generate setting of run-time global shell variables
#
sub set_global_variables( $$ ) {

    my ( $setall, $conditional ) = @_;

    if ( $conditional ) {
	my ( $interface, @interfaces );

	@interfaces = sort keys %interfaceaddr;

	for $interface ( @interfaces ) {
	    emit( qq([ -z "\$interface" -o "\$interface" = "$interface" ] && $interfaceaddr{$interface}) );
	}

	@interfaces = sort keys %interfacegateways;

	for $interface ( @interfaces ) {
	    emit( qq(if [ -z "\$interface" -o "\$interface" = "$interface" ]; then) );
	    push_indent;
	    emit( $interfacegateways{$interface} );
	    pop_indent;
	    emit( qq(fi\n) );
	}

	@interfaces = sort keys %interfacemacs;

	for $interface ( @interfaces ) {
	    emit( qq([ -z "\$interface" -o "\$interface" = "$interface" ] && $interfacemacs{$interface}) );
	}
    } else {
	emit $_     for sort values %interfaceaddr;
	emit "$_\n" for sort values %interfacegateways;
	emit $_     for sort values %interfacemacs;
    }

    if ( $setall ) {
	emit $_ for sort values %interfaceaddrs;
	emit $_ for sort values %interfacenets;

	unless ( have_capability( 'ADDRTYPE' ) ) {

	    if ( $family == F_IPV4 ) {
		emit 'ALL_BCASTS="$(get_all_bcasts) 255.255.255.255"';
		emit $_ for sort values %interfacebcasts;
	    } else {
		emit 'ALL_ACASTS="$(get_all_acasts)"';
		emit $_ for sort values %interfaceacasts;
	    }
	}
    }
}

sub verify_address_variables() {
    for my $variable ( sort keys %address_variables ) {
	my $type = $address_variables{$variable};
	my $address = "\$$variable";

	if ( $type eq '&' ) {
	    emit( qq([ -n "$address" ] || startup_error "Address variable $variable had not been assigned an address") ,
		  q() ,
		  qq(if qt \$g_tool -A INPUT -s $address; then) );
	} else {
	    emit( qq(if [ -z "$address" ]; then) ,
		  qq(    $variable=) . NILIP ,
		  qq(elif qt \$g_tool -A INPUT -s $address; then) );
	}

	emit( qq(    qt \$g_tool -D INPUT -s $address),
	      q(else),
	      qq(    startup_error "Invalid value ($address) for address variable $variable"),
	      qq(fi\n) );
    }
}

#
# Generate 'unreachable rule' message
#
sub unreachable_warning( $$ ) {
    my ( $ignore, $chainref ) = @_;
    unless ( $ignore ) {
	if ( $chainref->{complete} ) {
	    warning_message "One or more unreachable rules in chain $chainref->{name} have been discarded" unless $chainref->{unreachable_warned}++;
	    return 1;
	}
    }

    0;
}

############################################################################################
# Helpers for expand_rule()
############################################################################################
#
# Loops and conditionals can be opened by calling push_command().
# All loops/conditionals are terminated by calling pop_commands().
#
sub push_command( $$$ ) {
    my ( $chainref, $command, $end ) = @_;
    our @ends;

    add_commands $chainref, $command;
    incr_cmd_level $chainref;
    push @ends, $end;
}

sub pop_commands( $ ) {
    my $chainref = $_[0];

    our @ends;

    while ( @ends ) {
	decr_cmd_level $chainref;
	add_commands $chainref, pop @ends;
    }
}

#
# Issue an invalid list error message
#
sub invalid_network_list ( $$ ) {
    my ( $srcdst, $list ) = @_;
    fatal_error "Invalid $srcdst network list ($list)";
}

#
# Split a network element into the net part and exclusion part (if any)
#
sub split_network( $$$ ) {
    my ( $input, $srcdst, $list ) = @_;

    my @input = split '!', $input;
    my @result;

    if ( $input =~ /\[/ ) {
	while ( @input ) {
	    my $element = shift @input;

	    if ( $element =~ /\[/ ) {
		my $openbrackets;

		while ( ( $openbrackets = ( $element =~ tr/[/[/ ) ) > $element =~ tr/]/]/ ) {
		    fatal_error "Missing ']' ($element)" unless @input;
		    $element .= ( '!' . shift @input );
		}

		fatal_error "Mismatched [...] ($element)" unless $openbrackets == $element =~ tr/]/]/;
	    }

	    push @result, $element;
	}
    } else {
	@result = @input;
    }

    invalid_network_list( $srcdst, $list ) if @result > 2;

    @result;
}

#
# Handle SOURCE or DEST network list, including exclusion
#
sub handle_network_list( $$ ) {
    my ( $list, $srcdst ) = @_;

    my $nets = '';
    my $excl = '';

    my @nets = split_host_list $list, 1, 0;

    for ( @nets ) {
	if ( /!/ ) {
	    if ( /^!(.*)$/ ) {
		invalid_network_list( $srcdst, $list) if ( $nets || $excl );
		$excl = $1;
	    } else {
		my ( $temp1, $temp2 ) = split_network $_, $srcdst, $list;
		$nets = $nets ? join(',', $nets, $temp1 ) : $temp1;
		if ( $temp2 ) {
		    invalid_network_list( $srcdst, $list) if $excl;
		    $excl = $temp2;
		}
	    }
	} elsif ( $excl ) {
	    $excl .= ",$_";
	} else {
	    $nets = $nets ? join(',', $nets, $_ ) : $_;
	}
    }

    ( $nets, $excl );

}

#
# Split an interface:address pair and returns its components
#
sub isolate_source_interface( $ ) {
    my ( $source ) = @_;

    my ( $iiface, $inets );

    if ( $family == F_IPV4 ) {
	if ( $source =~ /^(.+?):(.+)$/ ) {
	    $iiface = $1;
	    $inets  = $2;
	} elsif ( $source =~ /^!?(?:\+|&|~|%|\^|\d+\.|.+\..+\.)/ ) {
	    $inets = $source;
	} else {
	    $iiface = $source;
	}
    } else {
	$source =~ tr/<>/[]/;

	if ( $source =~ /^(.+?):(\[(?:.+),\[(?:.+)\])$/ ) {
	    $iiface = $1;
	    $inets  = $2;
	} elsif ( $source =~ /^(.+?):\[(.+)\]\s*$/ ||
		  $source =~ /^(.+?):(!?\+.+)$/    ||
		  $source =~ /^(.+?):(!?[&%].+)$/  ||
		  $source =~ /^(.+?):(\[.+\]\/(?:\d+))\s*$/
		) {
	    $iiface = $1;
	    $inets  = $2;
	} elsif ( $source =~ /:/ ) {
	    if ( $source =~ /^\[(?:.+),\[(?:.+)\]$/ ){
		$inets = $source;
	    } elsif ( $source =~ /^\[(.+)\]$/ ) {
		$inets = $1;
	    } else {
		$inets = $source;
	    }
	} elsif ( $source =~ /(?:\+|&|%|~|\..*\.)/ || $source =~ /^!?\^/ ) {
	    $inets = $source;
	} else {
	    $iiface = $source;
	}
    }

    ( $iiface, $inets );
}

#
# Verify the source interface -- returns a rule fragment to be added to the rule being created
#
sub verify_source_interface( $$$$ ) {
    my ( $iiface, $restriction, $table, $chainref ) = @_;

    my $rule = '';

    fatal_error "Unknown Interface ($iiface)" unless known_interface $iiface;

    if ( $restriction & POSTROUTE_RESTRICT ) {
	#
	# An interface in the SOURCE column of a masq file
	#
	fatal_error "Bridge ports may not appear in the SOURCE column of this file" if port_to_bridge( $iiface );
	fatal_error "A wildcard interface ( $iiface) is not allowed in this context" if $iiface =~ /\+$/;

	if ( $table eq 'nat' ) {
	    warning_message qq(Using an interface as the masq SOURCE requires the interface to be up and configured when $Product starts/restarts/reloads) unless $idiotcount++;
	} else {
	    warning_message qq(Using an interface as the SOURCE in a T: rule requires the interface to be up and configured when $Product starts/restarts/reloads) unless $idiotcount1++;
	}

	push_command $chainref, join( '', 'for source in ', get_interface_nets( $iiface) , '; do' ), 'done';

	$rule .= '-s $source ';
    } else {
	if ( $restriction & OUTPUT_RESTRICT ) {
	    if ( $chainref->{accounting} ) {
		fatal_error "Source Interface ($iiface) not allowed in the $chainref->{name} chain";
	    } else {
		fatal_error "Source Interface ($iiface) not allowed when the SOURCE is the firewall";
	    }
	}

	$chainref->{restricted} |= $restriction;
	$rule .= match_source_dev( $iiface );
    }

    $rule;
}

#
# Splits an interface:address pair. Updates that passed rule and returns ($rule, $interface, $address )
#
sub isolate_dest_interface( $$$$ ) {
    my ( $restriction, $dest, $chainref, $rule ) = @_;

    my ( $diface, $dnets );

    if ( ( $restriction & PREROUTE_RESTRICT ) && $dest =~ /^detect:(.*)$/ ) {
	#
	# DETECT_DNAT_IPADDRS=Yes and we're generating the nat rule
	#
	my @interfaces = split /\s+/, $1;

	if ( @interfaces > 1 ) {
	    my $list = "";
	    my $optional;

	    for my $interface ( @interfaces ) {
		$optional++ if interface_is_optional $interface;
		$list = join( ' ', $list , get_interface_address( $interface ) );
	    }

	    push_command( $chainref , "for address in $list; do" , 'done' );

	    push_command( $chainref , 'if [ $address != 0.0.0.0 ]; then' , 'fi' ) if $optional;

	    $rule .= '-d $address ';
	} else {
	    my $interface = $interfaces[0];
	    my $variable  = get_interface_address( $interface );

	    push_command( $chainref , "if [ $variable != 0.0.0.0 ]; then" , 'fi') if interface_is_optional( $interface );

	    $rule .= "-d $variable ";
	}
    } elsif ( $family == F_IPV4 ) {
	if ( $dest =~ /^(.+?):(.+)$/ ) {
	    $diface = $1;
	    $dnets  = $2;
	} elsif ( $dest =~ /^!?(?:\+|&|%|~|\^|\d+\.|.+\..+\.)/ ) {
	    $dnets = $dest;
	} else {
	    $diface = $dest;
	}
    } else {
	$dest =~ tr/<>/[]/;

	if ( $dest =~ /^(.+?):(\[(?:.+),\[(?:.+)\])$/ ) {
	    $diface = $1;
	    $dnets  = $2;
	} elsif (  $dest =~ /^(.+?):\[(.+)\]\s*$/ ||
		   $dest =~ /^(.+?):(!?\+.+)$/    ||
		   $dest =~ /^(.+?):(!?[&%].+)$/  ||
		   $dest =~ /^(.+?):(\[.+\]\/(?:\d+))\s*$/
		) {
	    $diface = $1;
	    $dnets  = $2;
	} elsif ( $dest =~ /:/ ) {
	    if ( $dest =~ /^\[(?:.+),\[(?:.+)\]$/ ){
		$dnets = $dest;
	    } elsif ( $dest =~ /^\[(.+)\]$/ ) {
		$dnets = $1;
	    } else {
		$dnets = $dest;
	    }
	} elsif ( $dest =~ /(?:\+|&|\..*\.)/ || $dest =~ /^!?\^/ ) {
	    $dnets = $dest;
	} else {
	    $diface = $dest;
	}
    }

    ( $diface, $dnets, $rule );
}

#
# Verify the destination interface. Returns a rule fragment to be added to the rule being created
#
sub verify_dest_interface( $$$$ ) {
    my ( $diface, $restriction, $chainref, $iiface ) = @_;

    my $rule = '';

    fatal_error "Unknown Interface ($diface)" unless known_interface $diface;

    if ( $restriction & PREROUTE_RESTRICT ) {
	#
	# Dest interface -- must use routing table
	#
	fatal_error "A DEST interface is not permitted in the PREROUTING chain" if $restriction & DESTIFACE_DISALLOW;
	fatal_error "Bridge port ($diface) not allowed" if port_to_bridge( $diface );
	fatal_error "A wildcard interface ($diface) is not allowed in this context" if $diface =~ /\+$/;
	push_command( $chainref , 'for dest in ' . get_interface_nets( $diface) . '; do', 'done' );
	$rule .= '-d $dest ';
    } else {
	fatal_error "Bridge Port ($diface) not allowed in OUTPUT or POSTROUTING rules" if ( $restriction & ( POSTROUTE_RESTRICT + OUTPUT_RESTRICT ) ) && port_to_bridge( $diface );
	fatal_error "Destination Interface ($diface) not allowed when the destination zone is the firewall" if $restriction & INPUT_RESTRICT;
	if ( $restriction & DESTIFACE_DISALLOW ) {
	    if ( $chainref->{accounting} ) {
		fatal_error "Destination Interface ($diface) not allowed in the $chainref->{name} chain";
	    } else {
		fatal_error "Destination Interface ($diface) not allowed in the $chainref->{table} OUTPUT chain";
	    }
	}

	if ( $iiface ) {
	    my $bridge = port_to_bridge( $diface );
	    fatal_error "Source interface ($iiface) is not a port on the same bridge as the destination interface ( $diface )" if $bridge && $bridge ne source_port_to_bridge( $iiface );
	}

	$chainref->{restricted} |= $restriction;
	$rule .= match_dest_dev( $diface );
    }

    $rule;
}

#
# Handles the original destination. Updates the passed rule and returns ( $networks, $exclusion, $rule )
#
sub handle_original_dest( $$$ ) {
    my ( $origdest, $chainref, $rule ) = @_;
    my ( $onets, $oexcl );

    if ( $origdest eq '-' || ! have_capability( 'CONNTRACK_MATCH' ) ) {
	$onets = $oexcl = '';
    } elsif ( $origdest =~ /^detect:(.*)$/ ) {
	#
	# Either the filter part of a DNAT rule or 'detect' was given in the ORIG DEST column
	#
	my @interfaces = split /\s+/, $1;

	if ( @interfaces > 1 ) {
	    my $list = "";
	    my $optional;

	    for my $interface ( @interfaces ) {
		$optional++ if interface_is_optional $interface;
		$list = join( ' ', $list , get_interface_address( $interface ) );
	    }

	    push_command( $chainref , "for address in $list; do" , 'done' );

	    push_command( $chainref , 'if [ $address != 0.0.0.0 ]; then' , 'fi' ) if $optional;

	    $rule .= '-m conntrack --ctorigdst $address ';
	} else {
	    my $interface = $interfaces[0];
	    my $variable  = get_interface_address( $interface );

	    push_command( $chainref , "if [ $variable != 0.0.0.0 ]; then" , 'fi' ) if interface_is_optional( $interface );

	    $rule .= "-m conntrack --ctorigdst $variable ";
	}

	$onets = $oexcl = '';
    } else {
	fatal_error "Invalid ORIGINAL DEST" if  $origdest =~ /^([^!]+)?,!([^!]+)$/ || $origdest =~ /.*!.*!/;

	if ( $origdest =~ /^([^!]+)?!([^!]+)$/ ) {
	    #
	    # Exclusion
	    #
	    $onets = $1;
	    $oexcl = $2;
	} else {
	    $oexcl = '';
	    $onets = $origdest;
	}

	unless ( $onets ) {
	    my @oexcl = split_host_list( $oexcl, $config{DEFER_DNS_RESOLUTION} );
	    if ( @oexcl == 1 ) {
		$rule .= match_orig_dest( "!$oexcl" );
		$oexcl = '';
	    }
	}
    }

    ( $onets, $oexcl, $rule );
}

#
# Handles non-trivial exclusion. Updates the passed rule and returns ( $rule, $done )
#
sub handle_exclusion( $$$$$$$$$$$$$$$$$$$$$ ) {
    my ( $disposition, 
	 $table,
	 $prerule,
	 $sprerule,
	 $dprerule,
	 $rule,
	 $restriction, 
	 $inets,
	 $iexcl,
	 $onets,
	 $oexcl,
	 $dnets,
	 $dexcl,
	 $chainref,
	 $chain,
	 $mac,
	 $loglevel,
	 $logtag,
	 $targetref,
	 $exceptionrule,
	 $jump ) = @_;

    if ( $disposition eq 'RETURN' || $disposition eq 'CONTINUE' ) {
	#
	# We can't use an exclusion chain -- we mark those packets to be excluded and then condition the rules generated in the block below on the mark value
	#
	require_capability 'MARK_ANYWHERE' , 'Exclusion in ACCEPT+/CONTINUE/NONAT rules', 's' unless $table eq 'mangle';

	fatal_error "Exclusion in ACCEPT+/CONTINUE/NONAT rules requires the Multiple Match capability in your kernel and iptables"
	    if $rule =~ / -m mark / && ! $globals{KLUDGEFREE};
	#
	# Clear the exclusion bit
	#
	add_ijump $chainref , j => 'MARK', targetopts => '--and-mark ' . in_hex( $globals{EXCLUSION_MASK} ^ 0xffffffff );
	#
	# Mark packet if it matches any of the exclusions
	#
	my $exclude = '-j MARK --or-mark ' . in_hex( $globals{EXCLUSION_MASK} );

	for ( split_host_list( $iexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $chainref, $_ );
	    add_rule $chainref, ( match_source_net $_ , $restriction, $mac ) . $exclude;
	    conditional_rule_end( $chainref ) if $cond;
	}

	for ( split_host_list( $dexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $chainref, $_ );
	    add_rule $chainref, ( match_dest_net $_, $restriction ) . $exclude;
	    conditional_rule_end( $chainref ) if $cond;
	}

	for ( split_host_list( $oexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $chainref, $_ );
	    add_rule $chainref, ( match_orig_dest $_ ) . $exclude;
	    conditional_rule_end( $chainref ) if $cond;
	}
	#
	# Augment the rule to include 'not excluded'
	#
	$rule .= '-m mark --mark 0/' . in_hex( $globals{EXCLUSION_MASK} ) . ' ';

	( $rule, 0 );
    } else {
	#
	# Create the Exclusion Chain
	#
	my $echain = newexclusionchain( $table );

	my $echainref = dont_move new_chain $table, $echain;
	#
	# Use the current rule and send all possible matches to the exclusion chain
	#
	for my $onet ( split_host_list( $onets, $config{DEFER_DNS_RESOLUTION} ) ) {

	    my $cond = conditional_rule( $chainref, $onet );

	    $onet = match_orig_dest $onet;

	    for my $inet ( split_host_list( $inets, $config{DEFER_DNS_RESOLUTION} ) ) {

		my $cond = conditional_rule( $chainref, $inet );

		my $source_match = match_source_net( $inet, $restriction, $mac ) if $globals{KLUDGEFREE};

		for my $dnet ( split_host_list( $dnets, $config{DEFER_DNS_RESOLUTION} ) ) {
		    $source_match = match_source_net( $inet, $restriction, $mac ) unless $globals{KLUDGEFREE};
		    add_expanded_jump( $chainref, $echainref, 0, join( '', $prerule, $source_match, $sprerule, match_dest_net( $dnet, $restriction ), $dprerule, $onet, $rule ) );
		}

		conditional_rule_end( $chainref ) if $cond;
	    }

	    conditional_rule_end( $chainref ) if $cond;
	}
	#
	# Generate RETURNs for each exclusion
	#
	for ( split_host_list( $iexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $echainref, $_ );
	    add_rule $echainref, ( match_source_net $_ , $restriction, $mac ) . '-j RETURN';
	    conditional_rule_end( $echainref ) if $cond;
	}

	for ( split_host_list( $dexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $echainref, $_ );
	    add_rule $echainref, ( match_dest_net $_, $restriction ) . '-j RETURN';
	    conditional_rule_end( $echainref ) if $cond;
	}

	for ( split_host_list( $oexcl, $config{DEFER_DNS_RESOLUTION} ) ) {
	    my $cond = conditional_rule( $echainref, $_ );
	    add_rule $echainref, ( match_orig_dest $_ ) . '-j RETURN';
	    conditional_rule_end( $echainref ) if $cond;
	}
	#
	# Log rule
	#
	log_irule_limit( $loglevel ,
			 $echainref ,
			 $chain ,
			 $actparms{disposition} || ( $disposition eq 'reject' ? 'REJECT' : $disposition ),
			 [] ,
			 $logtag ,
			 'add' )
	    if $loglevel;
	#
	# Generate Final Rule
	#
	if ( $targetref ) {
	    add_expanded_jump( $echainref, $targetref, 0, $exceptionrule );
	} else {
	    add_rule( $echainref, $exceptionrule . $jump , 1 ) unless $disposition eq 'LOG';
	}

	( $rule, 1 );
    }
}

################################################################################################################
#
# This function provides a uniform way to generate ip[6]tables rules (something the original Shorewall
# sorely needed).
#
# Returns the destination interface specified in the rule, if any.
#
sub expand_rule( $$$$$$$$$$$;$ )
{
    my ($chainref ,    # Chain
	$restriction,  # Determines what to do with interface names in the SOURCE or DEST
	$prerule,      # Matches that go at the front of the rule
	$rule,         # Caller's matches that don't depend on the SOURCE, DEST and ORIGINAL DEST
	$source,       # SOURCE
	$dest,         # DEST
	$origdest,     # ORIGINAL DEST
	$target,       # Target ('-j' part of the rule - may be empty)
	$loglevel ,    # Log level (and tag)
	$disposition,  # Primtive part of the target (RETURN, ACCEPT, ...)
	$exceptionrule,# Caller's matches used in exclusion case
	$logname,      # Name of chain to name in log messages
       ) = @_;

    return if $chainref->{complete};

    my ( $iiface, $diface, $inets, $dnets, $iexcl, $dexcl, $onets , $oexcl, $trivialiexcl, $trivialdexcl ) = 
       ( '',      '',      '',     '',     '',     '',     '',      '',     '',            '' );
    my  $chain = $actparms{chain} || $chainref->{name};
    my $table = $chainref->{table};
    my ( $jump, $mac,  $targetref, $basictarget );
    our @ends = ();
    my $deferdns = $config{DEFER_DNS_RESOLUTION};

    if ( $target ) {
	( $basictarget, my $rest ) = split ' ', $target, 2;

	$jump  = '-j ' . $target unless $targetref = $chain_table{$table}{$basictarget};
    } else {
	$jump = $basictarget = '';
    }

    #
    # In the generated rules, we sometimes need run-time loops or conditional blocks. This function is used
    # to define such a loop or block.
    #
    # $chainref = Reference to the chain
    # $command  = The shell command that begins the loop or conditional
    # $end      = The shell keyword ('done' or 'fi') that ends the loop or conditional
    #
    # Trim disposition
    #
    $disposition =~ s/\s.*//;
    #
    # Handle Log Level
    #
    our $logtag = undef;

    if ( $loglevel ne '' ) {
	( $loglevel, $logtag, my $remainder ) = split( /:/, $loglevel, 3 );

	fatal_error "Invalid log tag" if defined $remainder;

	if ( $loglevel =~ /^none!?$/i ) {
	    return if $disposition eq 'LOG';
	    $loglevel = $logtag = '';
	} else {
	    $loglevel = validate_level( $loglevel );
	    $logtag   = '' unless defined $logtag;
	}
    } elsif ( $disposition eq 'LOG' ) {
	fatal_error "LOG requires a level";
    }
    #
    # Isolate Source Interface, if any
    #
    ( $iiface, $inets ) = isolate_source_interface( $source ) if supplied $source && $source ne '-';
    #
    # Verify Source Interface, if any
    #
    $rule .= verify_source_interface( $iiface, $restriction, $table, $chainref ) if supplied $iiface;
    #
    # Isolate Destination Interface, if any
    #
    ( $diface, $dnets, $rule ) = isolate_dest_interface( $restriction, $dest, $chainref, $rule ) if supplied $dest && $dest ne '-';
    #
    # Verify Destination Interface, if any
    #
    $rule .= verify_dest_interface(  $diface, $restriction, $chainref, $iiface ) if supplied $diface;
    #
    # Handle Original Destination
    #
    ( $onets, $oexcl, $rule ) = handle_original_dest( $origdest, $chainref, $rule ) if $origdest;
    #
    # Determine if there is Source Exclusion
    #
    my ( $sprerule, $dprerule ) = ( '', '' );

    if ( $inets ) {
	( $inets, $iexcl ) = handle_network_list( $inets, 'SOURCE' );

	unless ( $inets || $iexcl =~ /^\+\[/ || ( $iiface && $restriction & POSTROUTE_RESTRICT ) ) {
	    my @iexcl = split_host_list( $iexcl, $deferdns, 1 );
	    if ( @iexcl == 1 ) {
		$sprerule = match_source_net "!$iexcl" , $restriction;
		$iexcl = '';
		$trivialiexcl = 1;
	    }
	}
    }
    #
    # Determine if there is Destination Exclusion
    #
    if ( $dnets ) {
	( $dnets, $dexcl ) = handle_network_list( $dnets, 'DEST' );

	unless ( $dnets || $dexcl =~ /^\+\[/ ) {
	    my @dexcl = split_host_list( $dexcl, $deferdns, 1 );
	    if ( @dexcl == 1 ) {
		$dprerule = match_dest_net "!$dexcl", $restriction;
		$dexcl = '';
		$trivialdexcl = 1;
	    }
	}
    }

    $inets = ALLIP unless $inets;
    $dnets = ALLIP unless $dnets;
    $onets = ALLIP unless $onets;

    fatal_error "SOURCE interface may not be specified with a source IP address in the POSTROUTING chain"   if $restriction == POSTROUTE_RESTRICT && $iiface && ( $inets ne ALLIP || $iexcl || $trivialiexcl);
    fatal_error "DEST interface may not be specified with a destination IP address in the PREROUTING chain" if $restriction == PREROUTE_RESTRICT &&  $diface && ( $dnets ne ALLIP || $dexcl || $trivialdexcl);

    my $done;

    if ( $iexcl || $dexcl || $oexcl ) {
	#
	# We have non-trivial exclusion
	#
	( $rule, $done ) = handle_exclusion( $disposition,
					     $table,
					     $prerule,
					     $sprerule,
					     $dprerule,
					     $rule,
					     $restriction,
					     $inets,
					     $iexcl,
					     $onets,
					     $oexcl,
					     $dnets,
					     $dexcl,
					     $chainref,
					     $chain,
					     $mac,
					     $loglevel,
					     $logtag,
					     $targetref,
					     $exceptionrule,
					     $jump );
    }

    unless ( $done ) {
	#
	# No non-trivial exclusions or we're using marks to handle them
	#
	for my $onet ( split_host_list( $onets, $deferdns ) ) {
	    my $cond1 = conditional_rule( $chainref, $onet );

	    $onet = match_orig_dest $onet;

	    for my $inet ( split_host_list( $inets, $deferdns ) ) {
		my $source_match;

		my $cond2 = conditional_rule( $chainref, $inet );

		$source_match = match_source_net( $inet, $restriction, $mac ) if $globals{KLUDGEFREE};

		for my $dnet ( split_host_list( $dnets, $deferdns ) ) {
		    $source_match  = match_source_net( $inet, $restriction, $mac ) unless $globals{KLUDGEFREE};
		    my $dest_match = match_dest_net( $dnet, $restriction );
		    my $matches = join( '', $source_match, $sprerule, $dest_match, $dprerule, $onet, $rule );

		    my $cond3 = conditional_rule( $chainref, $dnet );

		    if ( $loglevel eq '' ) {
			#
			# No logging -- add the target rule with matches to the rule chain
			#
			if ( $targetref ) {
			    add_expanded_jump( $chainref, $targetref , 0, $matches );
			} else {
			    add_rule( $chainref, $prerule . $matches . $jump , 1 );
			}
		    } elsif ( $disposition eq 'LOG' || $disposition eq 'COUNT' ) {
			#
			# The log rule must be added with matches to the rule chain
			#
			log_rule_limit(
				       $loglevel ,
				       $chainref ,
				       $chain,
				       $actparms{disposition} || ( $disposition eq 'reject' ? 'REJECT' : $disposition ),
				       '' ,
				       $logtag ,
				       'add' ,
				       $matches
				      );
		    } elsif ( $logname || $basictarget eq 'RETURN' ) {
			log_rule_limit(
				       $loglevel ,
				       $chainref ,
				       $logname || $chain,
				       $actparms{disposition} || $disposition,
				       '',
				       $logtag,
				       'add',
				       $matches );

			if ( $targetref ) {
			    add_expanded_jump( $chainref, $targetref, 0, $matches );
			} else {
			    add_rule( $chainref, $matches . $jump, 1 );
			}
		    } else {
			#
			# Find/Create a chain that both logs and applies the target action
			# and jump to the log chain if all of the rule's conditions are met
			#
			add_expanded_jump( $chainref,
					   logchain( $chainref,
						     $loglevel,
						     $logtag,
						     $exceptionrule,
						     $actparms{disposition} || $disposition,
						     $target ),
					   $terminating{$basictarget} || ( $targetref && $targetref->{complete} ),
					   $matches );
		    }

		    conditional_rule_end( $chainref ) if $cond3;
		}

		conditional_rule_end( $chainref ) if $cond2;
	    }

	    conditional_rule_end( $chainref ) if $cond1;
	}
    }

    $chainref->{restricted} |= INPUT_RESTRICT if $mac;

    pop_commands( $chainref ) if @ends;

    $diface;
}

#
# Returns true if the passed interface is associated with exactly one zone
#
sub copy_options( $ ) {
    keys %{interface_zones( shift )} == 1;
}

#
# This function is called after the blacklist rules have been added to the canonical chains. It
# either copies the relevant interface option rules into each canonocal chain, or it inserts one
# or more jumps to the relevant option chains. The argument indicates whether blacklist rules are
# present.
#
sub add_interface_options( $ ) {

    if ( $_[0] ) {
	#
	# We have blacklist rules.
	#
	my %input_chains;
	my %forward_chains;

	for my $interface ( all_real_interfaces ) {
	    $input_chains{$interface}   = $filter_table->{input_option_chain $interface};
	    $forward_chains{$interface} = $filter_table->{forward_option_chain $interface};
	}
	#
	# Generate a digest for each chain
	#
	for my $chainref ( sort { $a->{name} cmp $b->{name} } values %input_chains, values %forward_chains ) {
	    my $digest = '';

	    assert( $chainref );

	    for ( @{$chainref->{rules}} ) {
		if ( $digest ) {
		    $digest .= ' |' . format_rule( $chainref, $_, 1 );
		} else {
		    $digest = format_rule( $chainref, $_, 1 );
		}
	    }

	    $chainref->{digest} = sha1_hex $digest;
	}
	#
	# Insert jumps to the interface chains into the rules chains
	#
	for my $zone1 ( off_firewall_zones ) {
	    my @input_interfaces   = sort keys %{zone_interfaces( $zone1 )};
	    my @forward_interfaces = @input_interfaces;

	    if ( @input_interfaces > 1 ) {
		#
		# This zone has multiple interfaces - discover if all of the interfaces have the same
		# input and/or forward options
		#
		my $digest;
	      INPUT:
		{
		    for ( @input_interfaces ) {
			if ( defined $digest ) {
			    last INPUT unless $input_chains{$_}->{digest} eq $digest;
			} else {
			    $digest = $input_chains{$_}->{digest};
			}
		    }

		    @input_interfaces = ( $input_interfaces[0] );
		}

		$digest = undef;

	      FORWARD:
		{
		    for ( @forward_interfaces ) {
			if ( defined $digest ) {
			    last FORWARD unless $forward_chains{$_}->{digest} eq $digest;
			} else {
			    $digest = $forward_chains{$_}->{digest};
			}
		    }

		    @forward_interfaces = ( $forward_interfaces[0] );
		}
	    }
	    #
	    # Now insert the jumps
	    #
	    for my $zone2 ( all_zones ) {
		my $chainref = $filter_table->{rules_chain( $zone1, $zone2 )};
		my $chain1ref;

		if ( zone_type( $zone2 ) & (FIREWALL | VSERVER ) ) {
		    if ( @input_interfaces == 1 && copy_options( $input_interfaces[0] ) ) {
			$chain1ref = $input_chains{$input_interfaces[0]};

			if ( @{$chain1ref->{rules}}  ) {
			    copy_rules $chain1ref, $chainref, 1;
			    $chainref->{referenced} = 1;
			}
		    } else {
			for my $interface ( @input_interfaces ) {
			    $chain1ref = $input_chains{$interface};
			    add_ijump ( $chainref ,
					j => $chain1ref->{name},
					@input_interfaces > 1 ? imatch_source_dev( $interface ) : () )->{comment} = interface_origin( $interface ) if @{$chain1ref->{rules}};
			}
		    }
		} else {
		    if ( @forward_interfaces == 1 && copy_options( $forward_interfaces[0] ) ) {
			$chain1ref = $forward_chains{$forward_interfaces[0]};
			if ( @{$chain1ref->{rules}} ) {
			    copy_rules $chain1ref, $chainref, 1;
			    $chainref->{referenced} = 1;
			}
		    } else {
			for my $interface ( @forward_interfaces ) {
			    $chain1ref = $forward_chains{$interface};
			    add_ijump ( $chainref , j => $chain1ref->{name}, @forward_interfaces > 1 ? imatch_source_dev( $interface ) : () )->{comment} = interface_origin( $interface ) if  @{$chain1ref->{rules}};
			}
		    }
		}
	    }
	}
	#
	# Now take care of jumps to the interface output option chains
	#
	for my $zone1 ( firewall_zone, vserver_zones ) {
	    for my $zone2 ( off_firewall_zones ) {
		my $chainref = $filter_table->{rules_chain( $zone1, $zone2 )};
		my @interfaces = sort keys %{zone_interfaces( $zone2 )};
		my $chain1ref;

		for my $interface ( @interfaces ) {
		    $chain1ref = $filter_table->{output_option_chain $interface};

		   if ( @{$chain1ref->{rules}} ) {
			copy_rules( $chain1ref, $chainref, 1 );
			$chainref->{referenced} = 1;
		    }
		}
	    }
	}
    } else {
	#
	# No Blacklisting - simply move the option chain rules to the interface chains
	#
	for my $interface ( all_real_interfaces ) {
	    my $chainref;
	    my $chain1ref;

	    $chainref = $filter_table->{input_option_chain $interface};

	    if( @{$chainref->{rules}} ) {
		move_rules $chainref, $chain1ref = $filter_table->{input_chain $interface};
		set_interface_option( $interface, 'use_input_chain', 1 );
	    }

	    $chainref = $filter_table->{forward_option_chain $interface};

	    if ( @{$chainref->{rules}} ) {
		move_rules $chainref, $chain1ref = $filter_table->{forward_chain $interface};
		set_interface_option( $interface, 'use_forward_chain' , 1 );
	    }

	    $chainref = $filter_table->{output_option_chain $interface};

	   if ( @{$chainref->{rules}} ) {
		move_rules $chainref, $chain1ref = $filter_table->{output_chain $interface};
		set_interface_option( $interface, 'use_output_chain' , 1 );
	    }
	}
    }
}

#
# The following functions generate the input to iptables-restore from the contents of the
# @rules arrays in the chain table entries.
#
# We always write the iptables-restore input into a file then pass the
# file to iptables-restore. That way, if things go wrong, the user (and Shorewall support)
# has (have) something to look at to determine the error
#
# We may have to generate part of the input at run-time. The rules array in each chain
# table entry may contain both rules or shell source, determined by the contents of the 'mode'
# member. We alternate between writing the rules into the temporary file to be passed to
# iptables-restore (CAT_MODE) and and writing shell source into the generated script (CMD_MODE).
#
# The following two functions are responsible for the mode transitions.
#
sub enter_cat_mode() {
    emit '';
    emit 'cat >&3 << __EOF__';
    $mode = CAT_MODE;
}

sub enter_cmd_mode() {
    emit_unindented "__EOF__\n" if $mode == CAT_MODE;
    $mode = CMD_MODE;
}

#
# Emits the passed rule (input to iptables-restore) or command
#
sub emitr( $$ ) {
    my ( $chainref, $ruleref ) = @_;

    assert( $chainref );

    if ( $ruleref ) {
	if ( $ruleref->{mode} == CAT_MODE ) {
	    #
	    # A rule
	    #
	    enter_cat_mode unless $mode == CAT_MODE;
	    emit_unindented format_rule( $chainref, $ruleref );
	} else {
	    #
	    # A command
	    #
	    enter_cmd_mode unless $mode == CMD_MODE;

	    if ( exists $ruleref->{cmd} ) {
		emit join( '', '    ' x $ruleref->{cmdlevel}, $ruleref->{cmd} );
	    } else {
		#
		# Must preserve quotes in the rule
		#
		( my $rule = format_rule( $chainref, $ruleref ) ) =~ s/"/\\"/g;

		emit join( '', '    ' x $ruleref->{cmdlevel} , 'echo "' , $rule, '" >&3' );
	    }
	}
    }
}

#
# These versions are used by 'preview'
#
sub enter_cat_mode1() {
    print "\n";
    emitstd "cat << __EOF__ >&3";
    $mode = CAT_MODE;
}

sub enter_cmd_mode1() {
    print "__EOF__\n\n" if $mode == CAT_MODE;
    $mode = CMD_MODE;
}

sub emitr1( $$ ) {
    my ( $chainref, $ruleref ) = @_;

    if ( $ruleref ) {
	if ( $ruleref->{mode} == CAT_MODE ) {
	    #
	    # A rule
	    #
	    enter_cat_mode1 unless $mode == CAT_MODE;

	    print format_rule( $chainref, $ruleref ) . "\n";
	} else {
	    #
	    # A command
	    #
	    enter_cmd_mode1 unless $mode == CMD_MODE;

	    if ( exists $ruleref->{cmd} ) {
		emitstd $ruleref->{cmd};
	    } else {
		( my $rule = format_rule( $chainref, $ruleref ) ) =~ s/"/\\"/g;

		emitstd join( '', '    ' x $ruleref->{cmdlevel} , 'echo "' , $rule, '" >&3' );
	    }
	}
    }
}

#
# Emit code to save the dynamic chains to hidden files in ${VARDIR}
#

sub save_dynamic_chains() {

    my $tool    = $family == F_IPV4 ? '${IPTABLES}'      : '${IP6TABLES}';
    my $utility = $family == F_IPV4 ? 'iptables-restore' : 'ip6tables-restore';

    emit ( 'if [ "$COMMAND" = reload -o "$COMMAND" = refresh ]; then' );
    push_indent;

    emit( 'if [ -n "$g_counters" ]; then' ,
	  "    ${tool}-save --counters | grep -vE '[ :]shorewall ' > \${VARDIR}/.${utility}-input",
	  "fi\n"
	);

    if ( have_capability 'IPTABLES_S' ) {
	emit <<"EOF";
if chain_exists 'UPnP -t nat'; then
    $tool -t nat -S UPnP | tail -n +2 > \${VARDIR}/.UPnP
else
    rm -f \${VARDIR}/.UPnP
fi

if chain_exists forwardUPnP; then
    $tool -S forwardUPnP | tail -n +2 > \${VARDIR}/.forwardUPnP
else
    rm -f \${VARDIR}/.forwardUPnP
fi

if chain_exists dynamic; then
    $tool -S dynamic | tail -n +2 | fgrep -v -- '-j ACCEPT' > \${VARDIR}/.dynamic
else
    rm -f \${VARDIR}/.dynamic
fi
EOF

    } else {
	$tool = $family == F_IPV4 ? '${IPTABLES}-save' : '${IP6TABLES}-save';

	emit <<"EOF";
if chain_exists 'UPnP -t nat'; then
    $tool -t nat | grep '^-A UPnP ' > \${VARDIR}/.UPnP
else
    rm -f \${VARDIR}/.UPnP
fi

if chain_exists forwardUPnP; then
    $tool -t filter | grep '^-A forwardUPnP ' > \${VARDIR}/.forwardUPnP
else
    rm -f \${VARDIR}/.forwardUPnP
fi

if chain_exists dynamic; then
    $tool -t filter | grep '^-A dynamic ' > \${VARDIR}/.dynamic
else
    rm -f \${VARDIR}/.dynamic
fi
EOF
    }

    pop_indent;
    emit ( 'else' );
    push_indent;

emit <<"EOF";
rm -f \${VARDIR}/.UPnP
rm -f \${VARDIR}/.forwardUPnP
EOF

    if ( have_capability 'IPTABLES_S' ) {
	emit( qq(if [ "\$COMMAND" = stop -o "\$COMMAND" = clear ]; then),
	      qq(    if chain_exists dynamic; then),
	      qq(        $tool -S dynamic | tail -n +2 > \${VARDIR}/.dynamic) );
    } else {
	emit( qq(if [ "\$COMMAND" = stop -o "\$COMMAND" = clear ]; then),
	      qq(    if chain_exists dynamic; then),
	      qq(        $tool -t filter | grep '^-A dynamic ' > \${VARDIR}/.dynamic) );
    }

emit <<"EOF";
    fi
fi
EOF

    pop_indent;

    emit ( 'fi' ,
	   '' );
}

sub ensure_ipset( $ ) {
    my $set = shift;

    if ( $family == F_IPV4 ) {
	if ( have_capability 'IPSET_V5' ) {
	    emit ( qq(    if ! qt \$IPSET -L $set -n; then) ,
		   qq(        error_message "WARNING: ipset $set does not exist; creating it as an hash:ip set") ,
		   qq(        \$IPSET -N $set hash:ip family inet) ,
		   qq(    fi) );
	} else {
	    emit ( qq(    if ! qt \$IPSET -L $set -n; then) ,
		   qq(        error_message "WARNING: ipset $set does not exist; creating it as an iphash set") ,
		   qq(        \$IPSET -N $set iphash) ,
		   qq(    fi) );
	}
    } else {
	emit ( qq(    if ! qt \$IPSET -L $set -n; then) ,
	       qq(        error_message "WARNING: ipset $set does not exist; creating it as an hash:ip set") ,
	       qq(        \$IPSET -N $set hash:ip family inet6) ,
	       qq(    fi) );
    }
}

#
# Generate the save_ipsets() function
#
sub create_save_ipsets() {
    my @ipsets = all_ipsets;

    emit( "#\n#Save the ipsets specified by the SAVE_IPSETS setting and by dynamic zones\n#",
	  'save_ipsets() {' );

    if ( @ipsets || @{$globals{SAVED_IPSETS}} || ( $config{SAVE_IPSETS} && have_ipset_rules ) ) {
	emit( '    local file' ,
	      '',
	      '    file=${1:-${VARDIR}/save.ipsets}'
	    );

	if ( @ipsets ) {
	    emit '';
	    ensure_ipset( $_ ) for @ipsets;
	}

	if ( $config{SAVE_IPSETS} ) {
	    if ( $family == F_IPV6 || $config{SAVE_IPSETS} eq 'ipv4' ) {
		my $select = $family == F_IPV4 ? '^create.*family inet ' : 'create.*family inet6 ';

		emit( '' ,
		      '    rm -f $file' ,
		      '    touch $file' ,
		      '    local set' ,
		    );

		if ( @ipsets ) {
		    emit '';
		    emit( "    \$IPSET -S $_ >> \$file" ) for @ipsets;
		}

		emit( '',
		      "    for set in \$(\$IPSET save | grep '$select' | cut -d' ' -f2); do" ,
		      "        \$IPSET save \$set >> \$file" ,
		      "    done" ,
		      '',
		    );
	    } else {
		emit ( 
		       '',
		       '    if eval $IPSET -S > ${VARDIR}/ipsets.tmp; then' ,
		       "        grep -qE -- \"^(-N|create )\" \${VARDIR}/ipsets.tmp && mv -f \${VARDIR}/ipsets.tmp \$file" ,
		       '    fi' );
	    }

	    emit( "    return 0",
		  '',
		  "}\n" );
	} elsif ( @ipsets || $globals{SAVED_IPSETS} ) {
	    emit( '' ,
		  '    rm -f ${VARDIR}/ipsets.tmp' ,
		  '    touch ${VARDIR}/ipsets.tmp' ,
		);

	    if ( @ipsets ) {
		emit '';
		emit( "    \$IPSET -S $_ >> \${VARDIR}/ipsets.tmp" ) for @ipsets;
	    }

	    emit( '' ,
		  "    if qt \$IPSET list $_; then" ,
		  "        \$IPSET save $_ >> \${VARDIR}/ipsets.tmp" ,
		  '    else' ,
		  "        error_message 'ipset $_ not saved (not found)'" ,
		  "    fi\n" ) for @{$globals{SAVED_IPSETS}};

	    emit( '' ,
		  "    grep -qE -- \"(-N|^create )\" \${VARDIR}/ipsets.tmp && cat \${VARDIR}/ipsets.tmp >> \$file\n" ,
		  '' ,
		  '    return 0',
		  '' ,
		  "}\n" );
	}
    } elsif ( $config{SAVE_IPSETS} ) {
	emit( '    error_message "WARNING: No ipsets were saved"',
	      '    return 1',
	      "}\n" );
    } else {
	emit( '    true',
	      "}\n" );
    }
}

sub load_ipsets() {

    my @ipsets = all_ipsets;

    if ( @ipsets || @{$globals{SAVED_IPSETS}} || ( $config{SAVE_IPSETS} && have_ipset_rules ) ) {
	emit ( '', );
	emit ( '',
	       'case $IPSET in',
	       '    */*)',
	       '        [ -x "$IPSET" ] || startup_error "IPSET=$IPSET does not exist or is not executable"',
	       '        ;;',
	       '    *)',
	       '        IPSET="$(mywhich $IPSET)"',
	       '        [ -n "$IPSET" ] || startup_error "The ipset utility cannot be located"' ,
	       '        ;;',
	       'esac' ,
	       '' ,
	       'if [ "$COMMAND" = start ]; then' );

	if ( $config{SAVE_IPSETS} ) {
	    emit ( '    if [ -f ${VARDIR}/ipsets.save ]; then' ,
		   '        $IPSET -F' ,
		   '        $IPSET -X' ,
		   '        $IPSET -R < ${VARDIR}/ipsets.save' ,
		   '    fi' );

	    if ( @ipsets ) {
		emit ( '' );
		ensure_ipset( $_ ) for @ipsets;
		emit ( '' );

		emit ( '    if [ -f ${VARDIR}/ipsets.save ]; then' ,
		       '        $IPSET flush' ,
		       '        $IPSET destroy' ,
		       '        $IPSET restore < ${VARDIR}/ipsets.save' ,
		       "    fi\n" ) for @{$globals{SAVED_IPSETS}};
	    }
	} else {
	    ensure_ipset( $_ ) for @ipsets;

	    if ( @{$globals{SAVED_IPSETS}} ) {
		emit ( '' );

		emit ( '    if [ -f ${VARDIR}/ipsets.save ]; then' ,
		       '        $IPSET flush' ,
		       '        $IPSET destroy' ,
		       '        $IPSET restore < ${VARDIR}/ipsets.save' ,
		       "    fi\n" ) for @{$globals{SAVED_IPSETS}};
	    }
	}

	emit ( 'elif [ "$COMMAND" = restore -a -z "$g_recovering" ]; then' );

	if ( $config{SAVE_IPSETS} ) {
	    emit( '    if [ -f $(my_pathname)-ipsets ]; then' ,
		  '        if chain_exists shorewall; then' ,
		  '            startup_error "Cannot restore $(my_pathname)-ipsets with Shorewall running"' ,
		  '        else' ,
		  '            $IPSET -F' ,
		  '            $IPSET -X' ,
		  '            $IPSET -R < $(my_pathname)-ipsets' ,
		  '        fi' ,
		  '    fi' ,
		);

	    if ( @ipsets ) {
		emit ( '' );
		ensure_ipset( $_ ) for @ipsets;
		emit ( '' );
	    }
	} else {
	    ensure_ipset( $_ ) for @ipsets;

	    emit ( '    if [ -f ${VARDIR}/ipsets.save ]; then' ,
		   '        $IPSET flush' ,
		   '        $IPSET destroy' ,
		   '        $IPSET restore < ${VARDIR}/ipsets.save' ,
		   "    fi\n" ) for @{$globals{SAVED_IPSETS}};
	}

	if ( @ipsets ) {
	    emit ( 'elif [ "$COMMAND" = reload ]; then' );
	    ensure_ipset( $_ ) for @ipsets;
	}

	emit( 'elif [ "$COMMAND" = stop ]; then' ,
	      '   save_ipsets'
	    );

	if ( @ipsets ) {
	    emit( 'elif [ "$COMMAND" = refresh ]; then' );
	    ensure_ipset( $_ ) for @ipsets;
	};

	emit ( 'fi' ,
	       '' );
    }
}

#
# Create nfacct objects if needed
#
sub create_nfobjects() {
    
    my @objects = ( sort keys %nfobjects );

    if ( @objects ) {
	if ( $config{NFACCT} ) {
	    emit( qq(NFACCT="$config{NFACCT}") ,
		  '[ -x "$NFACCT" ] || startup_error "NFACCT=$NFACCT does not exist or is not executable"'
		);
	} else {
	    emit( 'NFACCT=$(mywhich nfacct)' ,
		  '[ -n "$NFACCT" ] || startup_error "No nfacct utility found"',
		  ''
		);
	}
    }

    for ( sort keys %nfobjects ) {
	emit( qq(if ! qt \$NFACCT get $_; then),
	      qq(    \$NFACCT add $_),
	      qq(fi\n) );
    }
}
#
#
# Generate the netfilter input
#
sub create_netfilter_load( $ ) {
    my $test = shift;

    $mode = NULL_MODE;

    emit ( '#',
	   '# Create the input to iptables-restore/ip6tables-restore and pass that input to the utility',
	   '#',
	   'setup_netfilter()',
	   '{',
	   '    local option',
	);

    push_indent;

    my $utility = $family == F_IPV4 ? 'iptables-restore' : 'ip6tables-restore';
    my $UTILITY = $family == F_IPV4 ? 'IPTABLES_RESTORE' : 'IP6TABLES_RESTORE';

    emit( '',
	  'if [ "$COMMAND" = reload -a -n "$g_counters" ] && chain_exists $g_sha1sum1 && chain_exists $g_sha1sum2 ; then',
	  '    option="--counters"',
	  '',
	  '    progress_message "Reusing existing ruleset..."',
	  '',
	  'else'
	);

    push_indent;

    emit 'option=';

    save_progress_message "Preparing $utility input...";

    emit "exec 3>\${VARDIR}/.${utility}-input";

    enter_cat_mode;

    my $date = localtime;

    unless ( $test ) {
	emit_unindented '#';
	emit_unindented "# Generated by Shorewall $globals{VERSION} - $date";
	emit_unindented '#';
    }

    for my $table ( valid_tables ) {
	emit_unindented "*$table";

	my @chains;
	#
	# iptables-restore seems to be quite picky about the order of the builtin chains
	#
	for my $chain ( @builtins ) {
	    my $chainref = $chain_table{$table}{$chain};
	    if ( $chainref ) {
		assert( $chainref->{cmdlevel} == 0, $chainref->{name} );
		emit_unindented ":$chain $chainref->{policy} [0:0]";
		push @chains, $chainref;
	    }
	}
	#
	# First create the chains in the current table
	#
	for my $chain ( grep $chain_table{$table}{$_}->{referenced} , ( sort keys %{$chain_table{$table}} ) ) {
	    my $chainref =  $chain_table{$table}{$chain};
	    unless ( $chainref->{builtin} ) {
		assert( $chainref->{cmdlevel} == 0 , $chainref->{name} );
		emit_unindented ":$chainref->{name} - [0:0]";
		push @chains, $chainref;
	    }
	}
	#
	# SHA1SUM chains for handling 'reload -s'
	#
	if ( $table eq 'filter' ) {
	    emit_unindented ':$g_sha1sum1 - [0:0]';
	    emit_unindented ':$g_sha1sum2 - [0:0]';
	}

	#
	# Then emit the rules
	#
	for my $chainref ( @chains ) {
	    emitr( $chainref, $_ ) for @{$chainref->{rules}};
	}
	#
	# Commit the changes to the table
	#
	enter_cat_mode unless $mode == CAT_MODE;
	emit_unindented 'COMMIT';
    }

    enter_cmd_mode;

    pop_indent, emit "fi\n";
    #
    # Now generate the actual ip[6]tables-restore command
    #
    emit(  'exec 3>&-',
	   '' );

    emit( '[ -n "$g_debug_iptables" ] && command=debug_restore_input || command="$' . $UTILITY . ' $option"' );

    emit( '',
	  'progress_message2 "Running $command..."',
	  '',
	  "cat \${VARDIR}/.${utility}-input | \$command # Use this nonsensical form to appease SELinux",
	  'if [ $? != 0 ]; then',
	  qq(    fatal_error "iptables-restore Failed. Input is in \${VARDIR}/.${utility}-input"),
	  "fi\n"
	);

    pop_indent;

    emit "}\n";
}

#
# Preview netfilter input
#
sub preview_netfilter_load() {

    $mode = NULL_MODE;

    push_indent;

    enter_cat_mode1;

    my $date = localtime;

    print "#\n# Generated by Shorewall $globals{VERSION} - $date\n#\n";

    for my $table ( valid_tables ) {
	print "*$table\n";

	my @chains;
	#
	# iptables-restore seems to be quite picky about the order of the builtin chains
	#
	for my $chain ( @builtins ) {
	    my $chainref = $chain_table{$table}{$chain};
	    if ( $chainref ) {
		assert( $chainref->{cmdlevel} == 0 , $chainref->{name} );
		print ":$chain $chainref->{policy} [0:0]\n";
		push @chains, $chainref;
	    }
	}
	#
	# First create the chains in the current table
	#
	for my $chain ( grep $chain_table{$table}{$_}->{referenced} , ( sort keys %{$chain_table{$table}} ) ) {
	    my $chainref =  $chain_table{$table}{$chain};
	    unless ( $chainref->{builtin} ) {
		assert( $chainref->{cmdlevel} == 0, $chainref->{name} );
		print ":$chainref->{name} - [0:0]\n";
		push @chains, $chainref;
	    }
	}
	#
	# Then emit the rules
	#
	for my $chainref ( @chains ) {
	    emitr1($chainref, $_ ) for @{$chainref->{rules}};
	}
	#
	# Commit the changes to the table
	#
	enter_cat_mode1 unless $mode == CAT_MODE;
	print "COMMIT\n";
    }

    enter_cmd_mode1;

    pop_indent;

    print "\n";
}

#
# Generate the netfilter input for refreshing a list of chains
#
sub create_chainlist_reload($) {

    my $chains = $_[0];

    my @chains;

    unless ( $chains eq ':none:' ) {
	if ( $chains eq ':refresh:' ) {
	    $chains = '';
	} else {
	    @chains =  split_list $chains, 'chain';
	}

	unless ( @chains ) {
	    @chains = qw( blacklst ) if $filter_table->{blacklst};
	    push @chains, 'blackout' if $filter_table->{blackout};

	    for ( grep $_->{blacklistsection} && $_->{referenced}, values %{$filter_table} ) {
		push @chains, $_->{name} if $_->{blacklistsection};
	    }

	    push @chains, 'mangle:' if have_capability( 'MANGLE_ENABLED' ) && $config{MANGLE_ENABLED};
	    $chains = join( ',', @chains ) if @chains;
	}
    }

    $mode = NULL_MODE;

    emit(  'chainlist_reload()',
	   '{'
	   );

    push_indent;

    if ( @chains ) {
	my $word = @chains == 1 ? 'chain' : 'chains';

	progress_message2 "Compiling iptables-restore input for $word @chains...";
	save_progress_message "Preparing iptables-restore input for $word @chains...";

	emit '';

	my $table = 'filter';

	my %chains;

	my %tables;

	for my $chain ( @chains ) {
	    ( $table , $chain ) = split ':', $chain if $chain =~ /:/;

	    fatal_error "Invalid table ( $table )" unless $table =~ /^(nat|mangle|filter|raw|rawpost)$/;

	    $chains{$table} = {} unless $chains{$table};

	    if ( $chain ) {
		my $chainref;
		fatal_error "No $table chain found with name $chain" unless $chainref = $chain_table{$table}{$chain};
		fatal_error "Built-in chains may not be refreshed" if $chainref->{builtin};

		if ( $chainseq{$table} && @{$chainref->{rules}} ) {
		    $tables{$table} = 1;
		} else {
		    $chains{$table}{$chain} = $chainref;
		}
	    } else {
		$tables{$table} = 1;
	    }
	}

	for $table ( keys %tables ) {
	    while ( my ( $chain, $chainref ) = each %{$chain_table{$table}} ) {
		$chains{$table}{$chain} = $chainref if $chainref->{referenced} && ! $chainref->{builtin};
	    }
	}

	emit 'exec 3>${VARDIR}/.iptables-restore-input';

	enter_cat_mode;

	for $table ( qw(raw rawpost nat mangle filter) ) {
	    my $tableref=$chains{$table};

	    next unless $tableref;

	    @chains = sort keys %$tableref;

	    emit_unindented "*$table";

	    for my $chain ( @chains ) {
		my $chainref = $tableref->{$chain};
		emit_unindented ":$chainref->{name} - [0:0]";
	    }

	    for my $chain ( @chains ) {
		my $chainref = $tableref->{$chain};
		my @rules = @{$chainref->{rules}};
		my $name = $chainref->{name};

		@rules = () unless @rules;
		#
		# Emit the chain rules
		#
		emitr($chainref, $_) for @rules;
	    }
	    #
	    # Commit the changes to the table
	    #
	    enter_cat_mode unless $mode == CAT_MODE;

	    emit_unindented 'COMMIT';
	}

	enter_cmd_mode;

	#
	# Now generate the actual ip[6]tables-restore command
	#
	emit(  'exec 3>&-',
	       '' );

	if ( $family == F_IPV4 ) {
	    emit ( 'progress_message2 "Running iptables-restore..."',
		   '',
		   'cat ${VARDIR}/.iptables-restore-input | $IPTABLES_RESTORE -n # Use this nonsensical form to appease SELinux',
		   'if [ $? != 0 ]; then',
		   '    fatal_error "iptables-restore Failed. Input is in ${VARDIR}/.iptables-restore-input"',
		   "fi\n"
		 );
	} else {
	    emit ( 'progress_message2 "Running ip6tables-restore..."',
		   '',
		   'cat ${VARDIR}/.iptables-restore-input | $IP6TABLES_RESTORE -n # Use this nonsensical form to appease SELinux',
		   'if [ $? != 0 ]; then',
		   '    fatal_error "ip6tables-restore Failed. Input is in ${VARDIR}/.iptables-restore-input"',
		   "fi\n"
		 );
	}
    } else {
	emit('true');
    }

    pop_indent;

    emit "}\n";
}

#
# Generate the netfilter input to stop the firewall
#
sub create_stop_load( $ ) {
    my $test = shift;

    my $utility = $family == F_IPV4 ? 'iptables-restore' : 'ip6tables-restore';
    my $UTILITY = $family == F_IPV4 ? 'IPTABLES_RESTORE' : 'IP6TABLES_RESTORE';

    emit '';

    emit(  '[ -n "$g_debug_iptables" ] && command=debug_restore_input || command=$' . $UTILITY,
	   '',
	   'progress_message2 "Running $command..."',
	   '',
	   '$command <<__EOF__' );

    $mode = CAT_MODE;

    unless ( $test ) {
	my $date = localtime;
	emit_unindented '#';
	emit_unindented "# Generated by Shorewall $globals{VERSION} - $date";
	emit_unindented '#';
    }

    for my $table ( valid_tables ) {
	emit_unindented "*$table";

	my @chains;
	#
	# iptables-restore seems to be quite picky about the order of the builtin chains
	#
	for my $chain ( @builtins ) {
	    my $chainref = $chain_table{$table}{$chain};
	    if ( $chainref ) {
		assert( $chainref->{cmdlevel} == 0 , $chainref->{name} );
		emit_unindented ":$chain $chainref->{policy} [0:0]";
		push @chains, $chainref;
	    }
	}
	#
	# First create the chains in the current table
	#
	for my $chain ( grep $chain_table{$table}{$_}->{referenced} , ( sort keys %{$chain_table{$table}} ) ) {
	    my $chainref =  $chain_table{$table}{$chain};
	    unless ( $chainref->{builtin} ) {
		assert( $chainref->{cmdlevel} == 0 , $chainref->{name} );
		emit_unindented ":$chainref->{name} - [0:0]";
		push @chains, $chainref;
	    }
	}
	#
	# Then emit the rules
	#
	for my $chainref ( @chains ) {
	    emitr( $chainref, $_ ) for @{$chainref->{rules}};
	}
	#
	# Commit the changes to the table
	#
	emit_unindented 'COMMIT';
    }

    emit_unindented '__EOF__';
    #
    # Test result
    #
    emit ('',
	  'if [ $? != 0 ]; then',
	   '    error_message "ERROR: $command Failed."',
	   "fi\n"
	 );

}

sub initialize_switches() {
    if ( keys %switches ) {
	emit( 'if [ $COMMAND = start ]; then' );
	push_indent;
	for my $switch ( sort keys %switches ) {
	    my $setting = $switches{$switch};
	    my $file = "/proc/net/nf_condition/$switch";
	    emit "[ -f $file ] && echo $setting->{setting} > $file";
	}
	pop_indent;
	emit "fi\n";
    }
}

#
# Return ( action, level[:tag] ) from passed full action
#
sub split_action ( $ ) {
    my $action = $_[0];

    my @list   = split_list2( $action, 'ACTION' );

    fatal_error "Invalid ACTION ($action)" if @list > 3;

    ( shift @list, join( ':', @list ) );
}

#
# Get inline matches and conditionally verify the absense of -j
#
sub get_inline_matches( $ ) {
    if ( $_[0] ) {
	fetch_inline_matches;
    } else {
	my $inline_matches = fetch_inline_matches;

	fatal_error "-j is only allowed when the ACTION is INLINE with no parameter" if $inline_matches =~ /\s-j\s/;

	$inline_matches;
    }
}

#
# Split the passed target into the basic target and parameter
#
sub get_target_param( $ ) {
    my ( $target, $param ) = split '/', $_[0], 2;

    unless ( defined $param ) {
	( $target, $param ) = ( $1, $2 ) if $target =~ /^(.*?)[(](.*)[)]$/;
    }

    ( $target, $param );
}

sub get_target_param1( $ ) {
    my $target = $_[0];

    if ( $target =~ /^(.*?)[(](.*)[)]$/ ) {
	( $1, $2 );
    } else {
	( $target, '' );
    }
}

sub handle_inline( $$$$$$ ) {
    my ( $table, $tablename, $action, $basictarget, $param, $loglevel ) = @_;
    my $inline_matches = get_inline_matches(1);
    my $raw_matches = '';

    if ( $inline_matches =~ /^(.*\s+)?-j\s+(.+) $/ ) {
	$raw_matches .= $1 if supplied $1;
	$action = $2;
	my ( $target ) = split ' ', $action;
	my $target_type = $builtin_target{$target};
	fatal_error "Unknown jump target ($action)" unless $target_type;
	fatal_error "The $target TARGET is not allowed in the $tablename table" unless $target_type & $table;
	fatal_error "INLINE may not have a parameter when '-j' is specified in the free-form area" if $param ne '';
    } else {
	$raw_matches .= $inline_matches;
	
	if ( $param eq '' ) {
	    $action = $loglevel ? 'LOG' : '';
	} else {
	    ( $action, $loglevel )   = split_action $param;
	    ( $basictarget, $param ) = get_target_param $action;
	    $param = '' unless defined $param;
	}
    }

    return ( $action, $basictarget, $param, $loglevel, $raw_matches );
}

1;
