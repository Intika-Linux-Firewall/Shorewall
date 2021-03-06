#!/bin/sh
#
# Script to install Shoreline Firewall
#
#     (c) 2000-2018 - Tom Eastep (teastep@shorewall.net)
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
    echo "  -s"
    echo "  -a"
    echo "  -p"
    echo "  -n"
    exit $1
}

run_install()
{
    if ! install $*; then
	echo
	echo "ERROR: Failed to install $*" >&2
	exit 1
    fi
}

install_file() # $1 = source $2 = target $3 = mode
{
    run_install $T $OWNERSHIP -m $3 $1 ${2}
}

#
# Change to the directory containing this script
#
cd "$(dirname $0)"

if [ -f shorewall.service ]; then
    PRODUCT=shorewall
    Product=Shorewall
else
    PRODUCT=shorewall6
    Product=Shorewall6
fi

#
# Source common functions
#
. ./lib.installer || { echo "ERROR: Can not load common functions." >&2; exit 1; }

#
# Parse the run line
#
#
T="-T"
INSTALLD='-D'

finished=0
configure=1

while [ $finished -eq 0 ]; do
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
		    s*)
			SPARSE=Yes
			option=${option#s}
			;;
		    a*)
			ANNOTATED=Yes
			option=${option#a}
			;;
		    p*)
			ANNOTATED=
			option=${option#p}
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

for var in SHAREDIR LIBEXECDIR PERLLIBDIR CONFDIR SBINDIR VARLIB VARDIR; do
    require $var
done

[ -n "${INITFILE}" ] && require INITSOURCE && require INITDIR

[ -n "$SANDBOX" ] && configure=0

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
	    elif [ -f /etc/debian_version ]; then
		BUILD=debian
	    elif [ -f /etc/gentoo-release ]; then
		BUILD=gentoo
	    elif [ -f /etc/altlinux-release ]; then
		BUILD=alt
	    elif [ -f /etc/redhat-release ]; then
		BUILD=redhat
	    elif [ -f /etc/slackware-version ] ; then
		BUILD=slackware
	    elif [ -f /etc/SuSE-release ]; then
		BUILD=suse
	    elif [ -f /etc/arch-release ] ; then
		BUILD=archlinux
	    elif [ -f ${CONFDIR}/openwrt_release ] ; then
		BUILD=openwrt
	    else
		BUILD=linux
	    fi
	    ;;
    esac
fi

case $BUILD in
    cygwin*)
	OWNER=$(id -un)
	GROUP=$(id -gn)
	;;
    apple)
	[ -z "$OWNER" ] && OWNER=root
	[ -z "$GROUP" ] && GROUP=wheel
	INSTALLD=
	T=
	;;
    *)
	[ -z "$OWNER" ] && OWNER=root
	[ -z "$GROUP" ] && GROUP=root
	;;
esac

OWNERSHIP="-o $OWNER -g $GROUP"

case "$HOST" in
    cygwin)
	echo "Installing Cygwin-specific configuration..."
	;;
    apple)
	echo "Installing Mac-specific configuration...";
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
    suse)
	echo "Installing SuSE-specific configuration...";
	;;
    slackware)
	echo "Installing Slackware-specific configuration..."
	;;
    archlinux)
	echo "Installing ArchLinux-specific configuration..."
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
	fatal_error "Unknown HOST \"$HOST\""
	;;
esac

if [ ${PRODUCT} = shorewall ]; then
    if [ -n "$DIGEST" ]; then
	#
	# The user specified which digest to use
	#
	if [ "$DIGEST" != SHA ]; then
	    if [ "$BUILD" = "$HOST" ] && ! eval perl -e \'use Digest::$DIGEST\;\' 2> /dev/null ; then
		fatal_error "Perl compilation with Digest::$DIGEST failed"
	    fi

	    cp -af Perl/Shorewall/Chains.pm Perl/Shorewall/Chains.pm.bak
	    cp -af Perl/Shorewall/Config.pm Perl/Shorewall/Config.pm.bak

	    eval sed -i \'s/Digest::SHA/Digest::$DIGEST/\' Perl/Shorewall/Chains.pm
	    eval sed -i \'s/Digest::SHA/Digest::$DIGEST/\' Perl/Shorewall/Config.pm
	fi
    elif [ "$BUILD" = "$HOST" ]; then
        #
        # Fix up 'use Digest::' if SHA1 is installed
        #
	DIGEST=SHA
	if ! perl -e 'use Digest::SHA;' 2> /dev/null ; then
	    if perl -e 'use Digest::SHA1;' 2> /dev/null ; then
		cp -af Perl/Shorewall/Chains.pm Perl/Shorewall/Chains.pm.bak
		cp -af Perl/Shorewall/Config.pm Perl/Shorewall/Config.pm.bak

		sed -i 's/Digest::SHA/Digest::SHA1/' Perl/Shorewall/Chains.pm
		sed -i 's/Digest::SHA/Digest::SHA1/' Perl/Shorewall/Config.pm
		DIGEST=SHA1
	    else
		fatal_error "Shorewall $VERSION requires either Digest::SHA or Digest::SHA1"
	    fi
	fi
    fi

    if [ "$BUILD" = "$HOST" ]; then
        #
        # Verify that Perl and all required modules are installed
        #
	echo "Compiling the Shorewall Perl Modules with Digest::$DIGEST"

	if ! perl -c Perl/compiler.pl; then
	    echo "ERROR: $Product $VERSION requires Perl which either is not installed or is not able to compile the Shorewall Perl code" >&2
	    echo "       Try perl -c $PWD/Perl/compiler.pl" >&2
	    exit 1
	fi
    else
	echo "Using Digest::$DIGEST"
    fi
fi

if [ $BUILD != cygwin ]; then
    if [ `id -u` != 0 ] ; then
	echo "Not setting file owner/group permissions, not running as root."
	OWNERSHIP=""
    fi
fi

run_install -d $OWNERSHIP -m 0755 ${DESTDIR}${SBINDIR}
[ -n "${INITFILE}" ] && run_install -d $OWNERSHIP -m 0755 ${DESTDIR}${INITDIR}
if [ -z "$DESTDIR" -a ${PRODUCT} != shorewall ]; then
    [ -x ${LIBEXECDIR}/shorewall/compiler.pl ] || fatal_error "Shorewall >= 4.5.0 is not installed"
fi

echo "Installing $Product Version $VERSION"

#
# Check for /usr/share/${PRODUCT}/version
#
if [ -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/version ]; then
    first_install=""
else
    first_install="Yes"
fi

if [ -z "${DESTDIR}" -a ${PRODUCT} = shorewall -a ! -f ${SHAREDIR}/shorewall/coreversion ]; then
    echo "Shorewall $VERSION requires Shorewall Core which does not appear to be installed"
    exit 1
fi

#
# Install the Firewall Script
#
if [ -n "$INITFILE" ]; then
    if [ -f "${INITSOURCE}" ]; then
	initfile="${DESTDIR}${INITDIR}/${INITFILE}"
	install_file $INITSOURCE "$initfile" 0544

	[ "${SHAREDIR}" = /usr/share ] || eval sed -i \'s\|/usr/share/\|${SHAREDIR}/\|\' "$initfile"

	echo  "SysV init script $INITSOURCE installed in $initfile"
    fi
fi

#
# Create /etc/${PRODUCT} and other directories
#
make_parent_directory ${DESTDIR}${CONFDIR}/${PRODUCT} 0755
make_parent_directory ${DESTDIR}${LIBEXECDIR}/${PRODUCT} 0755
make_parent_directory ${DESTDIR}${PERLLIBDIR}/Shorewall 0755
make_parent_directory ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles 0755
make_parent_directory ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated 0755
make_parent_directory ${DESTDIR}${VARDIR} 0755

chmod 0755 ${DESTDIR}${SHAREDIR}/${PRODUCT}

[ -n "$DESTDIR" ] && make_parent_directory ${DESTDIR}${CONFDIR}/logrotate.d 0755

#
# Install the .service file
#
if [ -z "${SERVICEDIR}" ]; then
    SERVICEDIR="$SYSTEMD"
fi

if [ -n "$SERVICEDIR" ]; then
    make_parent_directory ${DESTDIR}${SERVICEDIR} 0755
    [ -z "$SERVICEFILE" ] && SERVICEFILE=${PRODUCT}.service
    run_install $OWNERSHIP -m 0644 $SERVICEFILE ${DESTDIR}${SERVICEDIR}/${PRODUCT}.service
    [ ${SBINDIR} != /sbin ] && eval sed -i \'s\|/sbin/\|${SBINDIR}/\|\' ${DESTDIR}${SERVICEDIR}/${PRODUCT}.service
    echo "Service file $SERVICEFILE installed as ${DESTDIR}${SERVICEDIR}/${PRODUCT}.service"
fi

if [ -z "$first_install" ]; then
    #
    # These use absolute path names since the files that they are removing existed
    # prior to the use of directory variables
    #
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/compiler
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.accounting
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.actions
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.dynamiczones
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.maclist
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.nat
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.providers
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.proxyarp
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.tc
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.tcrules
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/lib.tunnels

    if [ ${PRODUCT} = shorewall6 ]; then
	delete_file ${DESTDIR}/usr/share/shorewall6/lib.cli
	delete_file ${DESTDIR}/usr/share/shorewall6/lib.common
	delete_file ${DESTDIR}/usr/share/shorewall6/wait4ifup
    fi

    delete_file ${DESTDIR}/usr/share/${PRODUCT}/prog.header6
    delete_file ${DESTDIR}/usr/share/${PRODUCT}/prog.footer6

    #
    # Delete obsolete config files and manpages
    #
    delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/tos
    delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/tcrules
    delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/stoppedrules
    delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/notrack
    delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/blacklist
    delete_file ${DESTDIR}${MANDIR}/man5/${PRODUCT}/${PRODUCT}-tos
    delete_file ${DESTDIR}${MANDIR}/man5/${PRODUCT}/${PRODUCT}-tcrules
    delete_file ${DESTDIR}${MANDIR}/man5/${PRODUCT}/${PRODUCT}-stoppedrules
    delete_file ${DESTDIR}${MANDIR}/man5/${PRODUCT}/${PRODUCT}-notrack
    delete_file ${DESTDIR}${MANDIR}/man5/${PRODUCT}/${PRODUCT}-blacklist

    if [ ${PRODUCT} = shorewall ]; then
	#
	# Delete deprecated macros and actions
	#
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/macro.SNMPTrap
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.A_REJECT
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.Drop
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.Reject
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.A_Drop
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.A_Reject
	delete_file ${DESTDIR}${SHAREDIR}/shorewall/action.A_AllowICMPs
    else
	delete_file ${DESTDIR}${SHAREDIR}/shorewall6/action.A_AllowICMPs
	delete_file ${DESTDIR}${SHAREDIR}/shorewall6/action.AllowICMPs
	delete_file ${DESTDIR}${SHAREDIR}/shorewall6/action.Broadcast
	delete_file ${DESTDIR}${SHAREDIR}/shorewall6/action.Multicast
    fi
fi

#
# Install the Module Helpers file
#
run_install $OWNERSHIP -m 0644 helpers ${DESTDIR}${SHAREDIR}/${PRODUCT}/helpers
echo "Helper modules file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/helpers"

#
# Install the default config path file
#
install_file configpath ${DESTDIR}${SHAREDIR}/${PRODUCT}/configpath 0644
echo "Default config path file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/configpath"
#
# Install the Standard Actions file
#
install_file actions.std ${DESTDIR}${SHAREDIR}/${PRODUCT}/actions.std 0644
echo "Standard actions file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/actions.std"

cd configfiles

if [ -n "$ANNOTATED" ]; then
    suffix=.annotated
else
    suffix=
fi

#
# Install the config file
#
fix_config() {
    if [ $HOST = archlinux ] ; then
	sed -e 's!LOGFILE=/var/log/messages!LOGFILE=/var/log/messages.log!' -i $1
    elif [ $HOST = debian ]; then
	perl -p -w -i -e 's|^STARTUP_ENABLED=.*|STARTUP_ENABLED=Yes|;' $1
    elif [ $HOST = gentoo ]; then
	# Adjust SUBSYSLOCK path (see https://bugs.gentoo.org/show_bug.cgi?id=459316)
	perl -p -w -i -e "s|^SUBSYSLOCK=.*|SUBSYSLOCK=/run/lock/${PRODUCT}|;" $1
    fi
}

run_install $OWNERSHIP -m 0644 $PRODUCT.conf ${DESTDIR}${SHAREDIR}/$PRODUCT/configfiles/

fix_config ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/${PRODUCT}.conf

if [ ${PRODUCT} = shorewall ]; then
    run_install $OWNERSHIP -m 0644 shorewall.conf.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

    fix_config ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/${PRODUCT}.conf.annotated
fi

if [ ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/${PRODUCT}.conf ]; then
    run_install $OWNERSHIP -m 0600 ${PRODUCT}.conf${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/${PRODUCT}.conf

    fix_config ${DESTDIR}${CONFDIR}/${PRODUCT}/${PRODUCT}.conf

    echo "Config file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/${PRODUCT}.conf"
fi

#
# Install the init file
#
run_install $OWNERSHIP -m 0644 init ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/init

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/init ]; then
    run_install $OWNERSHIP -m 0600 init ${DESTDIR}${CONFDIR}/${PRODUCT}/init
    echo "Init file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/init"
fi

#
# Install the zones file
#
run_install $OWNERSHIP -m 0644 zones           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 zones.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/zones ]; then
    run_install $OWNERSHIP -m 0600 zones${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/zones
    echo "Zones file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/zones"
fi

#
# Install the policy file
#
run_install $OWNERSHIP -m 0644 policy           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 policy.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/policy ]; then
    run_install $OWNERSHIP -m 0600 policy${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/policy
    echo "Policy file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/policy"
fi
#
# Install the interfaces file
#
run_install $OWNERSHIP -m 0644 interfaces           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 interfaces.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/interfaces ]; then
    run_install $OWNERSHIP -m 0600 interfaces${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/interfaces
    echo "Interfaces file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/interfaces"
fi

#
# Install the hosts file
#
run_install $OWNERSHIP -m 0644 hosts           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 hosts.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/hosts ]; then
    run_install $OWNERSHIP -m 0600 hosts${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/hosts
    echo "Hosts file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/hosts"
fi
#
# Install the rules file
#
run_install $OWNERSHIP -m 0644 rules           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 rules.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/rules ]; then
    run_install $OWNERSHIP -m 0600 rules${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/rules
    echo "Rules file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/rules"
fi

if [ -f nat ]; then
    #
    # Install the NAT file
    #
    run_install $OWNERSHIP -m 0644 nat           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
    run_install $OWNERSHIP -m 0644 nat.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/nat ]; then
	run_install $OWNERSHIP -m 0600 nat${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/nat
	echo "NAT file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/nat"
    fi
fi

#
# Install the NETMAP file
#
run_install $OWNERSHIP -m 0644 netmap           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
run_install $OWNERSHIP -m 0644 netmap.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/netmap ]; then
    run_install $OWNERSHIP -m 0600 netmap${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/netmap
    echo "NETMAP file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/netmap"
fi
#
# Install the Parameters file
#
run_install $OWNERSHIP -m 0644 params          ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 params.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -f ${DESTDIR}${CONFDIR}/${PRODUCT}/params ]; then
    chmod 0644 ${DESTDIR}${CONFDIR}/${PRODUCT}/params
else
    case "$SPARSE" in
	[Vv]ery)
	;;
	*)
	    run_install $OWNERSHIP -m 0600 params${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/params
	    echo "Parameter file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/params"
	    ;;
    esac
fi

if [ ${PRODUCT} = shorewall ]; then
    #
    # Install the proxy ARP file
    #
    run_install $OWNERSHIP -m 0644 proxyarp           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
    run_install $OWNERSHIP -m 0644 proxyarp.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyarp ]; then
	run_install $OWNERSHIP -m 0600 proxyarp${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyarp
	echo "Proxy ARP file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyarp"
    fi
else
    #
    # Install the Proxyndp file
    #
    run_install $OWNERSHIP -m 0644 proxyndp           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
    run_install $OWNERSHIP -m 0644 proxyndp.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyndp ]; then
	run_install $OWNERSHIP -m 0600 proxyndp${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyndp
	echo "Proxyndp file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/proxyndp"
    fi
fi
#
# Install the Stopped Rules file
#
run_install $OWNERSHIP -m 0644 stoppedrules           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 stoppedrules.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/stoppedrules ]; then
    run_install $OWNERSHIP -m 0600 stoppedrules${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/stoppedrules
    echo "Stopped Rules file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/stoppedrules"
fi
#
# Install the Mac List file
#
run_install $OWNERSHIP -m 0644 maclist           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 maclist.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/maclist ]; then
    run_install $OWNERSHIP -m 0600 maclist${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/maclist
    echo "mac list file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/maclist"
fi

#
# Install the SNAT file
#
run_install $OWNERSHIP -m 0644 snat           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
run_install $OWNERSHIP -m 0644 snat.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/snat ]; then
    run_install $OWNERSHIP -m 0600 snat${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/snat
    echo "SNAT file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/snat"
fi

if [ -f arprules ]; then
    #
    # Install the ARP rules file
    #
    run_install $OWNERSHIP -m 0644 arprules           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
    run_install $OWNERSHIP -m 0644 arprules.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/arprules ]; then
	run_install $OWNERSHIP -m 0600 arprules${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/arprules
	echo "ARP rules file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/arprules"
    fi
fi
#
# Install the Conntrack file
#
run_install $OWNERSHIP -m 0644 conntrack           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
run_install $OWNERSHIP -m 0644 conntrack.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

case "$SPARSE" in
    [Vv]ery)
    ;;
    *)
	if [ ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/conntrack ]; then
	    run_install $OWNERSHIP -m 0600 conntrack${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/conntrack
	    echo "Conntrack file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/conntrack"
	fi
	;;
esac

#
# Install the Mangle file
#
run_install $OWNERSHIP -m 0644 mangle           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 mangle.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/mangle ]; then
    run_install $OWNERSHIP -m 0600 mangle${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/mangle
    echo "Mangle file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/mangle"
fi

#
# Install the TC Interfaces file
#
run_install $OWNERSHIP -m 0644 tcinterfaces           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tcinterfaces.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcinterfaces ]; then
    run_install $OWNERSHIP -m 0600 tcinterfaces${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tcinterfaces
    echo "TC Interfaces file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcinterfaces"
fi

#
# Install the TC Priority file
#
run_install $OWNERSHIP -m 0644 tcpri           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tcpri.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcpri ]; then
    run_install $OWNERSHIP -m 0600 tcpri${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tcpri
    echo "TC Priority file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcpri"
fi

#
# Install the Tunnels file
#
run_install $OWNERSHIP -m 0644 tunnels           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tunnels.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tunnels ]; then
    run_install $OWNERSHIP -m 0600 tunnels${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tunnels
    echo "Tunnels file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tunnels"
fi

#
# Install the blacklist rules file
#
run_install $OWNERSHIP -m 0644 blrules           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 blrules.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/blrules ]; then
    run_install $OWNERSHIP -m 0600 blrules${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/blrules
    echo "Blrules file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/blrules"
fi

if [ -f findgw ]; then
    #
    # Install the findgw file
    #
    run_install $OWNERSHIP -m 0644 findgw ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/findgw ]; then
	run_install $OWNERSHIP -m 0600 findgw ${DESTDIR}${CONFDIR}/${PRODUCT}
	echo "Find GW file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/findgw"
    fi
fi

#
# Delete the Limits Files
#
delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/action.Limit
delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/Limit
#
# Delete the xmodules file
#
delete_file ${DESTDIR}${SHAREDIR}/${PRODUCT}/xmodules
#
# Install the Providers file
#
run_install $OWNERSHIP -m 0644 providers           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 providers.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/providers ]; then
    run_install $OWNERSHIP -m 0600 providers${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/providers
    echo "Providers file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/providers"
fi

#
# Install the Route Rules file
#
run_install $OWNERSHIP -m 0644 rtrules           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 rtrules.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -f ${DESTDIR}${CONFDIR}/${PRODUCT}/route_rules -a ! ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules ]; then
    mv -f ${DESTDIR}${CONFDIR}/${PRODUCT}/route_rules ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules
    echo "${DESTDIR}${CONFDIR}/${PRODUCT}/route_rules has been renamed ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules"
elif [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules ]; then
    run_install $OWNERSHIP -m 0600 rtrules${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules
    echo "Routing rules file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/rtrules"
fi

#
# Install the tcclasses file
#
run_install $OWNERSHIP -m 0644 tcclasses           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tcclasses.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclasses ]; then
    run_install $OWNERSHIP -m 0600 tcclasses${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclasses
    echo "TC Classes file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclasses"
fi

#
# Install the tcdevices file
#
run_install $OWNERSHIP -m 0644 tcdevices           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tcdevices.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcdevices ]; then
    run_install $OWNERSHIP -m 0600 tcdevices${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tcdevices
    echo "TC Devices file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcdevices"
fi

#
# Install the tcfilters file
#
run_install $OWNERSHIP -m 0644 tcfilters           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 tcfilters.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcfilters ]; then
    run_install $OWNERSHIP -m 0600 tcfilters${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/tcfilters
    echo "TC Filters file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcfilters"
fi

#
# Install the secmarks file
#
run_install $OWNERSHIP -m 0644 secmarks           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
run_install $OWNERSHIP -m 0644 secmarks.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/secmarks ]; then
    run_install $OWNERSHIP -m 0600 secmarks${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/secmarks
    echo "Secmarks file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/secmarks"
fi

#
# Install the init file
#
run_install $OWNERSHIP -m 0644 init ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/init ]; then
    run_install $OWNERSHIP -m 0600 init ${DESTDIR}${CONFDIR}/${PRODUCT}
    echo "Init file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/init"
fi

if [ -f initdone ]; then
    #
    # Install the initdone file
    #
    run_install $OWNERSHIP -m 0644 initdone ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/initdone ]; then
	run_install $OWNERSHIP -m 0600 initdone ${DESTDIR}${CONFDIR}/${PRODUCT}
	echo "Initdone file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/initdone"
    fi
fi
#
# Install the start file
#
run_install $OWNERSHIP -m 0644 start ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/start

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/start ]; then
    run_install $OWNERSHIP -m 0600 start ${DESTDIR}${CONFDIR}/${PRODUCT}/start
    echo "Start file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/start"
fi
#
# Install the stop file
#
run_install $OWNERSHIP -m 0644 stop ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/stop

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/stop ]; then
    run_install $OWNERSHIP -m 0600 stop ${DESTDIR}${CONFDIR}/${PRODUCT}/stop
    echo "Stop file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/stop"
fi
#
# Install the stopped file
#
run_install $OWNERSHIP -m 0644 stopped ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/stopped

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/stopped ]; then
    run_install $OWNERSHIP -m 0600 stopped ${DESTDIR}${CONFDIR}/${PRODUCT}/stopped
    echo "Stopped file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/stopped"
fi

if [ -f ecn ]; then
    #
    # Install the ECN file
    #
    run_install $OWNERSHIP -m 0644 ecn           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles
    run_install $OWNERSHIP -m 0644 ecn.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

    if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/ecn ]; then
	run_install $OWNERSHIP -m 0600 ecn${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/ecn
	echo "ECN file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/ecn"
    fi
fi
#
# Install the Accounting file
#
run_install $OWNERSHIP -m 0644 accounting           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 accounting.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/accounting ]; then
    run_install $OWNERSHIP -m 0600 accounting${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/accounting
    echo "Accounting file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/accounting"
fi
#
# Install the private library file
#
run_install $OWNERSHIP -m 0644 lib.private ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/lib.private ]; then
    run_install $OWNERSHIP -m 0600 lib.private ${DESTDIR}${CONFDIR}/${PRODUCT}
    echo "Private library file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/lib.private"
fi
#
# Install the Started file
#
run_install $OWNERSHIP -m 0644 started ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/started

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/started ]; then
    run_install $OWNERSHIP -m 0600 started ${DESTDIR}${CONFDIR}/${PRODUCT}/started
    echo "Started file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/started"
fi
#
# Install the Restored file
#
run_install $OWNERSHIP -m 0644 restored ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/restored

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/restored ]; then
    run_install $OWNERSHIP -m 0600 restored ${DESTDIR}${CONFDIR}/${PRODUCT}/restored
    echo "Restored file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/restored"
fi
#
# Install the Clear file
#
run_install $OWNERSHIP -m 0644 clear ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/clear

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/clear ]; then
    run_install $OWNERSHIP -m 0600 clear ${DESTDIR}${CONFDIR}/${PRODUCT}/clear
    echo "Clear file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/clear"
fi
#
# Install the Isusable file
#
run_install $OWNERSHIP -m 0644 isusable ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/isusable
#
# Install the Refresh file
#
run_install $OWNERSHIP -m 0644 refresh ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/refresh

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/refresh ]; then
    run_install $OWNERSHIP -m 0600 refresh ${DESTDIR}${CONFDIR}/${PRODUCT}/refresh
    echo "Refresh file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/refresh"
fi
#
# Install the Refreshed file
#
run_install $OWNERSHIP -m 0644 refreshed ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/refreshed

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/refreshed ]; then
    run_install $OWNERSHIP -m 0600 refreshed ${DESTDIR}${CONFDIR}/${PRODUCT}/refreshed
    echo "Refreshed file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/refreshed"
fi
#
# Install the Tcclear file
#
run_install $OWNERSHIP -m 0644 tcclear           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclear ]; then
    run_install $OWNERSHIP -m 0600 tcclear ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclear
    echo "Tcclear file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/tcclear"
fi
#
# Install the Scfilter file
#
run_install $OWNERSHIP -m 0644 scfilter ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/scfilter

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/scfilter ]; then
    run_install $OWNERSHIP -m 0600 scfilter ${DESTDIR}${CONFDIR}/${PRODUCT}/scfilter
    echo "Scfilter file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/scfilter"
fi

#
# Install the Actions file
#
run_install $OWNERSHIP -m 0644 actions           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 actions.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/actions ]; then
    run_install $OWNERSHIP -m 0600 actions${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/actions
    echo "Actions file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/actions"
fi

#
# Install the Routes file
#
run_install $OWNERSHIP -m 0644 routes           ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/
run_install $OWNERSHIP -m 0644 routes.annotated ${DESTDIR}${SHAREDIR}/${PRODUCT}/configfiles/

if [ -z "$SPARSE" -a ! -f ${DESTDIR}${CONFDIR}/${PRODUCT}/routes ]; then
    run_install $OWNERSHIP -m 0600 routes${suffix} ${DESTDIR}${CONFDIR}/${PRODUCT}/routes
    echo "Routes file installed as ${DESTDIR}${CONFDIR}/${PRODUCT}/routes"
fi

cd ..

#
# Install the Action files
#
cd Actions

for f in action.* ; do
    case $f in
	*.deprecated)
	    install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/${f%.*} 0644
	    echo "Action ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/${f%.*}"
	    ;;
	*)
	    install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f 0644
	    echo "Action ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f"
	    ;;
    esac
done
#
# Now the Macros
#
cd ../Macros

for f in macro.* ; do
    case $f in
	*.deprecated)
	    install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/${f%.*} 0644
	    echo "Macro ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/${f%.*}"
	    ;;
	*)
	    install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f 0644
	    echo "Macro ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f"
	    ;;
    esac
done

cd ..

#
# Install the libraries
#
for f in lib.* Perl/lib.*; do
    if [ -f $f ]; then
        case $f in
            *installer)
                ;;
            *)
                install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/$(basename $f) 0644
                echo "Library ${f#*.} file installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f"
                ;;
        esac
    fi
done

if [ ${PRODUCT} = shorewall6 ]; then
    #
    # Symbolically link 'functions' to lib.base
    #
    ln -sf lib.base ${DESTDIR}${SHAREDIR}/${PRODUCT}/functions
    #
    # And create a symbolic link for the CLI
    #
    ln -sf shorewall ${DESTDIR}${SBINDIR}/shorewall6
fi

if [ -d Perl ]; then
    #
    # ${SHAREDIR}/${PRODUCT}/$Product if needed
    #
    make_parent_directory ${DESTDIR}${SHAREDIR}/${PRODUCT}/$Product 0755
    #
    # Install the Compiler
    #
    cd Perl

    install_file compiler.pl ${DESTDIR}${LIBEXECDIR}/${PRODUCT}/compiler.pl 0755

    echo
    echo "Compiler installed in ${DESTDIR}${LIBEXECDIR}/${PRODUCT}/compiler.pl"
    #
    # Install the params file helper
    #
    install_file getparams ${DESTDIR}${LIBEXECDIR}/${PRODUCT}/getparams 0755
    [ $SHAREDIR = /usr/share ] || eval sed -i \'s\|/usr/share/\|${SHAREDIR}/\|\' ${DESTDIR}${LIBEXECDIR}/${PRODUCT}/getparams

    echo
    echo "Params file helper installed in ${DESTDIR}${LIBEXECDIR}/${PRODUCT}/getparams"
    #
    # Install the Perl modules
    #
    for f in $Product/*.pm ; do
	install_file $f ${DESTDIR}${PERLLIBDIR}/$f 0644
	echo "Module ${f%.*} installed as ${DESTDIR}${PERLLIBDIR}/$f"
    done

    [ -f Perl/Shorewall/Chains.pm.bak ] && mv Perl/Shorewall/Chains.pm.bak Perl/Shorewall/Chains.pm
    [ -f Perl/Shorewall/Config.pm.bak ] && mv Perl/Shorewall/Config.pm.bak Perl/Shorewall/Config.pm

    #
    # Install the program skeleton files
    #
    for f in prog.* ; do
        install_file $f ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f 0644
        echo "Program skeleton file ${f#*.} installed as ${DESTDIR}${SHAREDIR}/${PRODUCT}/$f"
    done

    cd ..

    if [ -z "$DESTDIR" ]; then
	rm -rf ${SHAREDIR}/${PRODUCT}-perl
	rm -rf ${SHAREDIR}/${PRODUCT}-shell
	[ "$PERLLIBDIR" != ${SHAREDIR}/${PRODUCT} ] && rm -rf ${SHAREDIR}/${PRODUCT}/$Product
    fi
fi
#
# Create the version file
#
echo "$VERSION" > ${DESTDIR}${SHAREDIR}/${PRODUCT}/version
chmod 0644 ${DESTDIR}${SHAREDIR}/${PRODUCT}/version
#
# Remove and create the symbolic link to the init script
#

if [ -z "${DESTDIR}" -a -n "${INITFILE}" ]; then
    rm -f ${SHAREDIR}/${PRODUCT}/init
    ln -s ${INITDIR}/${INITFILE} ${SHAREDIR}/${PRODUCT}/init
fi

#
# Install the Man Pages
#

if [ -n "$MANDIR" ]; then

cd manpages

if [ ${PRODUCT} = shorewall ]; then
    [ -n "$INSTALLD" ] || make_parent_directory ${DESTDIR}${MANDIR}/man5 0755

    for f in *.5; do
	gzip -9c $f > $f.gz
	run_install $INSTALLD  -m 0644 $f.gz ${DESTDIR}${MANDIR}/man5/$f.gz
	echo "Man page $f.gz installed to ${DESTDIR}${MANDIR}/man5/$f.gz"
    done
fi

if [ ${PRODUCT} = shorewall6 ]; then
    make_parent_directory ${DESTDIR}${MANDIR}/man5 0755

    rm -f ${DESTDIR}${MANDIR}/man5/shorewall6*

    for f in \
	shorewall-accounting.5  shorewall-ipsets.5   shorewall-providers.5     shorewall-tcclasses.5     \
	shorewall-actions.5     shorewall-maclist.5                            shorewall-tcdevices.5     \
	                        shorewall-mangle.5   shorewall-proxyndp.5      shorewall-tcfilters.5     \
	shorewall-blacklist.5   shorewall-masq.5     shorewall-routes.5        shorewall-tcinterfaces.5  \
	shorewall-blrules.5     shorewall-modules.5  shorewall-routestopped.5  shorewall-tcpri.5         \
	shorewall-conntrack.5   shorewall-nat.5      shorewall-rtrules.5       shorewall-tcrules.5       \
                                shorewall-nesting.5  shorewall-rules.5         shorewall-tos.5           \
	shorewall-exclusion.5   shorewall-netmap.5   shorewall-secmarks.5      shorewall-tunnels.5       \
	shorewall-hosts.5       shorewall-params.5   shorewall-snat.5          shorewall-vardir.5        \
	shorewall-interfaces.5  shorewall-policy.5   shorewall-stoppedrules.5  shorewall-zones.5
    do
	f6=shorewall6-${f#*-}
	echo ".so man5/$f" > ${DESTDIR}${MANDIR}/man5/$f6
    done

    echo ".so man5/shorewall.conf.5" > ${DESTDIR}${MANDIR}/man5/shorewall6.conf.5
fi

[ -n "$INSTALLD" ] || make_parent_directory ${DESTDIR}${MANDIR}/man8 0755

for f in *.8; do
    gzip -9c $f > $f.gz
    run_install $INSTALLD  -m 0644 $f.gz ${DESTDIR}${MANDIR}/man8/$f.gz
    echo "Man page $f.gz installed to ${DESTDIR}${MANDIR}/man8/$f.gz"
done

cd ..

echo "Man Pages Installed"
fi

if [ -d ${DESTDIR}${CONFDIR}/logrotate.d ]; then
    run_install $OWNERSHIP -m 0644 logrotate ${DESTDIR}${CONFDIR}/logrotate.d/${PRODUCT}
    echo "Logrotate file installed as ${DESTDIR}${CONFDIR}/logrotate.d/${PRODUCT}"
fi

#
# Note -- not all packages will have the SYSCONFFILE so we need to check for its existance here
#
if [ -n "$SYSCONFFILE" -a -f "$SYSCONFFILE" -a ! -f ${DESTDIR}${SYSCONFDIR}/${PRODUCT} ]; then
    if [ ${DESTDIR} ]; then
	make_parent_directory ${DESTDIR}${SYSCONFDIR} 0755
    fi

    run_install $OWNERSHIP -m 0644 ${SYSCONFFILE} ${DESTDIR}${SYSCONFDIR}/${PRODUCT}
    echo "$SYSCONFFILE file installed in ${DESTDIR}${SYSCONFDIR}/${PRODUCT}"
fi

#
# Remove deleted actions and macros
#
if [ $PRODUCT = shorewall ]; then
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/action.A_AllowICMPs
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/action.A_Drop
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/action.A_Reject
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/action.Drop
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/action.Reject

    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/deprecated/macro.SMTPTraps
fi

#
# Remove unneeded modules files
#

if [ -n "$first_install" ]; then
    rm -f ${DESTDIR}${SHAREDIR}/${PRODUCT}/modules*
fi

if [ $configure -eq 1 -a -z "$DESTDIR" -a -n "$first_install" -a -z "${cygwin}${mac}" ]; then
    if [ -n "$SERVICEDIR" ]; then
	if systemctl enable ${PRODUCT}.service; then
	    echo "$Product will start automatically at boot"
	fi
    elif mywhich insserv; then
	if insserv ${CONFDIR}/init.d/${PRODUCT} ; then
	    echo "${PRODUCT} will start automatically at boot"
	    if [ $HOST = debian ]; then
		echo "Set startup=1 in ${CONFDIR}/default/${PRODUCT} to enable"
		touch /var/log/${PRODUCT}-init.log
		perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf
	    else
		echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf to enable"
	    fi
	else
	    cant_autostart
	fi
    elif mywhich chkconfig; then
	if chkconfig --add ${PRODUCT} ; then
	    echo "${PRODUCT} will start automatically in run levels as follows:"
	    echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf to enable"
	    chkconfig --list ${PRODUCT}
	else
	    cant_autostart
	fi
    elif mywhich update-rc.d ; then
	echo "${PRODUCT} will start automatically at boot"
	echo "Set startup=1 in ${CONFDIR}/default/${PRODUCT} to enable"
	touch /var/log/${PRODUCT}-init.log
	perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf
	update-rc.d ${PRODUCT} enable
    elif mywhich rc-update ; then
	if rc-update add ${PRODUCT} default; then
	    echo "${PRODUCT} will start automatically at boot"
	    if [ $HOST = debian ]; then
		echo "Set startup=1 in ${CONFDIR}/default/${PRODUCT} to enable"
		touch /var/log/${PRODUCT}-init.log
		perl -p -w -i -e 's/^STARTUP_ENABLED=No/STARTUP_ENABLED=Yes/;s/^IP_FORWARDING=On/IP_FORWARDING=Keep/;s/^SUBSYSLOCK=.*/SUBSYSLOCK=/;' ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf
	    else
		echo "Set STARTUP_ENABLED=Yes in ${CONFDIR}/${PRODUCT}/${PRODUCT}.conf to enable"
	    fi
	else
	    cant_autostart
	fi
    elif [ "$INITFILE" != rc.f ]; then #Slackware starts this automatically
	cant_autostart
    fi
fi

#
# Report Success
#
echo "$Product Version $VERSION Installed"
