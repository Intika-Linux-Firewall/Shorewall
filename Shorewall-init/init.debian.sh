#!/bin/sh
#
#     The Shoreline Firewall (Shorewall) Packet Filtering Firewall - V5.2
#
#     This program is under GPL [http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt]
#
#     (c) 2010,2012 - Tom Eastep (teastep@shorewall.net)
#
#       On most distributions, this file should be called /etc/init.d/shorewall.
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
### BEGIN INIT INFO
# Provides:          shorewall-init
# Required-Start:    $local_fs
# X-Start-Before:    $network
# Required-Stop:     $local_fs
# X-Stop-After:      $network
# Default-Start:     S
# Default-Stop:      0 1 6
# Short-Description: Initialize the firewall at boot time
# Description:       Place the firewall in a safe state at boot time prior to
#                    bringing up the network
### END INIT INFO

. /lib/lsb/init-functions

export VERBOSITY=0

if [ "$(id -u)" != "0" ]
then
  echo "You must be root to start, stop or restart \"Shorewall \"."
  exit 1
fi

echo_notdone () {
  echo "not done."
  exit 1
}

not_configured () {
    echo "#### WARNING ####"
    echo "the firewall won't be initialized unless it is configured"
    if [ "$1" != "stop" ]
    then
	echo ""
	echo "Please read about Debian specific customization in"
	echo "/usr/share/doc/shorewall-init/README.Debian.gz."
    fi
    echo "#################"
    exit 0
}

# set the STATEDIR variable
setstatedir() {
    local statedir
    if [ -f ${CONFDIR}/${PRODUCT}/vardir ]; then
	statedir=$( . /${CONFDIR}/${PRODUCT}/vardir && echo $VARDIR )
    fi

    [ -n "$statedir" ] && STATEDIR=${statedir} || STATEDIR=${VARLIB}/${PRODUCT}

    if [ -x ${STATEDIR}/firewall ]; then
        return 0
    else
        if [ $PRODUCT = shorewall ]; then
            ${SBINDIR}/shorewall compile
        elif [ $PRODUCT = shorewall6 ]; then
            ${SBINDIR}/shorewall -6 compile
        else
            return 1
        fi
    fi
}

#
# The installer may alter this
#
. /usr/share/shorewall/shorewallrc

# check if shorewall-init is configured or not
if [ -f "$SYSCONFDIR/shorewall-init" ]
then
    . $SYSCONFDIR/shorewall-init
    if [ -z "$PRODUCTS" ]
    then
	not_configured
    fi
else
    not_configured
fi

# Initialize the firewall
shorewall_start () {
  local PRODUCT
  local STATEDIR

  printf "Initializing \"Shorewall-based firewalls\": "

  for PRODUCT in $PRODUCTS; do
      if setstatedir; then
          #
	  # Run in a sub-shell to avoid name collisions
	  #
	  (
	      if ! ${STATEDIR}/firewall status > /dev/null 2>&1; then
		  ${STATEDIR}/firewall ${OPTIONS} stop
	      fi
	  )
      fi
  done

  echo "done."

  if [ -n "$SAVE_IPSETS" -a -f "$SAVE_IPSETS" ]; then

      printf "Restoring ipsets: "

      if ! ipset -R < "$SAVE_IPSETS"; then
	  echo_notdone
      fi

      echo "done."
  fi

  return 0
}

# Clear the firewall
shorewall_stop () {
  local PRODUCT
  local STATEDIR

  printf "Clearing \"Shorewall-based firewalls\": "
  for PRODUCT in $PRODUCTS; do
      if setstatedir; then
	  ${STATEDIR}/firewall ${OPTIONS} clear
      fi
  done

  echo "done."

  if [ -n "$SAVE_IPSETS" ]; then

      echo "Saving ipsets: "

      mkdir -p $(dirname "$SAVE_IPSETS")
      if ipset -S > "${SAVE_IPSETS}.tmp"; then
	  grep -qE -- '^(-N|create )' "${SAVE_IPSETS}.tmp" && mv -f "${SAVE_IPSETS}.tmp" "$SAVE_IPSETS" || rm -f "${SAVE_IPSETS}.tmp"
      else
	  rm -f "${SAVE_IPSETS}.tmp"
	  echo_notdone
      fi

      echo "done."
  fi

  return 0
}

case "$1" in
  start)
     shorewall_start
     ;;
  stop)
     shorewall_stop
     ;;
  reload|force-reload)
     ;;
  *)
     echo "Usage: $0 {start|stop|reload|force-reload}"
     exit 1
esac

exit 0
