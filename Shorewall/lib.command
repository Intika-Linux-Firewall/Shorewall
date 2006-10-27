#!/bin/sh
#
# Shorewall 3.3 -- /usr/share/shorewall/lib.command
#
#     This program is under GPL [http://www.gnu.org/copyleft/gpl.htm]
#
#     (c) 1999,2000,2001,2002,2003,2004,2005,2006 - Tom Eastep (teastep@shorewall.net)
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
#	Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA
#
# This library contains the command processing code common to /sbin/shorewall and
# /sbin/shorewall-lite.
#

#
# Fatal Error
#
fatal_error() # $@ = Message
{
    echo "   $@" >&2
    exit 2
}

# Display a chain if it exists
#

showfirstchain() # $1 = name of chain
{
    awk \
    'BEGIN	 {prnt=0; rslt=1; }; \
    /^$/	 { next; };\
    /^Chain/	 {if ( prnt == 1 ) { rslt=0; exit 0; }; };\
    /Chain '$1'/ { prnt=1; }; \
		 { if (prnt == 1)  print; };\
    END		 { exit rslt; }' $TMPFILE
}

showchain() # $1 = name of chain
{
    if [ "$firstchain" = "Yes" ]; then
	if showfirstchain $1; then
	    firstchain=
	fi
    else
	awk \
	'BEGIN	     {prnt=0;};\
	/^$|^ pkts/  { next; };\
	/^Chain/     {if ( prnt == 1 ) exit; };\
	/Chain '$1'/ { prnt=1; };\
		     { if (prnt == 1)  print; }' $TMPFILE
    fi
}

#
# The 'awk' hack that compensates for bugs in iptables-save (or rather in the extension modules).
#

iptablesbug()
{
    if qt mywhich awk ; then
	awk 'BEGIN           { sline=""; };\
             /^-j/           { print sline $0; next };\
             /-m policy.*-j/ { print $0; next };\
             /-m policy/     { sline=$0; next };\
             /--mask ff/     { sub( /--mask ff/, "--mask 0xff" ) };\
                             { print ; sline="" }'
    else
	echo "   WARNING: You don't have 'awk' on this system so the output of the save command may be unusable" >&2
	cat
    fi
}

#
# Validate the value of RESTOREFILE
#
validate_restorefile() # $* = label
{
    case $RESTOREFILE in
	*/*)
	    error_message "ERROR: $@ must specify a simple file name: $RESTOREFILE"
	    exit 2
	    ;;
	.*)
	    error_message "ERROR: Reserved File Name: $RESTOREFILE"
	    exit 2
	    ;;
    esac
}

#
# Clear descriptor 1 if it is a terminal
#
clear_term() {
    [ -t 1 ] && clear
}

#
# Delay $timeout seconds -- if we're running on a recent bash2 then allow
# <enter> to terminate the delay
#
timed_read ()
{
    read -t $timeout foo 2> /dev/null

    test $? -eq 2 && sleep $timeout
}

#
# Display the last $1 packets logged
#
packet_log() # $1 = number of messages
{
    local options

    [ -n "$realtail" ] && options="-n$1"

    if [ -n "$SHOWMACS" -o $VERBOSE -gt 2 ]; then
	grep 'IN=.* OUT=' $LOGFILE | \
	    sed s/" kernel:"// | \
	    sed s/" $host $LOGFORMAT"/" "/ | \
	    tail $options
    else
	grep 'IN=.* OUT=' $LOGFILE | \
	    sed s/" kernel:"// | \
	    sed s/" $host $LOGFORMAT"/" "/ | \
	    sed 's/MAC=.* SRC=/SRC=/' | \
	    tail $options
    fi
}

#
# Show traffic control information
#
show_tc() {

    show_one_tc() {
	local device=${1%@*}
	qdisc=$(tc qdisc list dev $device)

	if [ -n "$qdisc" ]; then
	    echo Device $device:
	    tc -s -d qdisc show dev $device
	    tc -s -d class show dev $device
	    echo
	fi
    }

    ip link list | \
    while read inx interface details; do
	case $inx in
	[0-9]*)
	    show_one_tc ${interface%:}
	    ;;
	*)
	    ;;
	esac
    done

}

#
# Show classifier information
#
show_classifiers() {

    show_one_classifier() {
	local device=${1%@*}
	qdisc=$(tc qdisc list dev $device)

	if [ -n "$qdisc" ]; then
	    echo Device $device:
	    tc -s filter ls dev $device
	    echo
	fi
    }

    ip link list | \
    while read inx interface details; do
	case $inx in
	[0-9]*)
	    show_one_classifier ${interface%:}
	    ;;
	*)
	    ;;
	esac
    done

}

#
# Watch the Firewall Log
#
logwatch() # $1 = timeout -- if negative, prompt each time that
	   #		     an 'interesting' packet count changes
{

    host=$(echo $HOSTNAME | sed 's/\..*$//')
    oldrejects=$($IPTABLES -L -v -n | grep 'LOG')

    if [ $1 -lt 0 ]; then
	timeout=$((- $1))
	pause="Yes"
    else
	pause="No"
	timeout=$1
    fi

    qt mywhich awk && haveawk=Yes || haveawk=

    while true; do
	clear_term
	echo "$banner $(date)"
	echo

	echo "Dropped/Rejected Packet Log ($LOGFILE)"
	echo

	show_reset

	rejects=$($IPTABLES -L -v -n | grep 'LOG')

	if [ "$rejects" != "$oldrejects" ]; then
	    oldrejects="$rejects"

	    $RING_BELL

	    packet_log 40

	    if [ "$pause" = "Yes" ]; then
		echo
		echo $ECHO_N 'Enter any character to continue: '
		read foo
	    else
		timed_read
	    fi
	else
	    echo
	    packet_log 40
	    timed_read
	fi
    done
}

#
# Save currently running configuration
#
save_config() {
    if shorewall_is_started ; then
	[ -d ${VARDIR} ] || mkdir -p ${VARDIR}

	if [ -f $RESTOREPATH -a ! -x $RESTOREPATH ]; then
	    echo "   ERROR: $RESTOREPATH exists and is not a saved $PRODUCT configuration"
	else
	    case $RESTOREFILE in
		save|restore-base)
		    echo "   ERROR: Reserved file name: $RESTOREFILE"
		    ;;
		*)
		    if $IPTABLES -L dynamic -n > ${VARDIR}/save; then
			echo "   Dynamic Rules Saved"
			if [ -f ${VARDIR}/.restore ]; then
			    if iptables-save | iptablesbug > ${VARDIR}/restore-$$; then
				cp -f ${VARDIR}/.restore $RESTOREPATH
				mv -f ${VARDIR}/restore-$$ ${RESTOREPATH}-iptables
				chmod +x $RESTOREPATH
				echo "   Currently-running Configuration Saved to $RESTOREPATH"

				rm -f ${RESTOREPATH}-ipsets

				case ${SAVE_IPSETS:-No} in
				    [Yy][Ee][Ss])
					RESTOREPATH=${RESTOREPATH}-ipsets

					f=${VARDIR}/restore-$$

					echo "#!/bin/sh" > $f
					echo "#This ipset restore file generated $(date) by Shorewall $version" >> $f
					echo  >> $f
					echo ". ${SHAREDIR}/lib.base" >> $f
					echo  >> $f
					grep '^MODULE' ${VARDIR}/restore-base >>  $f
					echo "reload_kernel_modules << __EOF__" >> $f
					grep 'loadmodule ip_set' ${VARDIR}/restore-base >>  $f
					echo "__EOF__" >> $f
					echo  >> $f
					echo "ipset -U :all: :all:" >> $f
					echo "ipset -F" >> $f
					echo "ipset -X" >> $f
					echo "ipset -R << __EOF__" >> $f
					ipset -S >> $f
					echo "__EOF__" >> $f
					mv -f $f $RESTOREPATH
					chmod +x $RESTOREPATH
					echo "   Current Ipset Contents Saved to $RESTOREPATH"
					;;
				    [Nn][Oo])
					;;
				    *)
					echo "   WARNING: Invalid value ($SAVE_IPSETS) for SAVE_IPSETS. Ipset contents not saved"
					;;
				esac
			    else
			        rm -f ${VARDIR}/restore-$$
				echo "   ERROR: Currently-running Configuration Not Saved"
			    fi
			else
			    echo "   ERROR: ${VARDIR}/.restore does not exist"
			fi
		    else
		        echo "Error Saving the Dynamic Rules"
		    fi
		    ;;
	    esac
	fi
    else
	echo "Shorewall isn't started"
    fi

}

#
# Show routing configuration
#
show_routing() {
    if [ -n "$(ip rule ls)" ]; then
	heading "Routing Rules"
	ip rule ls
	ip rule ls | while read rule; do
	    echo ${rule##* }
	done | sort -u | while read table; do
	    heading "Table $table:"
	    ip route ls table $table
	done
    else
	heading "Routing Table"
	ip route ls
    fi
}

#
# Show Command Executor
#
show_command() {
    local finished=0

    while [ $finished -eq 0 -a $# -gt 0 ]; do
	option=$1
	case $option in
	    -*)
		option=${option#-}

		while [ -n "$option" ]; do
		    case $option in
			-)
			    finished=1
			    option=
			    ;;
			v*)
			    VERBOSE=$(($VERBOSE + 1 ))
			    option=${option#v}
			    ;;
			x*)
			    IPT_OPTIONS="-xnv"
			    option=${option#x}
			    ;;
			m*)
			    SHOWMACS=Yes
			    option=${option#m}
			    ;;
			f*)
			    FILEMODE=Yes
			    option=${option#f}
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

    [ -n "$debugging" ] && set -x
    case "$1" in
	connections)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Connections at $HOSTNAME - $(date)"
	    echo
	    cat /proc/net/ip_conntrack
	    ;;
	nat)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version NAT Table at $HOSTNAME - $(date)"
	    echo
	    show_reset
	    $IPTABLES -t nat -L $IPT_OPTIONS
	    ;;
	tos|mangle)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Mangle Table at $HOSTNAME - $(date)"
	    echo
	    show_reset
	    $IPTABLES -t mangle -L $IPT_OPTIONS
	    ;;
	log)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Log ($LOGFILE) at $HOSTNAME - $(date)"
	    echo
	    show_reset
	    host=$(echo $HOSTNAME | sed 's/\..*$//')
	    packet_log 20
	    ;;
	tc)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Traffic Control at $HOSTNAME - $(date)"
	    echo
	    show_tc
	    ;;
	classifiers)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Clasifiers at $HOSTNAME - $(date)"
	    echo
	    show_classifiers
	    ;;
	zones)
	    [ $# -gt 1 ] && usage 1
	    if [ -f ${VARDIR}/zones ]; then
		echo "$PRODUCT $version Zones at $HOSTNAME - $(date)"
		echo
		while read zone type hosts; do
		    echo "$zone ($type)"
		    for host in $hosts; do
			case $host in
			    exclude)
				echo "  exclude:"
				;;
			    *)
				echo "   $host"
				;;
			esac
		    done
		done < ${VARDIR}/zones
		echo
	    else
		echo "   ERROR: ${VARDIR}/zones does not exist" >&2
		exit 1
	    fi
	    ;;
	capabilities)
	    [ $# -gt 1 ] && usage 1
	    determine_capabilities
	    VERBOSE=2
	    if [ -n "$FILEMODE" ]; then
		report_capabilities1
	    else
		report_capabilities
	    fi
	    ;;
	ip)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version IP at $HOSTNAME - $(date)"
	    echo
	    ip addr ls
	    ;;
	routing)
	    [ $# -gt 1 ] && usage 1
	    echo "$PRODUCT $version Routing at $HOSTNAME - $(date)"
	    echo
	    show_routing
	    ;;
	config)
	    . ${SHAREDIR}/configpath
	    echo "Default CONFIG_PATH is $CONFIG_PATH"
	    echo "LITEDIR is $LITEDIR"
	    ;;
	*)
	    if [ "$PRODUCT" = Shorewall ]; then
		case $1 in
		    actions)
			[ $# -gt 1 ] && usage 1
			echo "allowBcast          # Silently Allow Broadcast/multicast"
			echo "dropBcast           # Silently Drop Broadcast/multicast"
			echo "dropNotSyn          # Silently Drop Non-syn TCP packets"
			echo "rejNotSyn           # Silently Reject Non-syn TCP packets"
			echo "dropInvalid         # Silently Drop packets that are in the INVALID conntrack state"
			echo "allowInvalid        # Accept packets that are in the INVALID conntrack state."
			echo "allowoutUPnP        # Allow traffic from local command 'upnpd'"
			echo "allowinUPnP         # Allow UPnP inbound (to firewall) traffic"
			echo "forwardUPnP         # Allow traffic that upnpd has redirected from"
			cat ${SHAREDIR}/actions.std ${CONFDIR}/actions | grep -Ev '^\#|^$'
			return
			;;
		    macros)
			[ $# -gt 1 ] && usage 1
			for macro in ${SHAREDIR}/macro.*; do
			    foo=`grep 'This macro' $macro | sed 's/This macro //'`
			    if [ -n "$foo" ]; then
				macro=${macro#*.}
				foo=${foo%.*}
				echo "   $macro  ${foo#\#}"
			    fi
			done
			return
			;;
		esac
	    fi

	    echo "$PRODUCT $version $([ $# -gt 0 ] && echo Chains || echo Chain) $* at $HOSTNAME - $(date)"
	    echo
	    show_reset
	    if [ $# -gt 0 ]; then
		for chain in $*; do
		    $IPTABLES -L $chain $IPT_OPTIONS
		done
	    else
		$IPTABLES -L $IPT_OPTIONS
	    fi
	    ;;
    esac
}

#
# Dump Command Executor
#
dump_command() {
    local finished=0

    while [ $finished -eq 0 -a $# -gt 0 ]; do
	option=$1
	case $option in
	    -*)
		option=${option#-}

		while [ -n "$option" ]; do
		    case $option in
			-)
			    finished=1
			    option=
			    ;;
			x*)
			    IPT_OPTIONS="-xnv"
			    option=${option#x}
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

    [ $VERBOSE -lt 2 ] && VERBOSE=2

    [ -n "$debugging" ] && set -x
    [ $# -eq 0 ] || usage 1
    clear_term
    echo "$PRODUCT $version Dump at $HOSTNAME - $(date)"
    echo
    show_reset
    host=$(echo $HOSTNAME | sed 's/\..*$//')
    $IPTABLES -L $IPT_OPTIONS

    heading "Log ($LOGFILE)"
    packet_log 20

    heading "NAT Table"
    $IPTABLES -t nat -L $IPT_OPTIONS

    heading "Mangle Table"
    $IPTABLES -t mangle -L $IPT_OPTIONS

    heading "Conntrack Table"
    cat /proc/net/ip_conntrack

    heading "IP Configuration"
    ip addr ls

    heading "IP Stats"
    ip -stat link ls

    if qt mywhich brctl; then
	heading "Bridges"
	brctl show
    fi

    heading "/proc"
    show_proc /proc/version
    show_proc /proc/sys/net/ipv4/ip_forward
    show_proc /proc/sys/net/ipv4/icmp_echo_ignore_all

    for directory in /proc/sys/net/ipv4/conf/*; do
	for file in proxy_arp arp_filter arp_ignore rp_filter log_martians; do
	    show_proc $directory/$file
	done
    done

    show_routing

    heading "ARP"
    arp -na

    if qt mywhich lsmod; then
	heading "Modules"
	lsmod | grep -E '^ip_|^ipt_|^iptable_'
    fi

    determine_capabilities
    echo
    report_capabilities

    if [ -n "$TC_ENABLED" ]; then
	heading "Traffic Control"
	show_tc
	heading "TC Filters"
	show_classifiers
	fi
}

#
# Restore Comand Executor
#
restore_command() {
    local finished=0

    while [ $finished -eq 0 -a $# -gt 0 ]; do
	option=$1
	case $option in
	    -*)
		option=${option#-}

		while [ -n "$option" ]; do
		    case $option in
			-)
			    finished=1
			    option=
			    ;;
			n*)
			    NOROUTES=Yes
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

    case $# in
    0)
	;;
    1)
	RESTOREFILE="$1"
	validate_restorefile '<restore file>'
	;;
    *)
	usage 1
	;;
    esac

    if [ -z "$STARTUP_ENABLED" ]; then
	error_message "ERROR: Startup is disabled"
	exit 2
    fi

    RESTOREPATH=${VARDIR}/$RESTOREFILE

    export NOROUTES

    [ -n "$nolock" ] || mutex_on

    if [ -x $RESTOREPATH ]; then
	if [ -x ${RESTOREPATH}-ipsets ] ; then
	    echo Restoring Ipsets...
	    iptables -F
	    iptables -X
	    $SHOREWALL_SHELL ${RESTOREPATH}-ipsets
	fi

	progress_message3 "Restoring Shorewall..."
	$SHOREWALL_SHELL $RESTOREPATH restore && progress_message3 "$PRODUCT restored from ${VARDIR}/$RESTOREFILE"
	[ -n "$nolock" ] || mutex_off
    else
	echo "File ${VARDIR}/$RESTOREFILE: file not found"
	[ -n "$nolock" ] || mutex_off
	exit 2
    fi
}

#
# Help information
#
help()
{
    [ -x $HELP ] && { export version; exec $HELP $*; }
    echo "Help subsystem is not installed at $HELP"
}

#
# Display the time that the counters were last reset
#
show_reset() {
    [ -f ${VARDIR}/restarted ] && \
	echo "Counters reset $(cat ${VARDIR}/restarted)" && \
	echo
}

#
# Display's the passed file name followed by "=" and the file's contents.
#
show_proc() # $1 = name of a file
{
    [ -f $1 ] && echo "   $1 = $(cat $1)"
}

read_yesno_with_timeout() {
    read -t 60 yn 2> /dev/null
    if [ $? -eq 2 ]
    then
	# read doesn't support timeout
	test -x /bin/bash || return 2 # bash is not installed so the feature is not available
	/bin/bash -c 'read -t 60 yn ; if [ "$yn" == "y" ] ; then exit 0 ; else exit 1 ; fi' # invoke bash and use its version of read
	return $?
    else
	# read supports timeout
	case "$yn" in
	    y|Y)
		return 0
		;;
	    *)
		return 1
		;;
	esac
    fi
}

#
# Print a heading with leading and trailing black lines
#
heading() {
    echo
    echo "$@"
    echo
}

#
# Create the appropriate -q option to pass onward
#
make_verbose() {
    local v=$VERBOSE_OFFSET option=-

    if [ $VERBOSE_OFFSET -gt 0 ]; then
	while [ $v -gt 0 ]; do
	    option="${option}v"
	    v=$(($v - 1))
	done

	echo $option
    elif [ $VERBOSE_OFFSET -lt 0 ]; then
	while [ $v -lt 0 ]; do
	    option="${option}q"
	    v=$(($v + 1))
	done

	echo $option
    fi
}

#
# Executor for drop,reject,... commands
#
block() # $1 = command, $2 = Finished, $3 = Original Command $4 - $n addresses
{
    local chain=$1 finished=$2

    shift 3

    while [ $# -gt 0 ]; do
	case $1 in
	    *-*)
		qt $IPTABLES -D dynamic -m iprange --src-range $1 -j reject
		qt $IPTABLES -D dynamic -m iprange --src-range  $1 -j DROP
		qt $IPTABLES -D dynamic -m iprange --src-range $1 -j logreject
		qt $IPTABLES -D dynamic -m iprange --src-range $1 -j logdrop
		$IPTABLES -A dynamic -m iprange --src-range $1 -j $chain || break 1
		;;
	    *)
		qt $IPTABLES -D dynamic -s $1 -j reject
		qt $IPTABLES -D dynamic -s $1 -j DROP
		qt $IPTABLES -D dynamic -s $1 -j logreject
		qt $IPTABLES -D dynamic -s $1 -j logdrop
		$IPTABLES -A dynamic -s $1 -j $chain || break 1
		;;
	esac

	echo "$1 $finished"
	shift
    done
}
