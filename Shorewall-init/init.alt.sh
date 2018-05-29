#!/bin/sh
#
# Shorewall init script
#
# chkconfig: - 09 91
# description: Initialize the shorewall firewall at boot time
#
### BEGIN INIT INFO
# Provides: shorewall-init
# Required-Start: $local_fs
# Required-Stop: $local_fs
# Default-Start: 3 4 5
# Default-Stop:  0 1 2 6
# Short-Description: Initialize the shorewall firewall at boot time
# Description:       Place the firewall in a safe state at boot time
#                    prior to bringing up the network.
### END INIT INFO

# Do not load RH compatibility interface.
WITHOUT_RC_COMPAT=1

# Source function library.
. /etc/init.d/functions

#
# The installer may alter this
#
. /usr/share/shorewall/shorewallrc
NAME="Shorewall-init firewall"
PROG="shorewall-init"
SHOREWALL="$SBINDIR/$PROG"
LOGGER="logger -i -t $PROG"

# Get startup options (override default)
OPTIONS=

LOCKFILE=/var/lock/subsys/shorewall-init

# check if shorewall-init is configured or not
if [ -f "/etc/sysconfig/shorewall-init" ]; then
	. /etc/sysconfig/shorewall-init
	if [ -z "$PRODUCTS" ]; then
		echo "No PRODUCTS configured"
		exit 6
	fi
else
	echo "/etc/sysconfig/shorewall-init not found"
	exit 6
fi

RETVAL=0

# set the STATEDIR variable
setstatedir() {
	local statedir
	if [ -f ${CONFDIR}/${PRODUCT}/vardir ]; then
		statedir=$( . /${CONFDIR}/${PRODUCT}/vardir && echo $VARDIR )
	fi

	[ -n "$statedir" ] && STATEDIR=${statedir} || STATEDIR=${VARLIB}/${PRODUCT}

	if [ -x ${STATEDIR}/firewall ]; then
		return 0
	elif [ $PRODUCT = shorewall ]; then
		${SBINDIR}/shorewall compile
	elif [ $PRODUCT = shorewall6 ]; then
		${SBINDIR}/shorewall -6 compile
	else
		return 1
	fi
}

start() {
	local PRODUCT
	local STATEDIR

	printf "Initializing \"Shorewall-based firewalls\": "

	for PRODUCT in $PRODUCTS; do
		if setstatedir; then
			$STATEDIR/$PRODUCT/firewall ${OPTIONS} stop 2>&1 | "$LOGGER"
			RETVAL=$?
		else
			RETVAL=6
			break
		fi
	done

	if [ -n "$SAVE_IPSETS" -a -f "$SAVE_IPSETS" ]; then
		ipset -R < "$SAVE_IPSETS"
	fi

	[ $RETVAL -eq 0 ] && touch "$LOCKFILE"
	return $RETVAL
}

stop() {
	local PRODUCT
	local STATEDIR

	printf "Clearing \"Shorewall-based firewalls\": "
	for PRODUCT in $PRODUCTS; do
		if setstatedir; then
			${STATEDIR}/firewall ${OPTIONS} clear 2>&1 | "$LOGGER"
			RETVAL=$?
		else
			RETVAL=6
			break
		fi
	done

	if [ -n "$SAVE_IPSETS" ]; then
		mkdir -p $(dirname "$SAVE_IPSETS")
		if ipset -S > "${SAVE_IPSETS}.tmp"; then
			grep -qE -- '^(-N|create )' "${SAVE_IPSETS}.tmp" && mv -f "${SAVE_IPSETS}.tmp" "$SAVE_IPSETS" || rm -f "${SAVE_IPSETS}.tmp"
		else
			rm -f "${SAVE_IPSETS}.tmp"
		fi
	fi

	[ $RETVAL -eq 0 ] && rm -f "$LOCKFILE"
	return $RETVAL
}

# See how we were called.
case "$1" in
	start)
	    start
	    ;;
	stop)
	    stop
	    ;;
	restart|reload|condrestart|condreload)
	    # "Not implemented"
	    ;;
	condstop)
	    if [ -e "$LOCKFILE" ]; then
		stop
	    fi
	    ;;
	status)
	    status "$PROG"
	     RETVAL=$?
	    ;;
	*)
	    echo $"Usage: ${0##*/}  {start|stop|restart|reload|condrestart|condstop|status}"
	    RETVAL=1
esac

exit $RETVAL
