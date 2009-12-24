%define name shorewall6-lite
%define version 4.4.5
%define release 4

Summary: Shoreline Firewall 6 Lite is an ip6tables-based firewall for Linux systems.
Name: %{name}
Version: %{version}
Release: %{release}
License: GPLv2
Packager: Tom Eastep <teastep@shorewall.net>
Group: Networking/Utilities
Source: %{name}-%{version}.tgz
URL: http://www.shorewall.net/
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Requires: iptables iproute

%description

The Shoreline Firewall 6, more commonly known as "Shorewall6", is a Netfilter
(ip6tables) based firewall that can be used on a dedicated firewall system,
a multi-function gateway/ router/server or on a standalone GNU/Linux system.

Shorewall6 Lite is a companion product to Shorewall6 that allows network
administrators to centralize the configuration of Shorewall6-based firewalls.

%prep

%setup

%build

%install
export PREFIX=$RPM_BUILD_ROOT ; \
export OWNER=`id -n -u` ; \
export GROUP=`id -n -g` ;\
./install.sh

%clean
rm -rf $RPM_BUILD_ROOT

%pre

%post

if [ $1 -eq 1 ]; then
    if [ -x /sbin/insserv ]; then
	/sbin/insserv /etc/rc.d/shorewall6-lite
    elif [ -x /sbin/chkconfig ]; then
	/sbin/chkconfig --add shorewall6-lite;
    fi
fi

%preun

if [ $1 -eq 0 ]; then
    if [ -x /sbin/insserv ]; then
	/sbin/insserv -r /etc/init.d/shorewall6-lite
    elif [ -x /sbin/chkconfig ]; then
	/sbin/chkconfig --del shorewall6-lite
    fi
fi

%files
%defattr(0644,root,root,0755)
%attr(0755,root,root) %dir /etc/shorewall6-lite
%attr(0644,root,root) %config(noreplace) /etc/shorewall6-lite/shorewall6-lite.conf
%attr(0644,root,root) /etc/shorewall6-lite/Makefile
%attr(0544,root,root) /etc/init.d/shorewall6-lite
%attr(0755,root,root) %dir /usr/share/shorewall6-lite
%attr(0700,root,root) %dir /var/lib/shorewall6-lite

%attr(0644,root,root) /etc/logrotate.d/shorewall6-lite

%attr(0755,root,root) /sbin/shorewall6-lite

%attr(0644,root,root) /usr/share/shorewall6-lite/version
%attr(0644,root,root) /usr/share/shorewall6-lite/configpath
%attr(-   ,root,root) /usr/share/shorewall6-lite/functions
%attr(0644,root,root) /usr/share/shorewall6-lite/lib.base
%attr(0644,root,root) /usr/share/shorewall6-lite/lib.cli
%attr(0644,root,root) /usr/share/shorewall6-lite/modules
%attr(0544,root,root) /usr/share/shorewall6-lite/shorecap
%attr(0755,root,root) /usr/share/shorewall6-lite/wait4ifup

%attr(0644,root,root) %{_mandir}/man5/shorewall6-lite.conf.5.gz
%attr(0644,root,root) %{_mandir}/man5/shorewall6-lite-vardir.5.gz

%attr(0644,root,root) %{_mandir}/man8/shorewall6-lite.8.gz

%doc COPYING changelog.txt releasenotes.txt

%changelog
* Thu Dec 24 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.5-4
* Thu Dec 24 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.5-4
* Sun Dec 20 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.5-2
* Sat Dec 19 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.5-1
* Fri Nov 27 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.5-0base
* Sat Nov 21 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.4-0base
* Fri Nov 13 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.4-0Beta2
* Wed Nov 11 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.4-0Beta1
* Tue Nov 03 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.3-0base
* Sun Sep 06 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.2-0base
* Fri Sep 04 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.2-0base
* Fri Aug 14 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.1-0base
* Mon Aug 03 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0base
* Tue Jul 28 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0RC2
* Sun Jul 12 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0RC1
* Thu Jul 09 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0Beta4
* Sat Jun 27 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0Beta3
* Mon Jun 15 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0Beta2
* Fri Jun 12 2009 Tom Eastep tom@shorewall.net
- Updated to 4.4.0-0Beta1
* Sun Jun 07 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.13-0base
* Fri Jun 05 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.12-0base
* Sun May 10 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.11-0base
* Sun Apr 19 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.10-0base
* Sat Apr 11 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.9-0base
* Tue Mar 17 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.8-0base
* Sun Mar 01 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.7-0base
* Fri Feb 27 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.6-0base
* Sun Feb 22 2009 Tom Eastep tom@shorewall.net
- Updated to 4.3.5-0base
* Wed Feb 04 2009 Tom Eastep tom@shorewall.net
- Updated to 4.2.6-0base
* Thu Jan 29 2009 Tom Eastep tom@shorewall.net
- Updated to 4.2.6-0base
* Tue Jan 06 2009 Tom Eastep tom@shorewall.net
- Updated to 4.2.5-0base
* Thu Dec 25 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.4-0base
* Sun Dec 21 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.4-0RC2
* Wed Dec 17 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.4-0RC1
* Tue Dec 16 2008 Tom Eastep tom@shorewall.net
- Updated to 4.3.4-0base
* Sat Dec 13 2008 Tom Eastep tom@shorewall.net
- Updated to 4.3.3-0base
* Fri Dec 12 2008 Tom Eastep tom@shorewall.net
- Updated to 4.3.2-0base
* Thu Dec 11 2008 Tom Eastep tom@shorewall.net
- Updated to 4.3.1-0base
* Wed Dec 10 2008 Tom Eastep tom@shorewall.net
- Updated to 4.3.0-0base
* Wed Dec 10 2008 Tom Eastep tom@shorewall.net
- Updated to 2.3.0-0base
* Tue Dec 09 2008 Tom Eastep tom@shorewall.net
- Initial Version


