#!/bin/sh
#
# ifupdown script for Shorewall-based products
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2010 - Tom Eastep (teastep@shorewall.net)
#
#       Shorewall documentation is available at http://shorewall.net
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

IFUPDOWN=0
PRODUCTS=

if [ -f /etc/default/shorewall-init ]; then
    . /etc/default/shorewall-init
elif [ -f /etc/sysconfig/shorewall-init ]; then
    . /etc/sysconfig/shorewall-init
fi

[ "$IFUPDOWN" = 1 -a -n "$PRODUCTS" ] || exit 0

if [ -f /etc/debian_version ]; then
    #
    # Debian ifupdown system
    #
    if [ "$MODE" = start ]; then
	COMMAND=up
    elif [ "$MODE" = stop ]; then
	COMMAND=down
    else
	exit 0
    fi

    case "$PHASE" in
	pre-*)
	    exit 0
	    ;;
    esac
elif [ -f /etc/SuSE-release ]; then
    #
    # SuSE ifupdown system
    #
    IFACE="$2"

    case $0 in
	*if-up.d*)
	    COMMAND=up
	    ;;
	*if-down.d*)
	    COMMAND=down
	    ;;
	*)
	    exit 0
	    ;;
    esac
else
    #
    # Assume RedHat/Fedora/CentOS/Foobar/...
    #
    IFACE="$1"
    
    case $0 in 
	*ifup*)
	    COMMAND=up
	    ;;
	*ifdown*)
	    COMMAND=down
	    ;;
	*dispatcher.d*)
	    COMMAND="$2"
	    ;;
	*)
	    exit 0
	    ;;
    esac
fi

for PRODUCT in $PRODUCTS; do
    VARDIR=/var/lib/$PRODUCT
    [ -f /etc/$PRODUCT/vardir ] && . /etc/$PRODUCT/vardir
    if [ -x $VARDIR/firewall ]; then
	  ( . /usr/share/$PRODUCT/lib.base
	    mutex_on
	    ${VARDIR}/firewall -V0 $COMMAND $IFACE || echo_notdone
	    mutex_off
	  )
    fi
done

exit 0
