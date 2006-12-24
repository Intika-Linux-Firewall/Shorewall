#!/bin/sh
#
# Script to install Shoreline Firewall Lite
#
#     This program is under GPL [http://www.gnu.org/copyleft/gpl.htm]
#
#     (c) 2000,2001,2002,2003,2004,2005 - Tom Eastep (teastep@shorewall.net)
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
#       Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA
#

VERSION=3.4.0-Beta1

usage() # $1 = exit status
{
    ME=$(basename $0)
    echo "usage: $ME"
    echo "       $ME -v"
    echo "       $ME -h"
    echo "       $ME -n"
    exit $1
}

split() {
    local ifs=$IFS
    IFS=:
    set -- $1
    echo $*
    IFS=$ifs
}

qt()
{
    "$@" >/dev/null 2>&1
}

mywhich() {
    local dir

    for dir in $(split $PATH); do
	if [ -x $dir/$1 ]; then
	    echo $dir/$1
	    return 0
	fi
    done

    return 2
}

run_install()
{
    if ! install $*; then
	echo
	echo "ERROR: Failed to install $*" >&2
	exit 1
    fi
}

cant_autostart()
{
    echo
    echo  "WARNING: Unable to configure shorewall to start automatically at boot" >&2
}

backup_directory() # $1 = directory to backup
{
    if [ -d $1 ]; then
	if cp -a $1  ${1}-${VERSION}.bkout ; then
	    echo
	    echo "$1 saved to ${1}-${VERSION}.bkout"
	else
	    exit 1
	fi
    fi
}

backup_file() # $1 = file to backup, $2 = (optional) Directory in which to create the backup
{
    if [ -z "${PREFIX}${NOBACKUP}" ]; then
	if [ -f $1 -a ! -f ${1}-${VERSION}.bkout ]; then
	    if [ -n "$2" ]; then
		if [ -d $2 ]; then
		    if cp -f $1 $2 ; then
			echo
			echo "$1 saved to $2/$(basename $1)"
		    else
			exit 1
		    fi
		fi
	    elif cp $1 ${1}-${VERSION}.bkout; then
		echo
		echo "$1 saved to ${1}-${VERSION}.bkout"
	    else
		exit 1
	    fi
	fi
    fi
}

delete_file() # $1 = file to delete
{
    rm -f $1
}

install_file() # $1 = source $2 = target $3 = mode
{
    run_install $OWNERSHIP -m $3 $1 ${2}
}

install_file_with_backup() # $1 = source $2 = target $3 = mode $4 = (optional) backup directory
{
    backup_file $2 $4
    run_install $OWNERSHIP -m $3 $1 ${2}
}

#
# Parse the run line
#
# DEST is the SysVInit script directory
# INIT is the name of the script in the $DEST directory
# RUNLEVELS is the chkconfig parmeters for firewall
# ARGS is "yes" if we've already parsed an argument
#
ARGS=""

if [ -z "$DEST" ] ; then
	DEST="/etc/init.d"
fi

if [ -z "$INIT" ] ; then
	INIT="shorewall-lite"
fi

if [ -z "$RUNLEVELS" ] ; then
	RUNLEVELS=""
fi

if [ -z "$OWNER" ] ; then
	OWNER=root
fi

if [ -z "$GROUP" ] ; then
	GROUP=root
fi

NOBACKUP=

while [ $# -gt 0 ] ; do
    case "$1" in
	-h|help|?)
	    usage 0
	    ;;
        -v)
	    echo "Shorewall Lite Firewall Installer Version $VERSION"
	    exit 0
	    ;;
	-n)
	    NOBACKUP=Yes
	    ;;
	*)
	    usage 1
	    ;;
    esac
    shift
    ARGS="yes"
done

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin:/usr/local/sbin

#
# Determine where to install the firewall script
#
DEBIAN=

OWNERSHIP="-o $OWNER -g $GROUP"

if [ -n "$PREFIX" ]; then
	if [ `id -u` != 0 ] ; then
	    echo "Not setting file owner/group permissions, not running as root."
	    OWNERSHIP=""
	fi

	install -d $OWNERSHIP -m 755 ${PREFIX}/sbin
	install -d $OWNERSHIP -m 755 ${PREFIX}${DEST}
elif [ -d /etc/apt -a -e /usr/bin/dpkg ]; then
    DEBIAN=yes
elif [ -f /etc/slackware-version ] ; then
    DEST="/etc/rc.d"
    INIT="rc.firewall"
elif [ -f /etc/arch-release ] ; then
      DEST="/etc/rc.d"
      INIT="shorewall-lite"
      ARCHLINUX=yes
fi

#
# Change to the directory containing this script
#
cd "$(dirname $0)"

echo "Installing Shorewall Lite Version $VERSION"

#
# First do Backups
#

#
# Check for /etc/shorewall-lite
#
if [ -z "$PREFIX" -a -d /etc/shorewall-lite ]; then
    first_install=""
    if [ -z "$NOBACKUP" ]; then
	backup_directory /etc/shorewall-lite
	backup_directory /usr/share/shorewall-lite
	backup_directory /var/lib/shorewall-lite
    fi
else
    first_install="Yes"
    rm -rf ${PREFIX}/etc/shorewall-lite
    rm -rf ${PREFIX}/usr/share/shorewall-lite
    rm -rf ${PREFIX}/var/lib/shorewall-lite
fi

delete_file ${PREFIX}/usr/share/shorewall-lite/xmodules

install_file_with_backup shorewall-lite ${PREFIX}/sbin/shorewall-lite 0544 ${PREFIX}/var/lib/shorewall-lite-${VERSION}.bkout

echo "Shorewall Lite control program installed in ${PREFIX}/sbin/shorewall-lite"

#
# Install the Firewall Script
#
if [ -n "$DEBIAN" ]; then
    install_file_with_backup init.debian.sh /etc/init.d/shorewall-lite 0544 ${PREFIX}/usr/share/shorewall-lite-${VERSION}.bkout
elif [ -n "$ARCHLINUX" ]; then
    install_file_with_backup init.archlinux.sh ${PREFIX}${DEST}/$INIT 0544 ${PREFIX}/usr/share/shorewall-lite-${VERSION}.bkout

else
    install_file_with_backup init.sh ${PREFIX}${DEST}/$INIT 0544 ${PREFIX}/usr/share/shorewall-lite-${VERSION}.bkout
fi

echo  "Shorewall Lite script installed in ${PREFIX}${DEST}/$INIT"

#
# Create /etc/shorewall-lite, /usr/share/shorewall-lite and /var/lib/shorewall-lite if needed
#
mkdir -p ${PREFIX}/etc/shorewall-lite
mkdir -p ${PREFIX}/usr/share/shorewall-lite
mkdir -p ${PREFIX}/var/lib/shorewall-lite

chmod 755 ${PREFIX}/etc/shorewall-lite
chmod 755 ${PREFIX}/usr/share/shorewall-lite

#
# Install the config file
#
if [ ! -f ${PREFIX}/etc/shorewall-lite/shorewall.conf ]; then
   run_install $OWNERSHIP -m 0744 shorewall.conf ${PREFIX}/etc/shorewall-lite/shorewall.conf
   echo "Config file installed as ${PREFIX}/etc/shorewall-lite/shorewall.conf"
fi

if [ -n "$ARCHLINUX" ] ; then
   sed -e 's!LOGFILE=/var/log/messages!LOGFILE=/var/log/messages.log!' -i ${PREFIX}/etc/shorewall-lite/shorewall.conf
fi

#
# Install the  Makefile
#
run_install $OWNERSHIP -m 0600 Makefile ${PREFIX}/etc/shorewall-lite/Makefile
echo "Makefile installed as ${PREFIX}/etc/shorewall-lite/Makefile"

#
# Install the default config path file
#
install_file configpath ${PREFIX}/usr/share/shorewall-lite/configpath 0644
echo "Default config path file installed as ${PREFIX}/usr/share/shorewall-lite/configpath"

#
# Install the libraries
#
for f in lib.* ; do
    if [ -f $f ]; then
	install_file $f ${PREFIX}/usr/share/shorewall-lite/$f 0644
	echo "Library ${f#*.} file installed as ${PREFIX}/usr/share/shorewall-lite/$f"
    fi
done

ln -sf lib.base ${PREFIX}/usr/share/shorewall-lite/functions

echo "Common functions linked through ${PREFIX}/usr/share/shorewall-lite/functions"

#
# Install Shorecap
#

install_file shorecap ${PREFIX}/usr/share/shorewall-lite/shorecap 0555

echo
echo "Capability file builder installed in ${PREFIX}/usr/share/shorewall-lite/shorecap"

#
# Install the Modules file
#
run_install $OWNERSHIP -m 0600 modules ${PREFIX}/usr/share/shorewall-lite/modules
echo "Modules file installed as ${PREFIX}/usr/share/shorewall-lite/modules"

#
# Install the Man Pages
#

rm -f *.gz

cd manpages

for f in *.5; do
    gzip $f
    run_install -D -m 444 $f.gz ${PREFIX}/usr/share/man/man5/$f.gz
    echo "Man page $f.gz installed to /usr/share/man/man5/$f.gz"
done

for f in *.8; do
    gzip $f
    run_install -D -m 444 $f.gz ${PREFIX}/usr/share/man/man8/$f.gz
    echo "Man page $f.gz installed to /usr/share/man/man8/$f.gz"
done

cd ..

echo "Man Pages Installed"

#
# Create the version file
#
echo "$VERSION" > ${PREFIX}/usr/share/shorewall-lite/version
chmod 644 ${PREFIX}/usr/share/shorewall-lite/version
#
# Remove and create the symbolic link to the init script
#

if [ -z "$PREFIX" ]; then
    rm -f /usr/share/shorewall-lite/init
    ln -s ${DEST}/${INIT} /usr/share/shorewall-lite/init
fi

if [ -z "$PREFIX" -a -n "$first_install" ]; then
    if [ -n "$DEBIAN" ]; then
	run_install $OWNERSHIP -m 0644 default.debian /etc/default/shorewall-lite
	ln -s ../init.d/shorewall-lite /etc/rcS.d/S40shorewall-lite
	echo "Shorewall Lite will start automatically at boot"
	touch /var/log/shorewall-init.log
    else
	if [ -x /sbin/insserv -o -x /usr/sbin/insserv ]; then
	    if insserv /etc/init.d/shorewall-lite ; then
		echo "Shorewall Lite will start automatically at boot"
	    else
		cant_autostart
	    fi
	elif [ -x /sbin/chkconfig -o -x /usr/sbin/chkconfig ]; then
	    if chkconfig --add shorewall-lite ; then
		echo "Shorewall Lite will start automatically in run levels as follows:"
		chkconfig --list shorewall-lite
	    else
		cant_autostart
	    fi
	elif [ -x /sbin/rc-update ]; then
	    if rc-update add shorewall-lite default; then
		echo "Shorewall Lite will start automatically at boot"
	    else
		cant_autostart
	    fi
	elif [ "$INIT" != rc.firewall ]; then #Slackware starts this automatically
	    cant_autostart
	fi
    fi
fi

#
#  Report Success
#
echo "shorewall Lite Version $VERSION Installed"
