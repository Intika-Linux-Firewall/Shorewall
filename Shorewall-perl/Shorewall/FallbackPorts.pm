#
# Shorewall-perl 4.0 -- /usr/share/shorewall-perl/Shorewall/Ports.pm
#
#     This program is under GPL [http://www.gnu.org/copyleft/gpl.htm]
#
#     (c) 2007 - Tom Eastep (teastep@shorewall.net)
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
#       Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA
#
# This module exports the %protocols and %services hashes built from 
# /etc/protocols and /etc/services respectively.
#
# Module generated using buildports.pl 4.0.0-Beta7 - Fri Jun 29 14:10:45 2007
#
package Shorewall::Ports;

use strict;
use warnings;

our @ISA = qw(Exporter);
our @EXPORT = qw( %protocols %services );
our @EXPORT_OK = qw();
our $VERSION = '1.00';

our %protocols = (
		  ip			=> 0,
		  IP			=> 0,
		  icmp			=> 1,
		  ICMP			=> 1,
		  igmp			=> 2,
		  IGMP			=> 2,
		  ggp			=> 3,
		  GGP			=> 3,
		  ipencap		=> 4,
		  'IP-ENCAP'		=> 4,
		  st			=> 5,
		  ST			=> 5,
		  tcp			=> 6,
		  TCP			=> 6,
		  egp			=> 8,
		  EGP			=> 8,
		  igp			=> 9,
		  IGP			=> 9,
		  pup			=> 12,
		  PUP			=> 12,
		  udp			=> 17,
		  UDP			=> 17,
		  hmp			=> 20,
		  HMP			=> 20,
		  'xns-idp'		=> 22,
		  'XNS-IDP'		=> 22,
		  rdp			=> 27,
		  RDP			=> 27,
		  'iso-tp4'		=> 29,
		  'ISO-TP4'		=> 29,
		  xtp			=> 36,
		  XTP			=> 36,
		  ddp			=> 37,
		  DDP			=> 37,
		  'idpr-cmtp'		=> 38,
		  'IDPR-CMTP'		=> 38,
		  ipv6			=> 41,
		  IPv6			=> 41,
		  'ipv6-route'		=> 43,
		  'IPv6-Route'		=> 43,
		  'ipv6-frag'		=> 44,
		  'IPv6-Frag'		=> 44,
		  idrp			=> 45,
		  IDRP			=> 45,
		  rsvp			=> 46,
		  RSVP			=> 46,
		  gre			=> 47,
		  GRE			=> 47,
		  esp			=> 50,
		  'IPSEC-ESP'		=> 50,
		  ah			=> 51,
		  'IPSEC-AH'		=> 51,
		  skip			=> 57,
		  SKIP			=> 57,
		  'ipv6-icmp'		=> 58,
		  'IPv6-ICMP'		=> 58,
		  'ipv6-nonxt'		=> 59,
		  'IPv6-NoNxt'		=> 59,
		  'ipv6-opts'		=> 60,
		  'IPv6-Opts'		=> 60,
		  rspf			=> 73,
		  RSPF			=> 73,
		  CPHB			=> 73,
		  vmtp			=> 81,
		  VMTP			=> 81,
		  eigrp			=> 88,
		  EIGRP			=> 88,
		  ospf			=> 89,
		  OSPFIGP		=> 89,
		  'ax.25'		=> 93,
		  'AX.25'		=> 93,
		  ipip			=> 94,
		  IPIP			=> 94,
		  etherip		=> 97,
		  ETHERIP		=> 97,
		  encap			=> 98,
		  ENCAP			=> 98,
		  pim			=> 103,
		  PIM			=> 103,
		  ipcomp		=> 108,
		  IPCOMP		=> 108,
		  vrrp			=> 112,
		  VRRP			=> 112,
		  l2tp			=> 115,
		  L2TP			=> 115,
		  isis			=> 124,
		  ISIS			=> 124,
		  sctp			=> 132,
		  SCTP			=> 132,
		  fc			=> 133,
		  FC			=> 133,
		 );

our %services  = (
		  tcpmux		=> 1,
		  echo			=> 7,
		  discard		=> 9,
		  sink			=> 9,
		  null			=> 9,
		  systat		=> 11,
		  users			=> 11,
		  daytime		=> 13,
		  netstat		=> 15,
		  qotd			=> 17,
		  quote			=> 17,
		  msp			=> 18,
		  chargen		=> 19,
		  ttytst		=> 19,
		  source		=> 19,
		  'ftp-data'		=> 20,
		  ftp			=> 21,
		  fsp			=> 21,
		  fspd			=> 21,
		  ssh			=> 22,
		  telnet		=> 23,
		  smtp			=> 25,
		  mail			=> 25,
		  time			=> 37,
		  timserver		=> 37,
		  rlp			=> 39,
		  resource		=> 39,
		  nameserver		=> 42,
		  name			=> 42,
		  whois			=> 43,
		  nicname		=> 43,
		  tacacs		=> 49,
		  're-mail-ck'		=> 50,
		  domain		=> 53,
		  mtp			=> 57,
		  'tacacs-ds'		=> 65,
		  bootps		=> 67,
		  bootpc		=> 68,
		  tftp			=> 69,
		  gopher		=> 70,
		  rje			=> 77,
		  netrjs		=> 77,
		  finger		=> 79,
		  www			=> 80,
		  http			=> 80,
		  link			=> 87,
		  ttylink		=> 87,
		  kerberos		=> 88,
		  kerberos5		=> 88,
		  krb5			=> 88,
		  'kerberos-sec'	=> 88,
		  supdup		=> 95,
		  hostnames		=> 101,
		  hostname		=> 101,
		  'iso-tsap'		=> 102,
		  tsap			=> 102,
		  'acr-nema'		=> 104,
		  dicom			=> 104,
		  'csnet-ns'		=> 105,
		  'cso-ns'		=> 105,
		  rtelnet		=> 107,
		  pop2			=> 109,
		  postoffice		=> 109,
		  'pop-2'		=> 109,
		  pop3			=> 110,
		  'pop-3'		=> 110,
		  sunrpc		=> 111,
		  portmapper		=> 111,
		  auth			=> 113,
		  authentication	=> 113,
		  tap			=> 113,
		  ident			=> 113,
		  sftp			=> 115,
		  'uucp-path'		=> 117,
		  nntp			=> 119,
		  readnews		=> 119,
		  untp			=> 119,
		  ntp			=> 123,
		  pwdgen		=> 129,
		  'loc-srv'		=> 135,
		  epmap			=> 135,
		  'netbios-ns'		=> 137,
		  'netbios-dgm'		=> 138,
		  'netbios-ssn'		=> 139,
		  imap2			=> 143,
		  imap			=> 143,
		  snmp			=> 161,
		  'snmp-trap'		=> 162,
		  snmptrap		=> 162,
		  'cmip-man'		=> 163,
		  'cmip-agent'		=> 164,
		  mailq			=> 174,
		  xdmcp			=> 177,
		  nextstep		=> 178,
		  NeXTStep		=> 178,
		  NextStep		=> 178,
		  bgp			=> 179,
		  prospero		=> 191,
		  irc			=> 194,
		  smux			=> 199,
		  'at-rtmp'		=> 201,
		  'at-nbp'		=> 202,
		  'at-echo'		=> 204,
		  'at-zis'		=> 206,
		  qmtp			=> 209,
		  z3950			=> 210,
		  wais			=> 210,
		  ipx			=> 213,
		  imap3			=> 220,
		  pawserv		=> 345,
		  zserv			=> 346,
		  fatserv		=> 347,
		  rpc2portmap		=> 369,
		  codaauth2		=> 370,
		  clearcase		=> 371,
		  Clearcase		=> 371,
		  ulistserv		=> 372,
		  ldap			=> 389,
		  imsp			=> 406,
		  https			=> 443,
		  snpp			=> 444,
		  'microsoft-ds'	=> 445,
		  kpasswd		=> 464,
		  saft			=> 487,
		  isakmp		=> 500,
		  rtsp			=> 554,
		  nqs			=> 607,
		  'npmp-local'		=> 610,
		  dqs313_qmaster	=> 610,
		  'npmp-gui'		=> 611,
		  dqs313_execd		=> 611,
		  'hmmp-ind'		=> 612,
		  dqs313_intercell	=> 612,
		  ipp			=> 631,
		  exec			=> 512,
		  biff			=> 512,
		  comsat		=> 512,
		  login			=> 513,
		  who			=> 513,
		  whod			=> 513,
		  shell			=> 514,
		  cmd			=> 514,
		  syslog		=> 514,
		  printer		=> 515,
		  spooler		=> 515,
		  talk			=> 517,
		  ntalk			=> 518,
		  route			=> 520,
		  router		=> 520,
		  routed		=> 520,
		  timed			=> 525,
		  timeserver		=> 525,
		  tempo			=> 526,
		  newdate		=> 526,
		  courier		=> 530,
		  rpc			=> 530,
		  conference		=> 531,
		  chat			=> 531,
		  netnews		=> 532,
		  netwall		=> 533,
		  gdomap		=> 538,
		  uucp			=> 540,
		  uucpd			=> 540,
		  klogin		=> 543,
		  kshell		=> 544,
		  krcmd			=> 544,
		  afpovertcp		=> 548,
		  remotefs		=> 556,
		  rfs_server		=> 556,
		  rfs			=> 556,
		  nntps			=> 563,
		  snntp			=> 563,
		  submission		=> 587,
		  ldaps			=> 636,
		  tinc			=> 655,
		  silc			=> 706,
		  'kerberos-adm'	=> 749,
		  webster		=> 765,
		  rsync			=> 873,
		  'ftps-data'		=> 989,
		  ftps			=> 990,
		  telnets		=> 992,
		  imaps			=> 993,
		  ircs			=> 994,
		  pop3s			=> 995,
		  socks			=> 1080,
		  proofd		=> 1093,
		  rootd			=> 1094,
		  openvpn		=> 1194,
		  rmiregistry		=> 1099,
		  kazaa			=> 1214,
		  nessus		=> 1241,
		  lotusnote		=> 1352,
		  lotusnotes		=> 1352,
		  'ms-sql-s'		=> 1433,
		  'ms-sql-m'		=> 1434,
		  ingreslock		=> 1524,
		  'prospero-np'		=> 1525,
		  datametrics		=> 1645,
		  'old-radius'		=> 1645,
		  'sa-msg-port'		=> 1646,
		  'old-radacct'		=> 1646,
		  kermit		=> 1649,
		  l2f			=> 1701,
		  l2tp			=> 1701,
		  radius		=> 1812,
		  'radius-acct'		=> 1813,
		  radacct		=> 1813,
		  msnp			=> 1863,
		  'unix-status'		=> 1957,
		  'log-server'		=> 1958,
		  remoteping		=> 1959,
		  nfs			=> 2049,
		  'rtcm-sc104'		=> 2101,
		  cvspserver		=> 2401,
		  venus			=> 2430,
		  'venus-se'		=> 2431,
		  codasrv		=> 2432,
		  'codasrv-se'		=> 2433,
		  mon			=> 2583,
		  dict			=> 2628,
		  gpsd			=> 2947,
		  gds_db		=> 3050,
		  icpv2			=> 3130,
		  icp			=> 3130,
		  mysql			=> 3306,
		  nut			=> 3493,
		  distcc		=> 3632,
		  daap			=> 3689,
		  svn			=> 3690,
		  subversion		=> 3690,
		  iax			=> 4569,
		  'radmin-port'		=> 4899,
		  rfe			=> 5002,
		  mmcc			=> 5050,
		  sip			=> 5060,
		  'sip-tls'		=> 5061,
		  aol			=> 5190,
		  'xmpp-client'		=> 5222,
		  'jabber-client'	=> 5222,
		  'xmpp-server'		=> 5269,
		  'jabber-server'	=> 5269,
		  cfengine		=> 5308,
		  postgresql		=> 5432,
		  postgres		=> 5432,
		  x11			=> 6000,
		  'x11-0'		=> 6000,
		  'x11-1'		=> 6001,
		  'x11-2'		=> 6002,
		  'x11-3'		=> 6003,
		  'x11-4'		=> 6004,
		  'x11-5'		=> 6005,
		  'x11-6'		=> 6006,
		  'x11-7'		=> 6007,
		  'gnutella-svc'	=> 6346,
		  'gnutella-rtr'	=> 6347,
		  'afs3-fileserver'	=> 7000,
		  bbs			=> 7000,
		  'afs3-callback'	=> 7001,
		  'afs3-prserver'	=> 7002,
		  'afs3-vlserver'	=> 7003,
		  'afs3-kaserver'	=> 7004,
		  'afs3-volser'		=> 7005,
		  'afs3-errors'		=> 7006,
		  'afs3-bos'		=> 7007,
		  'afs3-update'		=> 7008,
		  'afs3-rmtsys'		=> 7009,
		  'font-service'	=> 7100,
		  xfs			=> 7100,
		  'bacula-dir'		=> 9101,
		  'bacula-fd'		=> 9102,
		  'bacula-sd'		=> 9103,
		  amanda		=> 10080,
		  hkp			=> 11371,
		  bprd			=> 13720,
		  bpdbm			=> 13721,
		  'bpjava-msvc'		=> 13722,
		  vnetd			=> 13724,
		  bpcd			=> 13782,
		  vopied		=> 13783,
		  wnn6			=> 22273,
		  kerberos4		=> 750,
		  'kerberos-iv'		=> 750,
		  kdc			=> 750,
		  kerberos_master	=> 751,
		  passwd_server		=> 752,
		  krb_prop		=> 754,
		  krb5_prop		=> 754,
		  hprop			=> 754,
		  krbupdate		=> 760,
		  kreg			=> 760,
		  swat			=> 901,
		  kpop			=> 1109,
		  knetd			=> 2053,
		  'zephyr-srv'		=> 2102,
		  'zephyr-clt'		=> 2103,
		  'zephyr-hm'		=> 2104,
		  eklogin		=> 2105,
		  kx			=> 2111,
		  iprop			=> 2121,
		  supfilesrv		=> 871,
		  supfiledbg		=> 1127,
		  linuxconf		=> 98,
		  poppassd		=> 106,
		  ssmtp			=> 465,
		  smtps			=> 465,
		  moira_db		=> 775,
		  moira_update		=> 777,
		  moira_ureg		=> 779,
		  spamd			=> 783,
		  omirr			=> 808,
		  omirrd		=> 808,
		  customs		=> 1001,
		  skkserv		=> 1178,
		  predict		=> 1210,
		  rmtcfg		=> 1236,
		  wipld			=> 1300,
		  xtel			=> 1313,
		  xtelw			=> 1314,
		  support		=> 1529,
		  sieve			=> 2000,
		  cfinger		=> 2003,
		  ndtp			=> 2010,
		  frox			=> 2121,
		  ninstall		=> 2150,
		  zebrasrv		=> 2600,
		  zebra			=> 2601,
		  ripd			=> 2602,
		  ripngd		=> 2603,
		  ospfd			=> 2604,
		  bgpd			=> 2605,
		  ospf6d		=> 2606,
		  ospfapi		=> 2607,
		  isisd			=> 2608,
		  afbackup		=> 2988,
		  afmbackup		=> 2989,
		  xtell			=> 4224,
		  fax			=> 4557,
		  hylafax		=> 4559,
		  distmp3		=> 4600,
		  munin			=> 4949,
		  lrrd			=> 4949,
		  'enbd-cstatd'		=> 5051,
		  'enbd-sstatd'		=> 5052,
		  pcrd			=> 5151,
		  noclog		=> 5354,
		  hostmon		=> 5355,
		  rplay			=> 5555,
		  rptp			=> 5556,
		  nsca			=> 5667,
		  mrtd			=> 5674,
		  bgpsim		=> 5675,
		  canna			=> 5680,
		  'sane-port'		=> 6566,
		  sane			=> 6566,
		  saned			=> 6566,
		  ircd			=> 6667,
		  'zope-ftp'		=> 8021,
		  webcache		=> 8080,
		  tproxy		=> 8081,
		  omniorb		=> 8088,
		  'clc-build-daemon'	=> 8990,
		  xinetd		=> 9098,
		  mandelspawn		=> 9359,
		  mandelbrot		=> 9359,
		  zope			=> 9673,
		  kamanda		=> 10081,
		  amandaidx		=> 10082,
		  amidxtape		=> 10083,
		  smsqp			=> 11201,
		  xpilot		=> 15345,
		  'sgi-cmsd'		=> 17001,
		  'sgi-crsd'		=> 17002,
		  'sgi-gcd'		=> 17003,
		  'sgi-cad'		=> 17004,
		  isdnlog		=> 20011,
		  vboxd			=> 20012,
		  binkp			=> 24554,
		  asp			=> 27374,
		  csync2		=> 30865,
		  dircproxy		=> 57000,
		  tfido			=> 60177,
		  fido			=> 60179,
		 );

1;
