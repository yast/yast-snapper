#
# spec file for package yast2-snapper
#
# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#


Name:           yast2-snapper
Version:        3.1.0
Release:        0
Group:		System/YaST

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

License:        GPL-2.0
BuildRequires:	update-desktop-files yast2 yast2-testsuite libbtrfs-devel
BuildRequires:  yast2-devtools >= 3.0.6
BuildRequires:	libsnapper-devel >= 0.0.11
BuildRequires:	yast2-core-devel >= 2.23.1
BuildRequires:	libtool doxygen gcc-c++ perl-XML-Writer

Requires:	yast2 >= 2.21.22
Requires:       yast2-ruby-bindings >= 1.0.0

# require the version of libsnapper used during build (bnc#845618)
%requires_eq libsnapper2

Summary:	YaST - file system snapshots review

%description
YaST module for accessing and managing btrfs system snapshots

%prep
%setup -n %{name}-%{version}

%build
%yast_build

%install
%yast_install


%files
%defattr(-,root,root)
%dir %{yast_yncludedir}/snapper
%{yast_yncludedir}/snapper/*
%{yast_clientdir}/snapper.rb
%{yast_moduledir}/Snapper.*
%{yast_desktopdir}/snapper.desktop
%{yast_scrconfdir}/*.scr
%{yast_plugindir}/libpy2ag_snapper*
%doc %{yast_docdir}
