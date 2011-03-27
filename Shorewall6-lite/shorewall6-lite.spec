%define name shorewall6-lite
%define version 4.4.18
%define release 2

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
Provides: shoreline_firewall = %{version}-%{release}

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
export DESTDIR=$RPM_BUILD_ROOT ; \
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
%attr(0644,root,root) /usr/share/shorewall6-lite/lib.common
%attr(0644,root,root) /usr/share/shorewall6-lite/modules*
%attr(0644,root,root) /usr/share/shorewall6-lite/helpers
%attr(0544,root,root) /usr/share/shorewall6-lite/shorecap
%attr(0755,root,root) /usr/share/shorewall6-lite/wait4ifup

%attr(0644,root,root) %{_mandir}/man5/shorewall6-lite.conf.5.gz
%attr(0644,root,root) %{_mandir}/man5/shorewall6-lite-vardir.5.gz

%attr(0644,root,root) %{_mandir}/man8/shorewall6-lite.8.gz

%doc COPYING changelog.txt releasenotes.txt

%changelog
* Sun Mar 27 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-2
* Sat Mar 19 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-1
* Sun Mar 13 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-1
* Wed Mar 02 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0base
* Mon Feb 28 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0RC1
* Sun Feb 20 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0Beta4
* Sat Feb 19 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0Beta3
* Sun Feb 13 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0Beta2
* Sat Feb 05 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.18-0Beta1
* Fri Feb 04 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.17-0base
* Sun Jan 30 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.17-0RC1
* Fri Jan 28 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.17-0Beta3
* Wed Jan 19 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.17-0Beta2
* Sat Jan 08 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.17-0Beta1
* Mon Jan 03 2011 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0base
* Thu Dec 30 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0RC1
* Thu Dec 30 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta8
* Sun Dec 26 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta7
* Mon Dec 20 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta6
* Fri Dec 10 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta5
* Sat Dec 04 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta4
* Fri Dec 03 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta3
* Fri Dec 03 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta2
* Tue Nov 30 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.16-0Beta1
* Fri Nov 26 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.15-0base
* Mon Nov 22 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.15-0RC1
* Mon Nov 15 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.15-0Beta2
* Sat Oct 30 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.15-0Beta1
* Sat Oct 23 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0base
* Wed Oct 06 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0RC1
* Fri Oct 01 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0Beta4
* Sun Sep 26 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0Beta3
* Thu Sep 23 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0Beta2
* Tue Sep 21 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.14-0Beta1
* Fri Sep 17 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0RC1
* Fri Sep 17 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta6
* Mon Sep 13 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta5
* Sat Sep 04 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta4
* Mon Aug 30 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta3
* Wed Aug 25 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta2
* Wed Aug 18 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.13-0Beta1
* Sun Aug 15 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0base
* Fri Aug 06 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0RC1
* Sun Aug 01 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0Beta4
* Sat Jul 31 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0Beta3
* Sun Jul 25 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0Beta2
* Wed Jul 21 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.12-0Beta1
* Fri Jul 09 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.11-0base
* Mon Jul 05 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.11-0RC1
* Sat Jul 03 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.11-0Beta3
* Thu Jul 01 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.11-0Beta2
* Sun Jun 06 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.11-0Beta1
* Sat Jun 05 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0base
* Fri Jun 04 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0RC2
* Thu May 27 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0RC1
* Wed May 26 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0Beta4
* Tue May 25 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0Beta3
* Thu May 20 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0Beta2
* Thu May 20 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0Beta2
* Thu May 13 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.10-0Beta1
* Mon May 03 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0base
* Sun May 02 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0RC2
* Sun Apr 25 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0RC1
* Sat Apr 24 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0Beta5
* Fri Apr 16 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0Beta4
* Fri Apr 09 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0Beta3
* Thu Apr 08 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0Beta2
* Sat Mar 20 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.9-0Beta1
* Fri Mar 19 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.8-0base
* Tue Mar 16 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.8-0RC2
* Mon Mar 08 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.8-0RC1
* Sun Feb 28 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.8-0Beta2
* Thu Feb 11 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.8-0Beta1
* Fri Feb 05 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0base
* Tue Feb 02 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0RC2
* Wed Jan 27 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0RC1
* Mon Jan 25 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0Beta4
* Fri Jan 22 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0Beta3
* Fri Jan 22 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0Beta2
* Sun Jan 17 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.7-0Beta1
* Wed Jan 13 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.6-0base
* Tue Jan 12 2010 Tom Eastep tom@shorewall.net
- Updated to 4.4.6-0Beta1
* Thu Dec 24 2009 Tom Eastep tom@shorewall.net
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


