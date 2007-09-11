#
# Shorewall-perl 4.0 -- /usr/share/shorewall-perl/Shorewall/Accounting.pm
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
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
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#   This module contains the code that handles the /etc/shorewall/accounting
#   file.
#
package Shorewall::Accounting;
require Exporter;
use Shorewall::Config;
use Shorewall::IPAddrs;
use Shorewall::Zones;
use Shorewall::Chains;

use strict;

our @ISA = qw(Exporter);
our @EXPORT = qw( setup_accounting );
our @EXPORT_OK = qw( );
our $VERSION = '4.03';

#
# Initialize globals -- we take this novel approach to globals initialization to allow
#                       the compiler to run multiple times in the same process. The
#                       initialize() function does globals initialization for this
#                       module and is called from an INIT block below. The function is
#                       also called by Shorewall::Compiler::compiler at the beginning of
#                       the second and subsequent calls to that function.
#

sub initialize() {
    our $jumpchainref;
    $jumpchainref = undef;
}

INIT {
    initialize;
}

#
# Accounting
#
sub process_accounting_rule( $$$$$$$$$ ) {

    our $jumpchainref;

    my ($action, $chain, $source, $dest, $proto, $ports, $sports, $user, $mark ) = @_;

    sub check_for_builtin( $ ) {
	my $chainref = shift;
	fatal_error "A builtin Chain ($jumpchainref->{name}) may not appear in the accounting file" if $chainref->{builtin};
    }

    sub accounting_error() {
	fatal_error "Invalid Accounting rule";
    }

    sub jump_to_chain( $ ) {
	my $jumpchain = $_[0];
	$jumpchainref = ensure_chain( 'filter', $jumpchain );
	check_for_builtin( $jumpchainref );
	mark_referenced $jumpchainref;
	"-j $jumpchain";
    }

    my $target = '';

    $proto  = ''    if $proto  eq 'any';
    $ports  = ''    if $ports  eq 'any' || $ports  eq 'all';
    $sports = ''    if $sports eq 'any' || $sports eq 'all';

    my $rule = do_proto( $proto, $ports, $sports ) . do_user ( $user ) . do_test ( $mark, 0xFF );
    my $rule2 = 0;

    unless ( $action eq 'COUNT' ) {
	if ( $action eq 'DONE' ) {
	    $target = '-j RETURN';
	} else {
	    ( $action, my $cmd ) = split /:/, $action;
	    if ( $cmd ) {
		if ( $cmd eq 'COUNT' ) {
		    $rule2=1;
		    $target = jump_to_chain $action;
		} elsif ( $cmd ne 'JUMP' ) {
		    accounting_error;
		}
	    } else {
		$target = jump_to_chain $action;
	    }
	}
    }

    my $restriction = NO_RESTRICT;

    $source = ALLIPv4 if $source eq 'any' || $source eq 'all';

    if ( have_bridges ) {
	my $fw = firewall_zone;

	if ( $source =~ /^$fw:?(.*)$/ ) {
	    $source = $1 ? $1 : ALLIPv4;
	    $restriction = OUTPUT_RESTRICT;
	    $chain = 'accountout' unless $chain and $chain ne '-';
	    $dest = ALLIPv4 if $dest   eq 'any' || $dest   eq 'all';
	} else {
	    $chain = 'accounting' unless $chain and $chain ne '-';
	    if ( $dest eq 'any' || $dest eq 'all' || $dest eq ALLIPv4 ) {
		expand_rule(
			    ensure_filter_chain( 'accountout' , 0 ) ,
			    OUTPUT_RESTRICT ,
			    $rule ,
			    $source ,
			    $dest = ALLIPv4 ,
			    '' ,
			    $target ,
			    '' ,
			    '' ,
			    ''  );
	    }
	}
    } else {
	$chain = 'accounting' unless $chain and $chain ne '-';
	$dest = ALLIPv4 if $dest   eq 'any' || $dest   eq 'all';
    }

    my $chainref = ensure_filter_chain $chain , 0;

    check_for_builtin( $chainref );
    
    expand_rule
	$chainref ,
	$restriction ,
	$rule ,
	$source ,
	$dest ,
	'' ,
	$target ,
	'' ,
	'' ,
	'' ;

    if ( $rule2 ) {
	expand_rule
	    $jumpchainref ,
	    $restriction ,
	    $rule ,
	    $source ,
	    $dest ,
	    '' ,
	    '' ,
	    '' ,
	    '' ,
	    '' ;
    }
}

sub setup_accounting() {

    my $first_entry = 1;

    my $fn = open_file 'accounting';

    while ( read_a_line ) {

	my ( $action, $chain, $source, $dest, $proto, $ports, $sports, $user, $mark ) = split_line1 1, 9, 'Accounting File';

	if ( $first_entry ) {
	    progress_message2 "$doing $fn...";
	    $first_entry = 0;
	}

	if ( $action eq 'COMMENT' ) {
	    process_comment;
	} else {
	    process_accounting_rule $action, $chain, $source, $dest, $proto, $ports, $sports, $user, $mark;
	}
    }

    clear_comment;

    if ( have_bridges ) {
	if ( $filter_table->{4}->{accounting} ) {
	    for my $chain ( qw/INPUT FORWARD/ ) {
		insert_rule $filter_table->{4}{$chain}, 1, '-j accounting';
	    }
	}

	if ( $filter_table->{4}->{accountout} ) {
	    insert_rule $filter_table->{4}{OUTPUT}, 1, '-j accountout';
	}
    } else {
	if ( $filter_table->{4}->{accounting} ) {
	    for my $chain ( qw/INPUT FORWARD OUTPUT/ ) {
		insert_rule $filter_table->{4}{$chain}, 1, '-j accounting';
	    }
	}
    }
}

1;
