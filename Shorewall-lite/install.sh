#!/bin/sh
#
# Script to install Shoreline Firewall Lite
#
#     (c) 2000-2016 - Tom Eastep (teastep@shorewall.net)
#
#       Shorewall documentation is available at http://shorewall.net
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

VERSION=xxx # The Build script inserts the actual version

usage() # $1 = exit status
{
    ME=$(basename $0)
    echo "usage: $ME [ <option> ] [ <shorewallrc file> ]"
    echo "where <option> is one of"
    echo "  -h"
    echo "  -v"
    echo "  -n"
    exit $1
}

install_file() # $1 = source $2 = target $3 = mode
{
    if cp -f $1 $2; then
	if chmod $3 $2; then
	    if [ -n "$OWNER" ]; then
		if chown $OWNER:$GROUP $2; then
		    return
		fi
	    else
		return 0
	    fi
	fi
    fi

    echo "ERROR: Failed to install $2" >&2
    exit 1
}

#
# Change to the directory containing this script
#
cd "$(dirname $0)"

if [ -f shorewall-lite.service ]; then
    PRODUCT=shorewall-lite
    Product="Shorewall Lite"
else
    PRODUCT=shorewall6-lite
    Product="Shorewall6 Lite"
fi

#
# Source common functions
#
. ./lib.installer || { echo "ERROR: Can not load common functions." >&2; exit 1; }

#
# Parse the run line
#
finished=0
configure=1

while [ $finished -eq 0 ] ; do

    option=$1

    case "$option" in
	-*)
	    option=${option#-}

	    while [ -n "$option" ]; do
		case $option in
		    h)
			usage 0
			;;
		    v)
			echo "$Product Firewall Installer Version $VERSION"
			exit 0
			;;
		    n*)
			configure=0
			option=${option#n}
			;;
		    *)
			usage 1
			;;
		esac
	    done

	    shift
	    ;;
	*)
	    finished=1
	    ;;
    esac
done

#
# Read the RC file
#
if [ $# -eq 0 ]; then
    if [ -f ./shorewallrc ]; then
	file=./shorewallrc
        . $file || fatal_error "Can not load the RC file: $file"
    elif [ -f ~/.shorewallrc ]; then
	file=~/.shorewallrc
        . $file || fatal_error "Can not load the RC file: $file"
    elif [ -f /usr/share/shorewall/shorewallrc ]; then
	file=/usr/share/shorewall/shorewallrc
        . $file || fatal_error "Can not load the RC file: $file"
    else
	fatal_error "No configuration file specified and /usr/share/shorewall/shorewallrc not found"
    fi
elif [ $# -eq 1 ]; then
    file=$1
    case $file in
	/*|.*)
	    ;;
	*)
	    file=./$file || exit 1
	    ;;
    esac

    . $file || fatal_error "Can not load the RC file: $file"
else
    usage 1
fi

if [ -z "${VARLIB}" ]; then
    VARLIB=${VARDIR}
    VARDIR=${VARLIB}/${PRODUCT}
elif [ -z "${VARDIR}" ]; then
    VARDIR=${VARLIB}/${PRODUCT}
fi

for var in SHAREDIR LIBEXECDIR CONFDIR SBINDIR VARLIB VARDIR; do
    require $var
done

[ -n "${INITFILE}" ] && require INITSOURCE && require INITDIR

PATH=${SBINDIR}:/bin:/usr${SBINDIR}:/usr/bin:/usr/local/bin:/usr/local${SBINDIR}

[ -n "$SANDBOX" ] && configure=0

#
# Determine where to install the firewall script
#
cygwin=

if [ -z "$BUILD" ]; then
    case $(uname) in
	cygwin*|CYGWIN*)
	    BUILD=cygwin
	    ;;
	Darwin)
	    BUILD=apple
	    ;;
	*)
	    if [ -f /etc/os-release ]; then
		eval $(cat /etc/os-release | grep ^ID)

		case $ID in
		    fedora|rhel|centos|foobar)
			BUILD=redhat
			;;
		    debian)
			BUILD=debian
			;;
		    gentoo)
			BUILD=gentoo
			;;
		    opensuse)
			BUILD=suse
			;;
		    alt|basealt|altlinux)
			BUILD=alt
			;;
		    *)
			BUILD="$ID"
			;;
		esac
	    elif [ -f ${CONFDIR}/debian_version ]; then
		BUILD=debian
	    elif [ -f /etc/gentoo-release ]; then
		BUILD=gentoo
	    elif [ -f /etc/altlinux-release ]; then
		BUILD=alt
	    elif [ -f ${CONFDIR}/redhat-release ]; then
		BUILD=redhat
	    elif [ -f ${CONFDIR}/SuSE-release ]; then
		BUILD=suse
	    elif [ -f ${CONFDIR}/slackware-version ] ; then
		BUILD=slackware
	    elif [ -f ${CONFDIR}/arch-release ] ; then
		BUILD=archlinux
	    elif [ -f ${CONFDIR}/openwrt_release ]; then
		BUILD=openwrt
	    else
		BUILD=linux
	    fi
	    ;;
    esac
fi

case $BUILD in
    cygwin*|CYGWIN*)
	OWNER=$(id -un)
	GROUP=$(id -gn)
	;;
    apple)
	[ -z "$OWNER" ] && OWNER=root
	[ -z "$GROUP" ] && GROUP=wheel
	;;
    *)
	if [ $(id -u) -eq 0 ]; then
	    [ -z "$OWNER" ] && OWNER=root
	    [ -z "$GROUP" ] && GROUP=root
	fi
	;;
esac

[ -n "$OWNER" ] && OWNERSHIP="$OWNER:$GROUP"

[ -n "$HOST" ] || HOST=$BUILD

case "$HOST" in
    cygwin)
	echo "$PRODUCT is not supported on Cygwin" >&2
	exit 1
	;;
    apple)
	echo "$PRODUCT is not supported on OS X" >&2
	exit 1
	;;
    debian)
	echo "Installing Debian-specific configuration..."
	;;
    gentoo)
	echo "Installing Gentoo-specific configuration..."
	;;
    redhat)
	echo "Installing Redhat/Fedora-specific configuration..."
	;;
    slackware)
	echo "Installing Slackware-specific configuration..."
	;;
    archlinux)
	echo "Installing ArchLinux-specific configuration..."
	;;
    suse)
	echo "Installing Suse-specific configuration..."
	;;
    openwrt)
	echo "Installing OpenWRT-specific configuration..."
	;;
    alt)
	echo "Installing ALT-specific configuration...";
	;;
    linux)
	;;
    *)
	fatal_error "ERROR: Unknown HOST \"$HOST\""
	;;
esac

[ -z "$INITDIR" ] && INITDIR="${CONFDIR}/init.d"

if [ -n "$DESTDIR" ]; then
    if [ `id -u` != 0 ] ; then
	echo "Not setting file owner/group permissions, not running as root."
	OWNERSHIP=""
    fi

    make_parent_directory ${DESTDIR}${INITDIR} 0755

else
    if [ ! -f ${SHAREDIR}/shorewall/coreversion ]; then
	echo "$PRODUCT $VERSION requires Shorewall Core which does not appear to be installed" >&2
	exit 1
    fi
fi

echo "Installing $Product Version $VERSION"

#
# Check for ${CONFDIR}/$PRODUCT
#
if [ -z "$DESTDIR" -a -d ${CONFDIR}/$PRODUCT ]; then
    if [ ! -f ${SHAREDIR}/shorewall/coreversion ]; then
	echo "$PRODUCT $VERSION requires Shorewall Core which does not appear to be installed" >&2
	exit 1
    fi

    [ -f ${CONFDIR}/$PRODUCT/shorewall.conf ] && \
	mv -f ${CONFDIR}/$PRODUCT/shorewall.conf ${CONFDIR}/$PRODUCT/$PRODUCT.conf
else
    rm -rf ${DESTDIR}${CONFDIR}/$PRODUCT
    rm -rf ${DESTDIR}${SHAREDIR}/$PRODUCT
    rm -rf ${DESTDIR}${VARDIR}
    [ "$LIBEXECDIR" = /usr/share ] || rm -rf ${DESTDIR}/usr/share/$PRODUCT/wait4ifup ${DESTDIR}/usr/share/$PRODUCT/shorecap
fi

#
# Check for ${SHAREDIR}/$PRODUCT/version
#
if [ -f ${DESTDIR}${SHAREDIR}/$PRODUCT/version ]; then
    first_install=""
else
    first_install="Yes"
fi

delete_file ${DESTDIR}/usr/share/$PRODUCT/xmodules

[ -n "${INITFILE}" ] && make_parent_directory ${DESTDIR}${INITDIR} 0755

#
# Create ${CONFDIR}/$PRODUCT, /usr/share/$PRODUCT and /var/lib/$PRODUCT if needed
#
make_parent_directory ${DESTDIR}${CONFDIR}/$PRODUCT 0755
make_parent_directory ${DESTDIR}${SHAREDIR}/$PRODUCT 0755
make_parent_directory ${DESTDIR}${LIBEXECDIR}/$PRODUCT 0755
make_parent_directory ${DESTDIR}${SBINDIR} 0755
make_parent_directory ${DESTDIR}${VARDIR} 0755

if [ -n "$DESTDIR" ]; then
    make_parent_directory ${DESTDIR}${CONFDIR}/logrotate.d 0755
    make_parent_directory ${DESTDIR}${INITDIR} 0755
fi

if [ -n "$INITFILE" ]; then
    if [ -f "${INITSOURCE}" ]; then
	initfile="${DESTDIR}${INITDIR}/${INITFILE}"
	install_file ${INITSOURCE} "$initfile" 0544

	[ "${SHAREDIR}" = /usr/share ] || eval sed -i \'s\|/usr/share/\|${SHAREDIR}/\|\' "$initfile"

	echo  "SysV init script $INITSOURCE installed in $initfile"
    fi
fi
#
# Install the .service file
#
if [ -z "${SERVICEDIR}" ]; then
    SERVICEDIR="$SYSTEMD"
fi

if [ -n "$SERVICEDIR" ]; then
    make_parent_directory ${DESTDIR}${SERVICEDIR} 0755
    [ -z "$SERVICEFILE" ] && SERVICEFILE=$PRODUCT.service
    install_file $SERVICEFILE ${DESTDIR}${SERVICEDIR}/$PRODUCT.service 0644
    [ ${SBINDIR} != /sbin ] && eval sed -i \'s\|/sbin/\|${SBINDIR}/\|\' ${DESTDIR}${SERVICEDIR}/$PRODUCT.service
    echo "Service file $SERVICEFILE installed as ${DESTDIR}${SERVICEDIR}/$PRODUCT.service"
fi
#
# Install the config file
#
if [ ! -f ${DESTDIR}${CONFDIR}/$PRODUCT/$PRODUCT.conf ]; then
   install_file $PRODUCT.conf ${DESTDIR}${CONFDIR}/$PRODUCT/$PRODUCT.conf 0744
   echo "Config file installed as ${DESTDIR}${CONFDIR}/$PRODUCT/$PRODUCT.conf"
fi

if [ $HOST = archlinux ] ; then
   sed -e 's!LOGFILE=/var/log/messages!LOGFILE=/var/log/messages.log!' -i ${DESTDIR}${CONFDIR}/$PRODUCT/$PRODUCT.conf
elif [ $HOST = gentoo ]; then
    # Adjust SUBSYSLOCK path (see https://bugs.gentoo.org/show_bug.cgi?id=459316)
    perl -p -w -i -e "s|^SUBSYSLOCK=.*|SUBSYSLOCK=/run/lock/$PRODUCT|;" ${DESTDIR}${CONFDIR}/$PRODUCT/$PRODUCT.conf
fi
#
# Install the default config path file
#
install_file configpath ${DESTDIR}${SHAREDIR}/$PRODUCT/configpath 0644
echo "Default config path file installed as ${DESTDIR}${SHAREDIR}/$PRODUCT/configpath"

#
# Install the libraries
#
for f in lib.* ; do
    if [ -f $f ]; then
        case $f in
            *installer)
                ;;
            *)
                install_file $f ${DESTDIR}${SHAREDIR}/$PRODUCT/$f 0644
                echo "Library ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/$PRODUCT/$f"
                ;;
        esac
    fi
done

ln -sf lib.base ${DESTDIR}${SHAREDIR}/$PRODUCT/functions

echo "Common functions linked through ${DESTDIR}${SHAREDIR}/$PRODUCT/functions"

#
# Install Shorecap
#

install_file shorecap ${DESTDIR}${LIBEXECDIR}/$PRODUCT/shorecap 0755
[ $SHAREDIR = /usr/share ] || eval sed -i \'s\|/usr/share/\|${SHAREDIR}/\|\' ${DESTDIR}${LIBEXECDIR}/$PRODUCT/shorecap

echo
echo "Capability file builder installed in ${DESTDIR}${LIBEXECDIR}/$PRODUCT/shorecap"

#
# Install the Modules files
#

if [ -f modules ]; then
    install_file modules ${DESTDIR}${SHAREDIR}/$PRODUCT/modules 0600
    echo "Modules file installed as ${DESTDIR}${SHAREDIR}/$PRODUCT/modules"

    for f in modules.*; do
	install_file $f ${DESTDIR}${SHAREDIR}/$PRODUCT/$f 0644
	echo "Module file $f installed as ${DESTDIR}${SHAREDIR}/$PRODUCT/$f"
    done
fi

if [ -f helpers ]; then
    install_file helpers ${DESTDIR}${SHAREDIR}/$PRODUCT/helpers 0600
    echo "Helper modules file installed as ${DESTDIR}${SHAREDIR}/$PRODUCT/helpers"
fi

#
# Install the Man Pages
#

if [ -d manpages -a -n "$MANDIR" ]; then
    cd manpages

    make_parent_directory ${DESTDIR}${MANDIR}/man5 0755

    for f in *.5; do
	gzip -c $f > $f.gz
	install_file $f.gz ${DESTDIR}${MANDIR}/man5/$f.gz 0644
	echo "Man page $f.gz installed to ${DESTDIR}${MANDIR}/man5/$f.gz"
    done

    make_parent_directory ${DESTDIR}${MANDIR}/man8 0755

    for f in *.8; do
	gzip -c $f > $f.gz
	install_file $f.gz ${DESTDIR}${MANDIR}/man8/$f.gz 0644
	echo "Man page $f.gz installed to ${DESTDIR}${MANDIR}/man8/$f.gz"
    done

    cd ..

    echo "Man Pages Installed"
fi

if [ -d ${DESTDIR}${CONFDIR}/logrotate.d ]; then
    install_file logrotate ${DESTDIR}${CONFDIR}/logrotate.d/$PRODUCT 0644
    echo "Logrotate file installed as ${DESTDIR}${CONFDIR}/logrotate.d/$PRODUCT"
fi

#
# Create the version file
#
echo "$VERSION" > ${DESTDIR}${SHAREDIR}/$PRODUCT/version
chmod 0644 ${DESTDIR}${SHAREDIR}/$PRODUCT/version
#
# Remove and create the symbolic link to the init script
#

if [ -z "${DESTDIR}" -a -n "${INITFILE}" ]; then
    rm -f ${SHAREDIR}/$PRODUCT/init
    ln -s ${INITDIR}/${INITFILE} ${SHAREDIR}/$PRODUCT/init
fi

delete_file ${DESTDIR}${SHAREDIR}/$PRODUCT/lib.common
delete_file ${DESTDIR}${SHAREDIR}/$PRODUCT/lib.cli
delete_file ${DESTDIR}${SHAREDIR}/$PRODUCT/wait4ifup

#
#  Creatae the symbolic link for the CLI
#
ln -sf shorewall ${DESTDIR}${SBINDIR}/${PRODUCT}

#
# Note -- not all packages will have the SYSCONFFILE so we need to check for its existance here
#
if [ -n "$SYSCONFFILE" -a -f "$SYSCONFFILE" -a ! -f ${DESTDIR}${SYSCONFDIR}/${PRODUCT} ]; then
    [ ${DESTDIR} ] && make_parent_directory ${DESTDIR}${SYSCONFDIR} 0755

    install_file ${SYSCONFFILE} ${DESTDIR}${SYSCONFDIR}/${PRODUCT} 0640
    echo "$SYSCONFFILE file installed in ${DESTDIR}${SYSCONFDIR}/${PRODUCT}"
fi

if [ ${SHAREDIR} != /usr/share ]; then
    eval sed -i \'s\|/usr/share/\|${SHAREDIR}/\|\' ${DESTDIR}${SHAREDIR}/${PRODUCT}/lib.base
fi

if [ $configure -eq 1 -a -z "$DESTDIR" -a -n "$first_install" -a -z "${cygwin}${mac}" ]; then
    if [ -n "$SERVICEDIR" ]; then
	if systemctl enable ${PRODUCT}.service; then
	    echo "$Product will start automatically at boot"
	fi
    elif mywhich insserv; then
	if insserv ${INITDIR}/${INITFILE} ; then
	    echo "$PRODUCT will start automatically at boot"
	    if [ $HOST = debian ]; then
		echo "Set startup=1 in ${CONFDIR}/default/$PRODUCT to enable"
		touch /var/log/$PRODUCT-init.log
		perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/$PRODUCT/$PRODUCT.conf
	    else
		echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/$PRODUCT/$PRODUCT.conf to enable"
	    fi
	else
	    cant_autostart
	fi
    elif mywhich chkconfig; then
	if chkconfig --add $PRODUCT ; then
	    echo "$PRODUCT will start automatically in run levels as follows:"
	    echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/$PRODUCT/${PRODUCT}.conf to enable"
	    chkconfig --list $PRODUCT
	else
	    cant_autostart
	fi
    elif mywhich update-rc.d ; then
	echo "$PRODUCT will start automatically at boot"
	echo "Set startup=1 in ${CONFDIR}/default/$PRODUCT to enable"
	touch /var/log/$PRODUCT-init.log
	perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/$PRODUCT/$PRODUCT.conf
	update-rc.d $PRODUCT enable
    elif mywhich rc-update ; then
	if rc-update add $PRODUCT default; then
	    echo "$PRODUCT will start automatically at boot"
	    if [ $HOST = debian ]; then
		echo "Set startup=1 in ${CONFDIR}/default/$PRODUCT to enable"
		touch /var/log/$PRODUCT-init.log
		perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/$PRODUCT/$PRODUCT.conf
	    else
		echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/$PRODUCT/$PRODUCT.conf to enable"
	    fi
	else
	    cant_autostart
	fi
    elif [ $HOST = openwrt -a -f ${CONFDIR}/rc.common ]; then
	/etc/init.d/$PRODUCT enable
	if /etc/init.d/$PRODUCT enabled; then
            echo "$PRODUCT will start automatically at boot"
	else
            cant_autostart
	fi
    elif [ "$INITFILE" != rc.${PRODUCT} ]; then #Slackware starts this automatically
	cant_autostart
    fi
fi

#
# Report Success
#
echo "$Product Version $VERSION Installed"
