#!/bin/sh

### BEGIN INIT INFO
# Provides:          shorewall6-lite
# Required-Start:    $network $remote_fs
# Required-Stop:     $network $remote_fs
# Default-Start:     S
# Default-Stop:      0 6
# Short-Description: Configure the firewall at boot time
# Description:       Configure the firewall according to the rules specified in
#                    /etc/shorewall6-lite
### END INIT INFO

. /lib/lsb/init-functions

SRWL=/sbin/shorewall6-lite
SRWL_OPTS="-tvv"
test -n ${INITLOG:=/var/log/shorewall6-lite-init.log}

[ "$INITLOG" = "/dev/null" ] && SHOREWALL_INIT_SCRIPT=1 || SHOREWALL_INIT_SCRIPT=0

export SHOREWALL_INIT_SCRIPT

test -x $SRWL || exit 0
test -x $WAIT_FOR_IFUP || exit 0
test -n "$INITLOG" || {
	echo "INITLOG cannot be empty, please configure $0" ;
	exit 1;
}

if [ "$(id -u)" != "0" ]
then
  echo "You must be root to start, stop or restart \"Shorewall6 Lite firewall\"."
  exit 1
fi

echo_notdone () {

  if [ "$INITLOG" = "/dev/null" ] ; then
	  echo "not done."
  else
	  echo "not done (check $INITLOG)."
  fi

  exit 1
}

not_configured () {
	echo "#### WARNING ####"
	echo "the firewall won't be started/stopped unless it is configured"
	if [ "$1" != "stop" ]
	then
		echo ""
		echo "Please read about Debian specific customization in"
		echo "/usr/share/doc/shorewall6-lite/README.Debian.gz."
	fi
	echo "#################"
	exit 0
}

# parse the shorewall6 params file in order to use params in
# /etc/default/shorewall6
if [ -f "/etc/shorewall6-lite/params" ]
then
	. /etc/shorewall6-lite/params
fi

# check if shorewall is configured or not
if [ -f "/etc/default/shorewall6-lite" ]
then
	. /etc/default/shorewall6-lite
	SRWL_OPTS="$SRWL_OPTS $OPTIONS"
	if [ "$startup" != "1" ]
	then
		not_configured
	fi
else
	not_configured
fi

#
# The installer may alter this
#
. /usr/share/shorewall/shorewallrc

# start the firewall
shorewall6_start () {
  echo -n "Starting \"Shorewall6 Lite firewall\": "
  $SRWL $SRWL_OPTS start $STARTOPTIONS >> $INITLOG 2>&1 && echo "done." || echo_notdone
  return 0
}

# stop the firewall
shorewall6_stop () {
  echo -n "Stopping \"Shorewall6 Lite firewall\": "
  if [ "$SAFESTOP" = 1 ]; then
      $SRWL $SRWL_OPTS stop >> $INITLOG 2>&1 && echo "done." || echo_notdone
  else
      $SRWL $SRWL_OPTS clear >> $INITLOG 2>&1 && echo "done." || echo_notdone
  fi
  return 0
}

# restart the firewall
shorewall6_restart () {
  echo -n "Restarting \"Shorewall6 Lite firewall\": "
  $SRWL $SRWL_OPTS restart $RESTARTOPTIONS >> $INITLOG 2>&1 && echo "done." || echo_notdone
  return 0
}

# refresh the firewall
shorewall6_refresh () {
  echo -n "Refreshing \"Shorewall6 Lite firewall\": "
  $SRWL $SRWL_OPTS refresh >> $INITLOG 2>&1 && echo "done." || echo_notdone
  return 0
}

# status of the firewall
shorewall6_status () {
  $SRWL $SRWL_OPTS status && exit 0 || exit $?
}

case "$1" in
  start)
     shorewall6_start
     ;;
  stop)
     shorewall6_stop
     ;;
  refresh)
     shorewall6_refresh
     ;;
  force-reload|restart)
     shorewall6_restart
     ;;
  status)
     shorewall6_status
     ;;
  *)
     echo "Usage: /etc/init.d/shorewall6-lite {start|stop|refresh|restart|force-reload|status}"
     exit 1
esac

exit 0
