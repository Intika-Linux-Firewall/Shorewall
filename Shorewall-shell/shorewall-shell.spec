%define name shorewall-shell
%define version 4.2.1
%define release 0base

Summary: Shoreline Firewall is an iptables-based firewall for Linux systems.
Name: %{name}
Version: %{version}
Release: %{release}
License: GPL
Packager: Tom Eastep <teastep@shorewall.net>
Group: Networking/Utilities
Source: %{name}-%{version}.tgz
URL: http://www.shorewall.net/
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Requires: iptables
Requires: iproute
Requires: shorewall-common >= 4.0.0-0RC1
Provides: shorewall_compiler = %{version}-%{release}
Provides: shorewall = %{version}-%{release}
Obsoletes: shorewall < 4.0.0-0Beta7

%description

The Shoreline Firewall, more commonly known as "Shorewall", is a Netfilter
(iptables) based firewall that can be used on a dedicated firewall system,
a multi-function gateway/ router/server or on a standalone GNU/Linux system.

Shorewall-shell is a part of Shorewall that alows running shorewall with
legacy configurations. Shorewall-perl is the preferred compiler, please use
it for new installations.

%prep

%setup

%build

%install
export PREFIX=$RPM_BUILD_ROOT ; \
export OWNER=`id -n -u` ; \
export GROUP=`id -n -g` ;\
./install.sh -n

%clean
rm -rf $RPM_BUILD_ROOT

%post

%preun

%postun

if [ "$1" -eq 0 -a -f /etc/shorewall/shorewall.conf ]; then
    sed -i.rpmsave -e 's/SHOREWALL_COMPILER=shell/SHOREWALL_COMPILER=/' /etc/shorewall/shorewall.conf
    if cmp -s /etc/shorewall/shorewall.conf.rpmsave /etc/shorewall/shorewall.conf; then
	rm -f /etc/shorewall/shorewall.conf.rpmsave
    else
	echo "/etc/shorewall/shorewall.conf modified - original saved as /etc/shorewall/shorewall.conf.rpmsave"
    fi 
fi

%files
%defattr(0644,root,root,0755)
%attr(0755,root,root) %dir /usr/share/shorewall-shell

%attr(0755,root,root) /usr/share/shorewall-shell/compiler
%attr(0644,root,root) /usr/share/shorewall-shell/lib.accounting
%attr(0644,root,root) /usr/share/shorewall-shell/lib.actions
%attr(0644,root,root) /usr/share/shorewall-shell/lib.maclist
%attr(0644,root,root) /usr/share/shorewall-shell/lib.nat
%attr(0644,root,root) /usr/share/shorewall-shell/lib.providers
%attr(0644,root,root) /usr/share/shorewall-shell/lib.proxyarp
%attr(0644,root,root) /usr/share/shorewall-shell/lib.tc
%attr(0644,root,root) /usr/share/shorewall-shell/lib.tcrules
%attr(0644,root,root) /usr/share/shorewall-shell/lib.tunnels
%attr(0644,root,root) /usr/share/shorewall-shell/prog.footer
%attr(0644,root,root) /usr/share/shorewall-shell/prog.header
%attr(0644,root,root) /usr/share/shorewall-shell/version

%doc COPYING INSTALL 

%changelog
* Wed Oct 08 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.1-0base
* Wed Oct 08 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0base
* Fri Oct 03 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0base
* Tue Sep 23 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0RC4
* Mon Sep 15 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0RC3
* Mon Sep 08 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0RC2
* Tue Aug 19 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0RC1
* Thu Jul 03 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0Beta3
* Mon Jun 02 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0Beta2
* Wed May 07 2008 Tom Eastep tom@shorewall.net
- Updated to 4.2.0-0Beta1
* Mon Apr 28 2008 Tom Eastep tom@shorewall.net
- Updated to 4.1.8-0base
* Mon Mar 24 2008 Tom Eastep tom@shorewall.net
- Updated to 4.1.7-0base
* Thu Mar 13 2008 Tom Eastep tom@shorewall.net
- Updated to 4.1.6-0base
* Tue Feb 05 2008 Tom Eastep tom@shorewall.net
- Updated to 4.1.5-0base
* Fri Jan 04 2008 Tom Eastep tom@shorewall.net
- Updated to 4.1.4-0base
* Wed Dec 12 2007 Tom Eastep tom@shorewall.net
- Updated to 4.1.3-0base
* Fri Dec 07 2007 Tom Eastep tom@shorewall.net
- Updated to 4.1.3-1
* Tue Nov 27 2007 Tom Eastep tom@shorewall.net
- Updated to 4.1.2-1
* Wed Nov 21 2007 Tom Eastep tom@shorewall.net
- Updated to 4.1.1-1
* Mon Nov 19 2007 Tom Eastep tom@shorewall.net
- Updated to 4.1.0-1
* Thu Nov 15 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.6-1
* Sat Nov 10 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.6-0RC3
* Thu Oct 25 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.6-0RC2
* Tue Oct 03 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.5-1
* Wed Sep 05 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.4-1
* Mon Aug 13 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.3-1
* Thu Aug 09 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.2-1
* Sat Jul 21 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.1-1
* Wed Jul 11 2007 Tom Eastep tom@shorewall.net
- Modify shorewall.conf on uninstall
- Updated to 4.0.0-1
* Sun Jul 08 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0RC2
* Fri Jun 29 2007 Tom EAstep tom@shorewall.net
- Updated to 4.0.0-0RC1
* Sun Jun 24 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta7
* Wed Jun 20 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta6
* Thu Jun 14 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta5
* Fri Jun 08 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta4
* Tue Jun 05 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta3
* Tue May 15 2007 Tom Eastep tom@shorewall.net
- Updated to 4.0.0-0Beta1
* Fri May 11 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.6-1
* Sat May 05 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.6-1
* Mon Apr 30 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.5-1
* Mon Apr 23 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.4-1
* Wed Apr 18 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.3-1
* Mon Apr 16 2007 Tom Eastep tom@shorewall.net
- Moved lib.dynamiczones to Shorewall-common
* Sat Apr 14 2007 Tom Eastep tom@shorewall.net
- Updated to 3.9.2-1
* Tue Apr 03 2007 Tom Eastep tom@shorewall.net
- Initial Version


