#!/bin/sh
#
#     The Shoreline Firewall (Shorewall) Packet Filtering Firewall - V4.5
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 1999,2000,2001,2002,2003,2004,2005,2006,2007,2012 - Tom Eastep (teastep@shorewall.net)
#
#	On most distributions, this file should be called /etc/init.d/shorewall.
#
#	Complete documentation is available at http://shorewall.net
#
#	This program is free software; you can redistribute it and/or modify
#	it under the terms of Version 2 of the GNU General Public License
#	as published by the Free Software Foundation.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program; if not, write to the Free Software
#	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
#	If an error occurs while starting or restarting the firewall, the
#	firewall is automatically stopped.
#
#	Commands are:
#
#	   shorewall start			  Starts the firewall
#	   shorewall restart			  Restarts the firewall
#	   shorewall reload			  Reload the firewall
#						  (same as restart)
#	   shorewall stop			  Stops the firewall
#	   shorewall status			  Displays firewall status
#


### BEGIN INIT INFO
# Provides:	  shorewall-lite
# Required-Start: $network $remote_fs
# Required-Stop:  
# Default-Start:  2 3 5
# Default-Stop:	  0 1 6
# Description:	  starts and stops the shorewall firewall
# Short-Description: Packet filtering firewall
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

if [ -f ${SYSCONFDIR}/shorewall-lite ]; then
    . ${SYSCONFDIR}/shorewall-lite
fi

SHOREWALL_INIT_SCRIPT=1

################################################################################
# E X E C U T I O N    B E G I N S   H E R E				       #
################################################################################
command="$1"

case "$command" in
    start)
	exec ${SBINDIR}/shorewall-lite $OPTIONS start $STARTOPTIONS
	;;
    restart|reload)
	exec ${SBINDIR}/shorewall-lite $OPTIONS restart $RESTARTOPTIONS
	;;
    status|stop)
	exec ${SBINDIR}/shorewall-lite $OPTIONS $command $@
	;;
    *)
	usage
	;;
esac
