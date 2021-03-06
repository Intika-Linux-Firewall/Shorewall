#!/bin/sh
RCDLINKS="2,S41 3,S41 6,K41"
#
#     The Shoreline Firewall (Shorewall) Packet Filtering Firewall - V5.2
#
#     (c) 1999,2000,2001,2002,2003,2004,2005,2006,2007,2012,2014 - Tom Eastep (teastep@shorewall.net)
#
#	On most distributions, this file should be called /etc/init.d/shorewall.
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
#	If an error occurs while starting or restarting the firewall, the
#	firewall is automatically stopped.
#
#	Commands are:
#
#	   shorewall6-lite start			  Starts the firewall
#	   shorewall6-lite restart			  Restarts the firewall
#	   shorewall6-lite reload			  Reload the firewall
#						          (same as restart)
#	   shorewall6-lite stop 			  Stops the firewall
#	   shorewall6-lite status			  Displays firewall status
#

# chkconfig: 2345 25 90
# description: Packet filtering firewall

### BEGIN INIT INFO
# Provides:	  shorewall6-lite
# Required-Start: $network
# Required-Stop:
# Default-Start:  2 3 5
# Default-Stop:	  0 1 6
# Description:	  starts and stops the shorewall firewall
### END INIT INFO

################################################################################
# Give Usage Information						       #
################################################################################
usage() {
    echo "Usage: $0 start|stop|reload|restart|status"
    exit 1
}

################################################################################
# Get startup options (override default)
################################################################################
OPTIONS=

#
# The installer may alter this
#
. /usr/share/shorewall/shorewallrc

export SHOREWALL_INIT_SCRIPT=1

################################################################################
# E X E C U T I O N    B E G I N S   H E R E				       #
################################################################################
command="$1"

case "$command" in
    start)
	exec ${SBINDIR}/shorewall -6l $OPTIONS start $STARTOPTIONS
	;;
    restart|reload)
	exec ${SBINDIR}/shorewall -6l $OPTIONS restart $RESTARTOPTIONS
	;;
    status|stop)
	exec ${SBINDIR}/shorewall -6l $OPTIONS $command $@
	;;
    *)
	usage
	;;
esac
