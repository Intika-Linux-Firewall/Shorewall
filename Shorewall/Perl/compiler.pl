#! /usr/bin/perl -w
#
#     The Shoreline Firewall Packet Filtering Firewall Compiler
#
#     (c) 2007,2008,2009,2010,2011,2014 - Tom Eastep (teastep@shorewall.net)
#
#	Complete documentation is available at http://shorewall.net
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
# Usage:
#
#         compiler.pl [ <option> ... ] [ <filename> ]
#
#     Options:
#
#         --export                    # Compile for export
#         --verbosity=<number>        # Set VERBOSITY range -1 to 2
#         --directory=<directory>     # Directory where configuration resides (default is /etc/shorewall)
#         --timestamp                 # Timestamp all progress messages
#         --debug                     # Print stack trace on warnings and fatal error.
#         --log=<filename>            # Log file
#         --log_verbosity=<number>    # Log Verbosity range -1 to 2
#         --test                      # Used by the regression library to omit versions and time/dates
#                                     # from the generated script
#         --family=<number>           # IP family; 4 = IPv4 (default), 6 = IPv6
#         --preview                   # Preview the ruleset.
#         --shorewallrc=<path>        # Path to global shorewallrc file.
#         --shorewallrc1=<path>       # Path to export shorewallrc file.
#         --config_path=<path-list>   # Search path for config files
#         --update                    # Update configuration to current release
#
#    If the <filename> is omitted, then a 'check' operation is performed.
#
use strict;
use FindBin;
use lib "$FindBin::Bin";
use Shorewall::Compiler;
use Getopt::Long;

sub usage( $ ) {

    print STDERR << '_EOF_';

usage: compiler.pl [ <option> ... ] [ <filename> ]

  options are:
    [ --export ]
    [ --directory=<directory> ]
    [ --verbose={-1|0-2} ]
    [ --timestamp ]
    [ --debug ]
    [ --confess ]
    [ --log=<filename> ]
    [ --log-verbose={-1|0-2} ]
    [ --test ]
    [ --preview ]
    [ --family={4|6} ]
    [ --annotate ]
    [ --update ]
    [ --shorewallrc=<pathname> ]
    [ --shorewallrc1=<pathname> ]
    [ --config_path=<path-list> ]
_EOF_

exit shift @_;
}

#
#                                     E x e c u t i o n   B e g i n s   H e r e
#
my $export        = 0;
my $shorewall_dir = '';
my $verbose       = 0;
my $timestamp     = 0;
my $debug         = 0;
my $confess       = 0;
my $log           = '';
my $log_verbose   = 0;
my $help          = 0;
my $test          = 0;
my $family        = 4; # F_IPV4
my $preview       = 0;
my $annotate      = 0;
my $update        = 0;
my $config_path   = '';
my $shorewallrc   = '';
my $shorewallrc1  = '';

Getopt::Long::Configure ('bundling');

my $result = GetOptions('h'               => \$help,
                        'help'            => \$help,
                        'export'          => \$export,
			'e'               => \$export,
			'directory=s'     => \$shorewall_dir,
			'd=s'             => \$shorewall_dir,
			'verbose=i'       => \$verbose,
			'v=i'             => \$verbose,
			'timestamp'       => \$timestamp,
			't'               => \$timestamp,
		        'debug'           => \$debug,
			'log=s'           => \$log,
			'l=s'             => \$log,
			'log_verbosity=i' => \$log_verbose,
			'test'            => \$test,
			'preview'         => \$preview,
			'f=i'             => \$family,
			'family=i'        => \$family,
			'c'               => \$confess,
			'confess'         => \$confess,
			'a'               => \$annotate,
			'annotate'        => \$annotate,
			'u'               => \$update,
			'update'          => \$update,
			'config_path=s'   => \$config_path,
			'shorewallrc=s'   => \$shorewallrc,
			'shorewallrc1=s'  => \$shorewallrc1,
		       );

usage(1) unless $result && @ARGV < 2;
usage(0) if $help;

compiler( script          => $ARGV[0] || '',
	  directory       => $shorewall_dir,
	  verbosity       => $verbose,
	  timestamp       => $timestamp,
	  debug           => $debug,
	  export          => $export,
	  log             => $log,
	  log_verbosity   => $log_verbose,
	  test            => $test,
	  preview         => $preview,
	  family          => $family,
	  confess         => $confess,
	  update          => $update,
	  annotate        => $annotate,
	  config_path     => $config_path,
	  shorewallrc     => $shorewallrc,
	  shorewallrc1    => $shorewallrc1,
	);
