#
# Shorewall 4.4 -- /usr/share/shorewall/Shorewall/Rules.pm
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
#   This module contains process_rule() and it's associated helpers for handling 
#   Actions and Macros.
#
#   This module combines the former Rules and Actions modules.
#
package Shorewall::Rules;
require Exporter;
use Shorewall::Config qw(:DEFAULT :internal);
use Shorewall::Zones;
use Shorewall::Chains qw(:DEFAULT :internal);
use Shorewall::IPAddrs;
use Shorewall::Policy;
use Scalar::Util 'reftype';

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw(
		  process_actions1
		  process_actions2
		  process_rules
	       );

our @EXPORT_OK = qw( initialize );
our $VERSION = '4.4_17';

our %macros;

our $family;

our @builtins;

#
# Commands that can be embedded in a basic rule and how many total tokens on the line (0 => unlimited).
#
our $rule_commands = { COMMENT => 0, FORMAT => 2 };

use constant { MAX_MACRO_NEST_LEVEL => 5 };

our $macro_nest_level;

our @actionstack;
our %active;

#  Action Table
#
#     %actions{ actchain => used to eliminate collisions }
#
our %actions;
#
# Contains an entry for each used <action>:<level>[:<tag>] that maps to the associated chain.
#
our %usedactions;

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
    $family            = shift;
    %macros            = ();
    @actionstack       = ();
    %active            = ();
    $macro_nest_level  = 0;
    %actions           = ();
    %usedactions       = ();

    if ( $family == F_IPV4 ) {
	@builtins = qw/dropBcast allowBcast dropNotSyn rejNotSyn dropInvalid allowInvalid allowinUPnP forwardUPnP Limit/;
    } else {
	@builtins = qw/dropBcast allowBcast dropNotSyn rejNotSyn dropInvalid allowInvalid/;
    }
}

#
# Return ( action, level[:tag] ) from passed full action
#
sub split_action ( $ ) {
    my $action = $_[0];

    my $target = '';
    my $max    = 3;
    #
    # The following rather grim RE, when matched, breaks the action into two parts:
    #
    #    basicaction(param)
    #    logging part (may be empty)
    #
    # The param may contain one or more ':' characters
    #
    if ( $action =~ /^([^(:]+\(.*?\))(:(.*))?$/ ) {
	$target = $1;
	$action = $2 ? $3 : '';
	$max    = 2;
    }

    my @a = split( /:/ , $action, 4 );
    fatal_error "Invalid ACTION ($action)" if ( $action =~ /::/ ) || ( @a > $max );
    $target = shift @a unless $target;
    ( $target, join ":", @a );
}

#
# Split the passed target into the basic target and parameter
#
sub get_target_param( $ ) {
    my ( $target, $param ) = split '/', $_[0];

    unless ( defined $param ) {
	( $target, $param ) = ( $1, $2 ) if $target =~ /^(.*?)[(](.*)[)]$/;
    }

    ( $target, $param );
}

#
# Create a normalized action name from the passed pieces.
#
# Internally, action invocations are uniquely identified by a 4-tuple that 
# includes the action name, log level, log tag and params. The pieces of the tuple
# are separated by ":". 
#
sub normalize_action( $$$ ) {
    my $action = shift;
    my $level  = shift;
    my $param  = shift;

    ( $level, my $tag ) = split ':', $level;

    $level = 'none' unless defined $level && $level ne '';
    $tag   = ''     unless defined $tag;
    $param = ''     unless defined $param;

    join( ':', $action, $level, $tag, $param );
}

#
# Accepts a rule target and returns a normalized tuple
#

sub normalize_action_name( $ ) {
    my $target = shift;
    my ( $action, $loglevel) = split_action $target;

    normalize_action( $action, $loglevel, '' );
}

#
# Produce a recognizable target from a normalized action
#
sub externalize( $ ) {
    my ( $target, $level, $tag, $params ) = split /:/, shift, 4;

    $target  = join( '', $target, '(', $params , ')' ) if $params;
    $target .= ":$level" if $level && $level ne 'none';
    $target .= ":$tag"   if $tag;
    $target;
}
    
#
# Define an Action
#
sub new_action( $$ ) {

    my ( $action , $type ) = @_;

    $actions{$action} = { actchain => ''  };

    $targets{$action} = $type;
}

#
# Create and record a log action chain -- Log action chains have names
# that are formed from the action name by prepending a "%" and appending
# a 1- or 2-digit sequence number. In the functions that follow,
# the $chain, $level and $tag variable serves as arguments to the user's
# exit. We call the exit corresponding to the name of the action but we
# set $chain to the name of the iptables chain where rules are to be added.
# Similarly, $level and $tag contain the log level and log tag respectively.
#
# The maximum length of a chain name is 30 characters -- since the log
# action chain name is 2-3 characters longer than the base chain name,
# this function truncates the original chain name where necessary before
# it adds the leading "%" and trailing sequence number.
#
sub createlogactionchain( $$$$$ ) {
    my ( $normalized, $action, $level, $tag, $param ) = @_;
    my $chain = $action;
    my $actionref = $actions{$action};
    my $chainref;

    validate_level $level;

    $actionref = new_action( $action , ACTION ) unless $actionref;

    $chain = substr $chain, 0, 28 if ( length $chain ) > 28;

  CHECKDUP:
    {
	$actionref->{actchain}++ while $chain_table{filter}{'%' . $chain . $actionref->{actchain}};
	$chain = substr( $chain, 0, 27 ), redo CHECKDUP if ( $actionref->{actchain} || 0 ) >= 10 and length $chain == 28;
    }

    $usedactions{$normalized} = $chainref = new_standard_chain '%' . $chain . $actionref->{actchain}++;

    fatal_error "Too many invocations of Action $action" if $actionref->{actchain} > 99;

    $chainref->{action} = $normalized;

    unless ( $targets{$action} & BUILTIN ) {

	dont_optimize $chainref;

	my $file = find_file $chain;

	if ( -f $file ) {
	    progress_message "Running $file...";

	    my @params = split /,/, $param;

	    unless ( my $return = eval `cat $file` ) {
		fatal_error "Couldn't parse $file: $@" if $@;
		fatal_error "Couldn't do $file: $!"    unless defined $return;
		fatal_error "Couldn't run $file";
	    }
	}
    }

    $chainref;
}

sub createsimpleactionchain( $ ) {
    my $action  = shift;
    my $normalized = normalize_action_name( $action );

    return createlogactionchain( $normalized, $action, 'none', '', '' ) if $filter_table->{$action} || $nat_table->{$action};
	
    my $chainref = new_standard_chain $action;

    $usedactions{$normalized} = $chainref;

    $chainref->{action} = $normalized;

    unless ( $targets{$action} & BUILTIN ) {

	dont_optimize $chainref;

	my $file = find_file $action;

	if ( -f $file ) {
	    progress_message "Running $file...";

	    my ( $level, $tag ) = ( '', '' );

	    unless ( my $return = eval `cat $file` ) {
		fatal_error "Couldn't parse $file: $@" if $@;
		fatal_error "Couldn't do $file: $!"    unless defined $return;
		fatal_error "Couldn't run $file";
	    }
	}
    }

    $chainref;
}

#
# Create an action chain and run its associated user exit
#
sub createactionchain( $ ) {
    my $normalized = shift;

    my ( $target, $level, $tag, $param ) = split /:/, $normalized, 4;

    assert( defined $param );

    my $chainref;

    if ( $level eq 'none' && $tag eq '' && $param eq '' ) {
	createsimpleactionchain $target;
    } else {
	createlogactionchain $normalized, $target , $level , $tag, $param;
    }
}

#
# Mark an action as used and create its chain. Returns a reference to the chain if the chain was
# created on this call or 0 otherwise.
#
sub use_action( $ ) {
    my $normalized = shift;

    if ( $usedactions{$normalized} ) {
	0;
    } else {
	createactionchain $normalized;
    }
}

#
# This function determines the logging and params for a subordinate action or a rule within a superior action
#
sub merge_levels ($$) {
    my ( $superior, $subordinate ) = @_;

    my @supparts = split /:/, $superior;
    my @subparts = split /:/, $subordinate;

    my $subparts = @subparts;

    my $target   = $subparts[0];

    push @subparts, '' while @subparts < 3;   #Avoid undefined values

    my $level = $supparts[1];
    my $tag   = $supparts[2];

    if ( @supparts == 3 ) {
	return "$target:none!:$tag"   if $level eq 'none!';
	return "$target:$level:$tag"  if $level =~ /!$/;
	return $subordinate           if $subparts >= 2;
	return "$target:$level:$tag";
    }

    if ( @supparts == 2 ) {
	return "$target:none!"        if $level eq 'none!';
	return "$target:$level"       if ($level =~ /!$/) || ($subparts < 2);
    }

    $subordinate;
}

#
# Try to find a macro file -- RETURNS false if the file doesn't exist or MACRO if it does.
# If the file exists, the macro is entered into the 'targets' table and the fully-qualified
# name of the file is stored in the 'macro' table.
#
sub find_macro( $ )
{
    my $macro = $_[0];
    my $macrofile = find_file "macro.$macro";

    if ( -f $macrofile ) {
	$macros{$macro} = $macrofile;
	$targets{$macro} = MACRO;
    } else {
	0;
    }
}

#
# This function substitutes the second argument for the first part of the first argument up to the first colon (":")
#
# Example:
#
#         substitute_param DNAT PARAM:info:FTP
#
#         produces "DNAT:info:FTP"
#
sub substitute_param( $$ ) {
    my ( $param, $action ) = @_;

    if ( $action =~ /:/ ) {
	my $logpart = (split_action $action)[1];
	$logpart =~ s!/$!!;
	return "$param:$logpart";
    }

    $param;
}

#
# Combine fields from a macro body with one from the macro invocation
#
sub merge_macro_source_dest( $$ ) {
    my ( $body, $invocation ) = @_;

    if ( $invocation ) {
	if ( $body ) {
	    return $body if $invocation eq '-';
	    return "$body:$invocation" if $invocation =~ /.*?\.*?\.|^\+|^!+|^~|^!~|~<|~\[/;
	    return "$invocation:$body";
	}

	return $invocation;
    }

    $body || '';
}

sub merge_macro_column( $$ ) {
    my ( $body, $invocation ) = @_;

    if ( defined $invocation && $invocation ne '' && $invocation ne '-' ) {
	$invocation;
    } else {
	$body;
    }
}

#
# Get Macro Name -- strips away trailing /*, :* and (*) from the first column in a rule, macro or action.
#
sub isolate_basic_target( $ ) {
    my $target = ( split '[/:]', $_[0])[0];

    $target =~ /^(\w+)[(].*[)]$/ ? $1 : $target;
}

#
# Map pre-3.0 actions to the corresponding Macro invocation
#

sub find_old_action ( $$$ ) {
    my ( $target, $macro, $param ) = @_;

    if ( my $actiontype = find_macro( $macro ) ) {
	( $macro, $actiontype , $param );
    } else {
	( $target, 0, '' );
    }
}

sub map_old_actions( $ ) {
    my $target = shift;

    if ( $target =~ /^Allow(.*)$/ ) {
	find_old_action( $target, $1, 'ACCEPT' );
    } elsif ( $target =~ /^Drop(.*)$/ ) {
	find_old_action( $target, $1, 'DROP' );
    } elsif ( $target = /^Reject(.*)$/ ) {
	find_old_action( $target, $1, 'REJECT' );
    } else {
	( $target, 0, '' );
    }
}

#
# The following small functions generate rules for the builtin actions of the same name
#
sub dropBcast( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    if ( have_capability( 'ADDRTYPE' ) ) {
	if ( $level ne '' ) {
	    log_rule_limit $level, $chainref, 'dropBcast' , 'DROP', '', $tag, 'add', ' -m addrtype --dst-type BROADCAST ';
	    if ( $family == F_IPV4 ) {
		log_rule_limit $level, $chainref, 'dropBcast' , 'DROP', '', $tag, 'add', ' -d 224.0.0.0/4 ';
	    } else {
		log_rule_limit $level, $chainref, 'dropBcast' , 'DROP', '', $tag, 'add', join( ' ', ' -d' , IPv6_MULTICAST , '-j DROP ' );
	    }
	}

	add_rule $chainref, '-m addrtype --dst-type BROADCAST -j DROP';
    } else {
	if ( $family == F_IPV4 ) {
	    add_commands $chainref, 'for address in $ALL_BCASTS; do';
	} else {
	    add_commands $chainref, 'for address in $ALL_ACASTS; do';
	}

	incr_cmd_level $chainref;
	log_rule_limit $level, $chainref, 'dropBcast' , 'DROP', '', $tag, 'add', ' -d $address ' if $level ne '';
	add_rule $chainref, '-d $address -j DROP';
	decr_cmd_level $chainref;
	add_commands $chainref, 'done';

	log_rule_limit $level, $chainref, 'dropBcast' , 'DROP', '', $tag, 'add', ' -d 224.0.0.0/4 ' if $level ne '';
    }

    if ( $family == F_IPV4 ) {
	add_rule $chainref, '-d 224.0.0.0/4 -j DROP';
    } else {
	add_rule $chainref, join( ' ', '-d', IPv6_MULTICAST, '-j DROP' );
    }
}

sub allowBcast( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    if ( $family == F_IPV4 && have_capability( 'ADDRTYPE' ) ) {
	if ( $level ne '' ) {
	    log_rule_limit $level, $chainref, 'allowBcast' , 'ACCEPT', '', $tag, 'add', ' -m addrtype --dst-type BROADCAST ';
	    log_rule_limit $level, $chainref, 'allowBcast' , 'ACCEPT', '', $tag, 'add', ' -d 224.0.0.0/4 ';
	}

	add_rule $chainref, '-m addrtype --dst-type BROADCAST -j ACCEPT';
	add_rule $chainref, '-d 224.0.0.0/4 -j ACCEPT';
    } else {
	if ( $family == F_IPV4 ) {
	    add_commands $chainref, 'for address in $ALL_BCASTS; do';
	} else {
	    add_commands $chainref, 'for address in $ALL_MACASTS; do';
	}

	incr_cmd_level $chainref;
	log_rule_limit $level, $chainref, 'allowBcast' , 'ACCEPT', '', $tag, 'add', ' -d $address ' if $level ne '';
	add_rule $chainref, '-d $address -j ACCEPT';
	decr_cmd_level $chainref;
	add_commands $chainref, 'done';

	if ( $family == F_IPV4 ) {
	    log_rule_limit $level, $chainref, 'allowBcast' , 'ACCEPT', '', $tag, 'add', ' -d 224.0.0.0/4 ' if $level ne '';
	    add_rule $chainref, '-d 224.0.0.0/4 -j ACCEPT';
	} else {
	    log_rule_limit $level, $chainref, 'allowBcast' , 'ACCEPT', '', $tag, 'add', ' -d ' . IPv6_MULTICAST . ' ' if $level ne '';
	    add_rule $chainref, join ( ' ', '-d', IPv6_MULTICAST, '-j ACCEPT' );
	}
    }
}

sub dropNotSyn ( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    log_rule_limit $level, $chainref, 'dropNotSyn' , 'DROP', '', $tag, 'add', '-p 6 ! --syn ' if $level ne '';
    add_rule $chainref , '-p 6 ! --syn -j DROP';
}

sub rejNotSyn ( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    log_rule_limit $level, $chainref, 'rejNotSyn' , 'REJECT', '', $tag, 'add', '-p 6 ! --syn ' if $level ne '';
    add_rule $chainref , '-p 6 ! --syn -j REJECT --reject-with tcp-reset';
}

sub dropInvalid ( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    log_rule_limit $level, $chainref, 'dropInvalid' , 'DROP', '', $tag, 'add', "$globals{STATEMATCH} INVALID " if $level ne '';
    add_rule $chainref , "$globals{STATEMATCH} INVALID -j DROP";
}

sub allowInvalid ( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    log_rule_limit $level, $chainref, 'allowInvalid' , 'ACCEPT', '', $tag, 'add', "$globals{STATEMATCH} INVALID " if $level ne '';
    add_rule $chainref , "$globals{STATEMATCH} INVALID -j ACCEPT";
}

sub forwardUPnP ( $$$ ) {
    my $chainref = dont_optimize 'forwardUPnP';
    add_commands( $chainref , '[ -f ${VARDIR}/.forwardUPnP ] && cat ${VARDIR}/.forwardUPnP >&3' );
}

sub allowinUPnP ( $$$ ) {
    my ($chainref, $level, $tag) = @_;

    if ( $level ne '' ) {
	log_rule_limit $level, $chainref, 'allowinUPnP' , 'ACCEPT', '', $tag, 'add', '-p 17 --dport 1900 ';
	log_rule_limit $level, $chainref, 'allowinUPnP' , 'ACCEPT', '', $tag, 'add', '-p 6 --dport 49152 ';
    }

    add_rule $chainref, '-p 17 --dport 1900 -j ACCEPT';
    add_rule $chainref, '-p 6 --dport 49152 -j ACCEPT';
}

sub Limit( $$$$ ) {
    my ($chainref, $level, $tag, $param ) = @_;

    my @param;

    if ( $param ) {
	@param = split /,/, $param;
    } else {
	@param = split /,/, $tag;
	$tag = '';
    }

    fatal_error 'Limit rules must include <set name>,<max connections>,<interval> as the log tag or as parameters' unless @param == 3;

    my $set   = $param[0];

    for ( @param[1,2] ) {
	fatal_error 'Max connections and interval in Limit rules must be numeric (' . join( ':', 'Limit', $level eq '' ? 'none' : $level, $tag ) . ')' unless /^\d+$/
    }

    my $count = $param[1] + 1;

    require_capability( 'RECENT_MATCH' , 'Limit rules' , '' );

    add_rule $chainref, "-m recent --name $set --set";

    if ( $level ne '' ) {
	my $xchainref = new_chain 'filter' , "$chainref->{name}%";
	log_rule_limit $level, $xchainref, $param[0], 'DROP', '', $tag, 'add', '';
	add_rule $xchainref, '-j DROP';
	add_jump $chainref,  $xchainref, 0, "-m recent --name $set --update --seconds $param[2] --hitcount $count ";
    } else {
	add_rule $chainref, "-m recent --update --name $set --seconds $param[2] --hitcount $count -j DROP";
    }

    add_rule $chainref, '-j ACCEPT';
}

my %builtinops = ( 'dropBcast'      => \&dropBcast,
		   'allowBcast'     => \&allowBcast,
		   'dropNotSyn'     => \&dropNotSyn,
		   'rejNotSyn'      => \&rejNotSyn,
		   'dropInvalid'    => \&dropInvalid,
		   'allowInvalid'   => \&allowInvalid,
		   'allowinUPnP'    => \&allowinUPnP,
		   'forwardUPnP'    => \&forwardUPnP,
		   'Limit'          => \&Limit, );

#
# This function is called prior to processing of the policy file. It:
#
# - Adds the builtin actions to the target table
# - Reads actions.std and actions (in that order) and for each entry:
#   o Adds the action to the target table
#   o Verifies that the corresponding action file exists
#

sub process_actions1() {

    progress_message2 "Locating Action Files...";
    #
    # Add built-in actions to the target table and create those actions
    #
    $targets{$_} = new_action( $_ , ACTION + BUILTIN ) for @builtins;

    for my $file ( qw/actions.std actions/ ) {
	open_file $file;

	while ( read_a_line ) {
	    my ( $action ) = split_line 1, 1, 'action file';

	    if ( $action =~ /:/ ) {
		warning_message 'Default Actions are now specified in /etc/shorewall/shorewall.conf';
		$action =~ s/:.*$//;
	    }

	    fatal_error "Invalid Action Name ($action)" unless $action =~ /^[\w-]+$/;

	    if ( $targets{$action} ) {
		warning_message "Duplicate Action Name ($action) Ignored" unless $targets{$action} & ACTION;
		next;
	    }

	    fatal_error "Invalid Action Name ($action)" unless "\L$action" =~ /^[a-z]\w*$/;

	    new_action $action, ACTION;

	    my $actionfile = find_file "action.$action";

	    fatal_error "Missing Action File ($actionfile)" unless -f $actionfile;
	}
    }
}

sub process_rule1 ( $$$$$$$$$$$$$$$$ );

#
# Populate an action invocation chain. As new action tuples are encountered,
# the function will be called recursively by process_rules_common().
#
sub process_action( $) {
    my $chainref = shift;
    my $wholeaction = $chainref->{action};
    my ( $action, $level, $tag, $param ) = split /:/, $wholeaction, 4;

    if ( $targets{$action} & BUILTIN ) {
	$level = '' if $level =~ /none!?/;
	$builtinops{$action}->( $chainref, $level, $tag, $param );
    } else {
	my $actionfile = find_file "action.$action";
	my $format = 1;

	fatal_error "Missing Action File ($actionfile)" unless -f $actionfile;

	progress_message2 "$doing $actionfile for chain $chainref->{name}...";

	push_open $actionfile;

	my $oldparms = push_params( $param );

	$active{$wholeaction}++;
	push @actionstack, $wholeaction;

	while ( read_a_line ) {

	    my ($target, $source, $dest, $proto, $ports, $sports, $origdest, $rate, $user, $mark, $connlimit, $time, $headers );

	    if ( $format == 1 ) {
		($target, $source, $dest, $proto, $ports, $sports, $rate, $user, $mark ) = split_line1 1, 9, 'action file', $rule_commands;
		$origdest = $connlimit = $time = $headers = '-';
	    } else {
		($target, $source, $dest, $proto, $ports, $sports, $origdest, $rate, $user, $mark, $connlimit, $time, $headers ) = split_line1 1, 13, 'action file', $rule_commands;
	    }

	    if ( $target eq 'COMMENT' ) {
		process_comment;
		next;
	    }

	    if ( $target eq 'FORMAT' ) {
		fatal_error "FORMAT must be 1 or 2" unless $source =~ /^[12]$/;
		$format = $source;
		next;
	    }

	    process_rule1( $chainref,
			   merge_levels( "$action:$level:$tag", $target ),
			   '',
			   $source,
			   $dest,
			   $proto,
			   $ports,
			   $sports,
			   $origdest,
			   $rate,
			   $user,
			   $mark,
			   $connlimit,
			   $time,
			   $headers,
			   0 );
	}

	clear_comment;

	$active{$wholeaction}--;
	pop @actionstack;

	pop_open;

	pop_params( $oldparms );
    }
}

#
# This function creates and populates the chains for the policy actions.
#
sub process_actions2 () {
    progress_message2 "$doing policy actions...";

    for ( map normalize_action_name $_, ( grep ! ( $targets{$_} & BUILTIN ), policy_actions ) ) {
	if ( my $ref = use_action( $_ ) ) {
	    process_action( $ref );
	}
    }
}

#
# Expand a macro rule from the rules file
#
sub process_macro ( $$$$$$$$$$$$$$$$$ ) {
    my ($macro, $chainref, $target, $param, $source, $dest, $proto, $ports, $sports, $origdest, $rate, $user, $mark, $connlimit, $time, $headers, $wildcard ) = @_;

    my $nocomment = no_comment;

    my $format = 1;

    my $generated = 0;

    macro_comment $macro;

    my $macrofile = $macros{$macro};

    progress_message "..Expanding Macro $macrofile...";

    push_open $macrofile;

    while ( read_a_line ) {

	my ( $mtarget, $msource, $mdest, $mproto, $mports, $msports, $morigdest, $mrate, $muser, $mmark, $mconnlimit, $mtime, $mheaders );

	if ( $format == 1 ) {
	    ( $mtarget, $msource, $mdest, $mproto, $mports, $msports, $mrate, $muser ) = split_line1 1, 8, 'macro file', $rule_commands;
	    ( $morigdest, $mmark, $mconnlimit, $mtime, $mheaders ) = qw/- - - - -/;
	} else {
	    ( $mtarget, $msource, $mdest, $mproto, $mports, $msports, $morigdest, $mrate, $muser, $mmark, $mconnlimit, $mtime, $mheaders ) = split_line1 1, 13, 'macro file', $rule_commands;
	}

	if ( $mtarget eq 'COMMENT' ) {
	    process_comment unless $nocomment;
	    next;
	}

	if ( $mtarget eq 'FORMAT' ) {
	    fatal_error "Invalid FORMAT ($msource)" unless $msource =~ /^[12]$/;
	    $format = $msource;
	    next;
	}

	$mtarget = merge_levels $target, $mtarget;

	if ( $mtarget =~ /^PARAM(:.*)?$/ ) {
	    fatal_error 'PARAM requires a parameter to be supplied in macro invocation' unless $param ne '';
	    $mtarget = substitute_param $param,  $mtarget;
	}

	my $action = isolate_basic_target $mtarget;

	fatal_error "Invalid or missing ACTION ($mtarget)" unless defined $action;

	my $actiontype = $targets{$action} || find_macro( $action );

	fatal_error "Invalid Action ($mtarget) in macro" unless $actiontype & ( ACTION +  STANDARD + NATRULE +  MACRO );

	if ( $msource ) {
	    if ( $msource eq '-' ) {
		$msource = $source || '';
	    } elsif ( $msource =~ s/^DEST:?// ) {
		$msource = merge_macro_source_dest $msource, $dest;
	    } else {
		$msource =~ s/^SOURCE:?//;
		$msource = merge_macro_source_dest $msource, $source;
	    }
	} else {
	    $msource = '';
	}

	if ( $mdest ) {
	    if ( $mdest eq '-' ) {
		$mdest = $dest || '';
	    } elsif ( $mdest =~ s/^SOURCE:?// ) {
		$mdest = merge_macro_source_dest $mdest , $source;
	    } else {
		$mdest =~ s/DEST:?//;
		$mdest = merge_macro_source_dest $mdest, $dest;
	    }
	} else {
	    $mdest = '';
	}

	$generated |= process_rule1(
				    $chainref,
				    $mtarget,
				    $param,
				    $msource,
				    $mdest,
				    merge_macro_column( $mproto,     $proto ) ,
				    merge_macro_column( $mports,     $ports ) ,
				    merge_macro_column( $msports,    $sports ) ,
				    merge_macro_column( $morigdest,  $origdest ) ,
				    merge_macro_column( $mrate,      $rate ) ,
				    merge_macro_column( $muser,      $user ) ,
				    merge_macro_column( $mmark,      $mark ) ,
				    merge_macro_column( $mconnlimit, $connlimit) ,
				    merge_macro_column( $mtime,      $time ),
				    merge_macro_column( $mheaders,   $headers ),
				    $wildcard
				   );

	progress_message "   Rule \"$currentline\" $done";
    }

    pop_open;

    progress_message "..End Macro $macrofile";

    clear_comment unless $nocomment;

    return $generated;
}

#
# Once a rule has been expanded via wildcards (source and/or dest zone eq 'all'), it is processed by this function. If
# the target is a macro, the macro is expanded and this function is called recursively for each rule in the expansion.
# Similarly, if a new action tuple is encountered, this function is called recursively for each rule in the action 
# body. In this latter case, a reference to the tuple's chain is passed in the first ($chainref) argument.
#
sub process_rule1 ( $$$$$$$$$$$$$$$$ ) {
    my ( $chainref,   #reference to Action Chain if we are being called from process_action(); undef otherwise
	 $target, 
	 $current_param,
	 $source,
	 $dest,
	 $proto,
	 $ports,
	 $sports,
	 $origdest,
	 $ratelimit,
	 $user,
	 $mark,
	 $connlimit,
	 $time,
	 $headers,
	 $wildcard ) = @_;

    my ( $action, $loglevel) = split_action $target;
    my ( $basictarget, $param ) = get_target_param $action;
    my $rule = '';
    my $optimize = $wildcard ? ( $basictarget =~ /!$/ ? 0 : $config{OPTIMIZE} & 1 ) : 0;
    my $inaction = '';
    my $normalized_target;
    my $normalized_action;
 
    ( $inaction, undef, undef, undef ) = split /:/, $normalized_action = $chainref->{action}, 4 if defined $chainref;

    $param = '' unless defined $param;

    #
    # Determine the validity of the action
    #
    my $actiontype = $targets{$basictarget} || find_macro ( $basictarget );

    if ( $config{ MAPOLDACTIONS } ) {
	( $basictarget, $actiontype , $param ) = map_old_actions( $basictarget ) unless $actiontype || $param;
    }

    fatal_error "Unknown ACTION ($action)" unless $actiontype;

    if ( $actiontype == MACRO ) {
	#
	# process_macro() will call process_rule1() recursively for each rule in the macro body
	#
	fatal_error "Macro invocations nested too deeply" if ++$macro_nest_level > MAX_MACRO_NEST_LEVEL;

	if ( $param ne '' ) {
	    $current_param = $param unless $param eq 'PARAM';
	}

	my $generated = process_macro( $basictarget,
				       $chainref,
				       $target,
				       $current_param,
				       $source,
				       $dest,
				       $proto,
				       $ports,
				       $sports,
				       $origdest,
				       $ratelimit,
				       $user,
				       $mark,
				       $connlimit,
				       $time,
				       $headers,
				       $wildcard );

	$macro_nest_level--;

	return $generated;

    } elsif ( $actiontype & NFQ ) {
	require_capability( 'NFQUEUE_TARGET', 'NFQUEUE Rules', '' );
	my $paramval = $param eq '' ? 0 : numeric_value( $param );
	fatal_error "Invalid value ($param) for NFQUEUE queue number" unless defined($paramval) && $paramval <= 65535;
	$action = "NFQUEUE --queue-num $paramval";
    } elsif ( $actiontype & SET ) {
	require_capability( 'IPSET_MATCH', 'SET and UNSET rules', '' );
	fatal_error "$action rules require a set name parameter" unless $param;
    } elsif ( $actiontype & ACTION ) {
	split_list $param, 'Action parameter';
    } else {
	fatal_error "The $basictarget TARGET does not accept a parameter" unless $param eq '';
    }

    #
    # We can now dispense with the postfix character
    #
    $action =~ s/[\+\-!]$//;
    #
    # Handle actions
    #
    if ( $actiontype & ACTION ) {
	#
	# Create the action:level:tag:param tuple.
	#
	$normalized_target = normalize_action( $basictarget, $loglevel, $param );

	fatal_error( "Action $basictarget invoked Recursively (" .  join( '->', map( externalize( $_ ), @actionstack , $normalized_target ) ) . ')' ) if $active{$normalized_target};

	if ( my $ref = use_action( $normalized_target ) ) {
	    #
	    # First reference to this tuple
	    #
	    process_action( $ref );
	    #
	    # Processing the action may determine that the action or one of it's dependents does NAT, so:
	    #
	    #    - Refresh $actiontype
	    #    - Create the associate nat table chain if appropriate.
	    #
	    ensure_chain( 'nat', $ref->{name} ) if ( $actiontype = $targets{$basictarget} ) & NATRULE;
	}

	$action = $basictarget; # Remove params, if any, from $action.
    } else {
	#
	# Catch empty parameter list
	#
	fatal_error "The $basictarget TARGET does not accept parameters" if $action =~ s/\(\)$//;
    }

    if ( $inaction ) {
	$targets{$inaction} |= NATRULE if $actiontype & (NATRULE | NONAT | NATONLY ) 
    }
    #
    # Take care of irregular syntax and targets
    #
    my $log_action = $action;

    unless ( $actiontype & ( ACTION | MACRO | NFQ | CHAIN ) ) {
	my $bt = $basictarget;

	$bt =~ s/[-+!]$//;

	my %functions = ( REDIRECT => sub () {
			      my $z = $actiontype & NATONLY ? '' : firewall_zone;
			      if ( $dest eq '-' ) {
				  $dest = $inaction ? '' : join( '', $z, '::' , $ports =~ /[:,]/ ? '' : $ports );
			      } elsif ( $inaction ) {
				  $dest = ":$dest";
			      } else {
				  $dest = join( '', $z, '::', $dest ) unless $dest =~ /^[^\d].*:/;
			      }
			  } ,
			  REJECT => sub { $action = 'reject'; } ,
			  CONTINUE => sub { $action = 'RETURN'; } ,
			  COUNT => sub { $action = ''; } ,
			  LOG => sub { fatal_error 'LOG requires a log level' unless defined $loglevel and $loglevel ne ''; } ,
		     );

	my $function = $functions{ $bt };

	if ( $function ) {
	    $function->();
	} elsif ( $actiontype & SET ) {
	    my %xlate = ( ADD => 'add-set' , DEL => 'del-set' );
	    
	    my ( $setname, $flags, $rest ) = split ':', $param, 3;
	    fatal_error "Invalid ADD/DEL parameter ($param)" if $rest;
	    fatal_error "Expected ipset name ($setname)" unless $setname =~ s/^\+// && $setname =~ /^[a-zA-Z]\w*$/;
	    fatal_error "Invalid flags ($flags)" unless defined $flags && $flags =~ /^(dst|src)(,(dst|src)){0,5}$/;
	    $action = join( ' ', 'SET --' . $xlate{$basictarget} , $setname , $flags );
	}
    }
    #
    # Isolate and validate source and destination zones
    #
    my $sourcezone = '-';
    my $destzone = '-';
    my $sourceref;
    my $destref;
    my $origdstports;

    unless ( $inaction ) {
	if ( $source =~ /^(.+?):(.*)/ ) {
	    fatal_error "Missing SOURCE Qualifier ($source)" if $2 eq '';
	    $sourcezone = $1;
	    $source = $2;
	} else {
	    $sourcezone = $source;
	    $source = ALLIP;
	}
   
	if ( $dest =~ /^(.*?):(.*)/ ) {
	    fatal_error "Missing DEST Qualifier ($dest)" if $2 eq '';
	    $destzone = $1;
	    $dest = $2;
	} elsif ( $dest =~ /.*\..*\./ ) {
	    #
	    # Appears to be an IPv4 address (no NAT in IPv6)
	    #
	    $destzone = '-';
	} else {
	    $destzone = $dest;
	    $dest = ALLIP;
	}

	fatal_error "Missing source zone" if $sourcezone eq '-' || $sourcezone =~ /^:/;
	fatal_error "Unknown source zone ($sourcezone)" unless $sourceref = defined_zone( $sourcezone );
    }

    if ( $actiontype & NATONLY ) {
	unless ( $destzone eq '-' || $destzone eq '' ) {
	    $destref = defined_zone( $destzone );

	    if ( $destref ) {
		warning_message "The destination zone ($destzone) is ignored in $log_action rules";
	    } else {
		$dest = join ':', $destzone, $dest;
		$destzone = '';
	    }
	}
    } else {
	unless ( $inaction ) {
	    fatal_error "Missing destination zone" if $destzone eq '-' || $destzone eq '';
	    fatal_error "Unknown destination zone ($destzone)" unless $destref = defined_zone( $destzone );
	}
    }

    my $restriction = NO_RESTRICT;

    unless ( $inaction ) {
	if ( $sourceref && ( $sourceref->{type} == FIREWALL || $sourceref->{type} == VSERVER ) ) {
	    $restriction = $destref && ( $destref->{type} == FIREWALL || $destref->{type} == VSERVER ) ? ALL_RESTRICT : OUTPUT_RESTRICT;
	} else {
	    $restriction = INPUT_RESTRICT if $destref && ( $destref->{type} == FIREWALL || $destref->{type} == VSERVER );
	}
    }

    #
    # For compatibility with older Shorewall versions
    #
    $origdest = ALLIP if $origdest eq 'all';

    #
    # Take care of chain
    #
    my ( $chain, $policy );

    if ( $inaction ) {
        #
        # We are generating rules in an action chain -- the chain name is the name of that action chain
        #
	$chain = $chainref->{name};
    } else { 
	unless ( $actiontype & NATONLY ) {
	    #
	    # Check for illegal bridge port rule
	    #
	    if ( $destref->{type} == BPORT ) {
		unless ( $sourceref->{bridge} eq $destref->{bridge} || single_interface( $sourcezone ) eq $destref->{bridge} ) {
		    return 0 if $wildcard;
		    fatal_error "Rules with a DESTINATION Bridge Port zone must have a SOURCE zone on the same bridge";
		}
	    }

	    $chain = rules_chain( ${sourcezone}, ${destzone} );
	    #
	    # Ensure that the chain exists but don't mark it as referenced until after optimization is checked
	    #
	    $chainref = ensure_chain 'filter', $chain;
	    $policy   = $chainref->{policy};

	    if ( $policy eq 'NONE' ) {
		return 0 if $wildcard;
		fatal_error "Rules may not override a NONE policy";
	    }
	    #
	    # Handle Optimization
	    #
	    if ( $optimize > 0 ) {
		my $loglevel = $filter_table->{$chainref->{policychain}}{loglevel};
		if ( $loglevel ne '' ) {
		    return 0 if $target eq "${policy}:$loglevel}";
		} else {
		    return 0 if $basictarget eq $policy;
		}
	    }
	    #
	    # Mark the chain as referenced and add appropriate rules from earlier sections.
	    #
	    $chainref = ensure_filter_chain $chain, 1;
	    #
	    # Don't let the rules in this chain be moved elsewhere
	    #
	    dont_move $chainref;
	}
    }
    #
    # Generate Fixed part of the rule
    #
    if ( $actiontype & ( NATRULE | NONAT ) && ! ( $actiontype & NATONLY ) ) {
	#
	# Either a DNAT, REDIRECT or ACCEPT+ rule or an Action with NAT;
	# don't apply rate limiting twice
	#
	$rule = join( '',
		      do_proto($proto, $ports, $sports),
		      do_user( $user ) ,
		      do_test( $mark , $globals{TC_MASK} ) ,
		      do_connlimit( $connlimit ),
		      do_time( $time ) );
    } else {
	$rule = join( '',
		      do_proto($proto, $ports, $sports),
		      do_ratelimit( $ratelimit, $basictarget ) ,
		      do_user( $user ) ,
		      do_test( $mark , $globals{TC_MASK} ) ,
		      do_connlimit( $connlimit ),
		      do_time( $time ) ,
		      do_headers( $headers )
		    );
    }

    unless ( $section eq 'NEW' || $inaction ) {
	fatal_error "Entries in the $section SECTION of the rules file not permitted with FASTACCEPT=Yes" if $config{FASTACCEPT};
	fatal_error "$basictarget rules are not allowed in the $section SECTION" if $actiontype & ( NATRULE | NONAT );
	$rule .= "$globals{STATEMATCH} $section "
    }

    #
    # Generate NAT rule(s), if any
    #
    if ( $actiontype & NATRULE ) {
	my ( $server, $serverport );
	my $randomize = $dest =~ s/:random$// ? ' --random' : '';

	require_capability( 'NAT_ENABLED' , "$basictarget rules", '' );
	#
	# Isolate server port
	#
	if ( $dest =~ /^(.*)(:(.+))$/ ) {
	    #
	    # Server IP and Port
	    #
	    $server = $1;      # May be empty
	    $serverport = $3;  # Not Empty due to RE
	    $origdstports = $ports;

	    if ( $origdstports && $origdstports ne '-' && port_count( $origdstports ) == 1 ) {
		$origdstports = validate_port( $proto, $origdstports );
	    } else {
		$origdstports = '';
	    }

	    if ( $serverport =~ /^(\d+)-(\d+)$/ ) {
		#
		# Server Port Range
		#
		fatal_error "Invalid port range ($serverport)" unless $1 < $2;
		my @ports = ( $1, $2 );
		$_ = validate_port( proto_name( $proto ), $_) for ( @ports );
		( $ports = $serverport ) =~ tr/-/:/;
	    } else {
		$serverport = $ports = validate_port( proto_name( $proto ), $serverport );
	    }
	} elsif ( $dest eq ':' ) {
	    #
	    # Rule with no server IP or port ( zone:: )
	    #
	    $server = $serverport = '';
	} else {
	    #
	    # Simple server IP address (may be empty or "-")
	    #
	    $server = $dest;
	    $serverport = '';
	}

	#
	# Generate the target
	#
	my $target = '';

	if ( $actiontype  & REDIRECT ) {
	    fatal_error "A server IP address ($server) may not be specified in a REDIRECT rule" if $server;
	    $target  = 'REDIRECT';
	    $target .= " --to-port $serverport" if $serverport;
	    if ( $origdest eq '' || $origdest eq '-' ) {
		$origdest = ALLIP;
	    } elsif ( $origdest eq 'detect' ) {
		fatal_error 'ORIGINAL DEST "detect" is invalid in an action' if $inaction;

		if ( $config{DETECT_DNAT_IPADDRS} && $sourcezone ne firewall_zone ) {
		    my $interfacesref = $sourceref->{interfaces};
		    my @interfaces = keys %$interfacesref;
		    $origdest = @interfaces ? "detect:@interfaces" : ALLIP;
 		} else {
		    $origdest = ALLIP;
		}
	    }
	} elsif ( $actiontype & ACTION ) {
	    fatal_error "A server port ($serverport) is not allowed in $action rule" if $serverport;
	    $target = $usedactions{$normalized_target}->{name};
	    $loglevel = '';
	} else {
	    if ( $server eq '' ) {
		fatal_error "A server and/or port must be specified in the DEST column in $action rules" unless $serverport;
	    } elsif ( $server =~ /^(.+)-(.+)$/ ) {
		validate_range( $1, $2 );
	    } else {
		unless ( ( $actiontype & ACTION ) && $server eq ALLIP ) {
		    my @servers = validate_address $server, 1;
		    $server = join ',', @servers;
		}
	    }

	    if ( $action eq 'DNAT' ) {
		$target = 'DNAT';
		if ( $server ) {
		    $serverport = ":$serverport" if $serverport;
		    for my $serv ( split /,/, $server ) {
			$target .= " --to-destination ${serv}${serverport}";
		    }
		} else {
		    $target .= " --to-destination :$serverport";
		}
	    }

	    unless ( $origdest && $origdest ne '-' && $origdest ne 'detect' ) {
		if ( ! $inaction && $config{DETECT_DNAT_IPADDRS} && $sourcezone ne firewall_zone ) {
		    my $interfacesref = $sourceref->{interfaces};
		    my @interfaces = keys %$interfacesref;
		    $origdest = @interfaces ? "detect:@interfaces" : ALLIP;
		} else {
		    $origdest = ALLIP;
		}
	    }
	}

	$target .= $randomize;

	#
	# And generate the nat table rule(s)
	#
	expand_rule ( ensure_chain ('nat' , $inaction ? $chain : $sourceref->{type} == FIREWALL ? 'OUTPUT' : dnat_chain $sourcezone ),
		      PREROUTE_RESTRICT ,
		      $rule ,
		      $source ,
		      $origdest ,
		      '' ,
		      $target ,
		      $loglevel ,
		      $log_action ,
		      $serverport ? do_proto( $proto, '', '' ) : '' );
	#
	# After NAT:
	#   - the destination port will be the server port ($ports) -- we did that above
	#   - the destination IP   will be the server IP   ($dest)
	#   - there will be no log level (we log NAT rules in the nat table rather than in the filter table).
	#   - the target will be ACCEPT.
	#
	unless ( $actiontype & NATONLY ) {
	    $rule = join( '',
			  do_proto( $proto, $ports, $sports ),
			  do_ratelimit( $ratelimit, 'ACCEPT' ),
			  do_user $user ,
			  do_test( $mark , $globals{TC_MASK} ) );
	    $loglevel = '';
	    $dest     = $server;
	    $action   = 'ACCEPT';
	}
    } elsif ( $actiontype & NONAT ) {
	#
	# NONAT or ACCEPT+ -- May not specify a destination interface
	#
	fatal_error "Invalid DEST ($dest) in $action rule" if $dest =~ /:/;

	$origdest = '' unless $origdest and $origdest ne '-';

	if ( $origdest eq 'detect' ) {
	    my $interfacesref = $sourceref->{interfaces};
	    my $interfaces = [ ( keys %$interfacesref ) ];
	    $origdest = $interfaces ? "detect:@$interfaces" : ALLIP;
	}

	my $tgt = 'RETURN';

	my $nonat_chain;

	my $chn;

	if ( $inaction ) {
	    $nonat_chain = ensure_chain 'nat', $chain;
	} elsif ( $sourceref->{type} == FIREWALL ) {
	    $nonat_chain = $nat_table->{OUTPUT};
	} else {
	    $nonat_chain = ensure_chain 'nat', dnat_chain $sourcezone;

	    my @interfaces = keys %{zone_interfaces $sourcezone};

	    for ( @interfaces ) {
		my $ichain = input_chain $_;

		if ( $nat_table->{$ichain} ) {
		    #
		    # Static NAT is defined on this interface
		    #
		    $chn = new_chain( 'nat', newnonatchain ) unless $chn;
		    add_jump $chn, $nat_table->{$ichain}, 0, @interfaces > 1 ? match_source_dev( $_ )  : '';
		}
	    }

	    if ( $chn ) {
		#
		# Call expand_rule() to correctly handle logging. Because
		# the 'logname' argument is passed, expand_rule() will
		# not create a separate logging chain but will rather emit
		# any logging rule in-line.
		#
		expand_rule( $chn,
			     PREROUTE_RESTRICT,
			     '', # Rule
			     '', # Source
			     '', # Dest
			     '', # Original dest
			     'ACCEPT',
			     $loglevel,
			     $log_action,
			     '',
			     dnat_chain( $sourcezone  ) );
		$loglevel = '';
		$tgt = $chn->{name};
	    } else {
		$tgt = 'ACCEPT';
	    }
	}

	expand_rule( $nonat_chain ,
		     PREROUTE_RESTRICT ,
		     $rule ,
		     $source ,
		     $dest ,
		     $origdest ,
		     $tgt,
		     $loglevel ,
		     $log_action ,
		     '' ,
		   );
	#
	# Possible optimization if the rule just generated was a simple jump to the nonat chain
	#
	if ( $chn && ${$nonat_chain->{rules}}[-1] eq "-A -j $tgt" ) {
	    #
	    # It was -- delete that rule
	    #
	    pop @{$nonat_chain->{rules}};
	    #
	    # And move the rules from the nonat chain to the zone dnat chain
	    #
	    move_rules ( $chn, $nonat_chain );
	}
    }

    #
    # Add filter table rule, unless this is a NATONLY rule type
    #
    unless ( $actiontype & NATONLY ) {

	if ( $actiontype & ACTION ) {
	    $action = $usedactions{$normalized_target}{name};
	    $loglevel = '';
	}

	if ( $origdest ) {
	    unless ( $origdest eq '-' ) {
		require_capability( 'CONNTRACK_MATCH', 'ORIGINAL DEST in a non-NAT rule', 's' ) unless $actiontype & NATRULE;
	    } else {
		$origdest = '';
	    }
	}

	$rule .= "-m conntrack --ctorigdstport $origdstports " if have_capability( 'NEW_CONNTRACK_MATCH' ) && $origdstports;

	expand_rule( ensure_chain( 'filter', $chain ) ,
		     $restriction ,
		     $rule ,
		     $source ,
		     $dest ,
		     $origdest ,
		     $action ,
		     $loglevel ,
		     $log_action ,
		     '' );
    }

    return 1;
}

#
# Helper functions for process_rule(). That function deals with the ugliness of wildcard zones ('all' and 'any') and zone lists.
#
# Process a SECTION header
#
sub process_section ($) {
    my $sect = shift;
    #
    # read_a_line has already verified that there are exactly two tokens on the line
    #
    fatal_error "Invalid SECTION ($sect)" unless defined $sections{$sect};
    fatal_error "Duplicate or out of order SECTION $sect" if $sections{$sect};
    $sections{$sect} = 1;

    if ( $sect eq 'RELATED' ) {
	$sections{ESTABLISHED} = 1;
	finish_section 'ESTABLISHED';
    } elsif ( $sect eq 'NEW' ) {
	@sections{'ESTABLISHED','RELATED'} = ( 1, 1 );
	finish_section ( ( $section eq 'RELATED' ) ? 'RELATED' : 'ESTABLISHED,RELATED' );
    }

    $section = $sect;
}

#
# Build a source or destination zone list
#
sub build_zone_list( $$$\$\$ ) {
    my ($fw, $input, $which, $intrazoneref, $wildref ) = @_;
    my $any = ( $input =~ s/^any/all/ );
    my $exclude;
    my $rest;
    my %exclude;
    my @result;
    #
    # Handle Wildcards
    #
    if ( $input =~ /^(all[-+]*)(![^:]+)?(:.*)?/ ) {
	$input   = $1;
	$exclude = $2;
	$rest    = $3;

	$$wildref = 1;

	if ( defined $exclude ) {
	    $exclude =~ s/!//;
	    fatal_error "Invalid exclusion list (!$exclude)" if $exclude =~ /^,|!|,,|,$/;
	    for ( split /,/, $exclude ) {
		fatal_error "Unknown zone ($_)" unless defined_zone $_;
		$exclude{$_} = 1;
	    }
	}

	unless ( $input eq 'all' ) {
	    if ( $input eq 'all+' ) {
		$$intrazoneref = 1;
	    } elsif ( ( $input eq 'all+-' ) || ( $input eq 'all-+' ) ) {
		$$intrazoneref = 1;
		$exclude{$fw} = 1;
	    } elsif ( $input eq 'all-' ) {
		$exclude{$fw} = 1;
	    } else {
		fatal_error "Invalid $which ($input)";
	    }
	}

	@result = grep ! $exclude{$_}, $any ? all_parent_zones : non_firewall_zones;

	unshift @result, $fw unless $exclude{$fw};

    } elsif ( $input =~ /^([^:]+,[^:]+)(:.*)?$/ ) {
	$input    = $1;
	$rest     = $2;
	$$wildref = 1;

	$$intrazoneref = ( $input =~ s/\+$// );

	@result = split_list $input, 'zone';
    } else {
	@result = ( $input );
    }

    if ( defined $rest ) {
	$_ .= $rest for @result;
    }

    @result;
}

#
# Process a Record in the rules file
#
sub process_rule ( ) {
    my ( $target, $source, $dest, $proto, $ports, $sports, $origdest, $ratelimit, $user, $mark, $connlimit, $time, $headers ) = split_line1 1, 13, 'rules file', $rule_commands;

    process_comment,            return 1 if $target eq 'COMMENT';
    process_section( $source ), return 1 if $target eq 'SECTION';
    #
    # Section Names are optional so once we get to an actual rule, we need to be sure that
    # we close off any missing sections.
    #
    process_section( 'NEW' ) unless $section;

    if ( $source =~ /^none(:.*)?$/i || $dest =~ /^none(:.*)?$/i ) {
	progress_message "Rule \"$currentline\" ignored.";
	return 1;
    }

    my $intrazone = 0;
    my $wild      = 0;
    my $thisline  = $currentline; #We must save $currentline because it is overwritten by macro expansion
    my $action    = isolate_basic_target $target;
    my $fw        = firewall_zone;
    my @source    = build_zone_list ( $fw, $source, 'SOURCE', $intrazone, $wild );
    my @dest      = build_zone_list ( $fw, $dest,   'DEST'  , $intrazone, $wild );
    my $generated = 0;

    fatal_error "Invalid or missing ACTION ($target)" unless defined $action;

    for $source ( @source ) {
	for $dest ( @dest ) {
	    my $sourcezone = (split( /:/, $source, 2 ) )[0];
	    my $destzone   = (split( /:/, $dest,   2 ) )[0];
	    $destzone = $action =~ /^REDIRECT/ ? $fw : '' unless defined_zone $destzone;
	    if ( ! $wild || $intrazone || ( $sourcezone ne $destzone ) ) {
		$generated |= process_rule1( undef,
					     $target,
					     '',
					     $source,
					     $dest,
					     $proto,
					     $ports,
					     $sports,
					     $origdest,
					     $ratelimit,
					     $user,
					     $mark,
					     $connlimit,
					     $time,
					     $headers,
					     $wild );
	    }
	}
    }

    warning_message  qq(Entry generated no $toolname rules) unless $generated;

    progress_message qq(   Rule "$thisline" $done);
}

#
# Process the Rules File
#
sub process_rules() {

    my $fn = open_file 'rules';

    if ( $fn ) {

	first_entry "$doing $fn...";

	process_rule while read_a_line;

	clear_comment;
    }

    $section = 'DONE';
}

1;
