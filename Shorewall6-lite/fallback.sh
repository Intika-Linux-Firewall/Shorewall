#!/bin/sh
#
# Script to back out the installation of Shorewall Lite and to restore the previous version of
# the program
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2006,2007 - Tom Eastep (teastep@shorewall.net)
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
#    Usage:
#
#       You may only use this script to back out the installation of the version
#       shown below. Simply run this script to revert to your prior version of
#       Shoreline Firewall.

VERSION=4.4.3

usage() # $1 = exit status
{
    echo "usage: $(basename $0)"
    exit $1
}

restore_directory() # $1 = directory to restore
{
    if [ -d ${1}-${VERSION}.bkout ]; then
	if mv -f $1 ${1}-${VERSION} && mv ${1}-${VERSION}.bkout $1; then
	    echo
	    echo "$1 restored"
	    rm -rf ${1}-${VERSION}
	else
	    echo "ERROR: Could not restore $1"
	    exit 1
	fi
    fi
}

restore_file() # $1 = file to restore, $2 = (Optional) Directory to restore from
{
    if [ -n "$2" ]; then
	local file
	file=$(basename $1)

	if [ -f $2/$file ]; then
	    if mv -f $2/$file $1 ; then
		echo
		echo "$1 restored"
		return
	    fi

	    echo "ERROR: Could not restore $1"
	    exit 1
        fi
    fi

    if [ -f ${1}-${VERSION}.bkout -o -L ${1}-${VERSION}.bkout ]; then
	if (mv -f ${1}-${VERSION}.bkout $1); then
	    echo
	    echo "$1 restored"
        else
	    echo "ERROR: Could not restore $1"
	    exit 1
        fi
    fi
}

if [ ! -f /usr/share/shorewall-lite-${VERSION}.bkout/version ]; then
    echo "Shorewall Version $VERSION is not installed"
    exit 1
fi

echo "Backing Out Installation of Shorewall $VERSION"

if [ -L /usr/share/shorewall-lite/init ]; then
    FIREWALL=$(ls -l /usr/share/shorewall-lite/init | sed 's/^.*> //')
    restore_file $FIREWALL /usr/share/shorewall-lite-${VERSION}.bkout
else
    restore_file /etc/init.d/shorewall /usr/share/shorewall-lite-${VERSION}.bkout
fi

restore_file /sbin/shorewall /var/lib/shorewall-lite-${VERSION}.bkout

restore_directory /etc/shorewall-lite
restore_directory /usr/share/shorewall-lite
restore_directory /var/lib/shorewall-lite

echo "Shorewall Lite Restored to Version $(cat /usr/share/shorewall-lite/version)"


