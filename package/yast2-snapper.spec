#
# spec file for package yast2-snapper
#
# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
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
Version:        4.0.6
Release:        0
Group:		System/YaST

# change to noarch causes problems according to behlert
# BuildArch:	noarch

BuildRoot:      %{_tmppath}/%{name}-%{version}-build
Source0:        %{name}-%{version}.tar.bz2

License:        GPL-2.0-only

BuildRequires:  doxygen
BuildRequires:  update-desktop-files
BuildRequires:  yast2
BuildRequires:  yast2-devtools >= 3.1.10
BuildRequires:  rubygem(%{rb_default_ruby_abi}:rspec)
BuildRequires:  rubygem(%{rb_default_ruby_abi}:ruby-dbus)
Requires:       snapper
Requires:       yast2 >= 2.21.22
Requires:       yast2-ruby-bindings >= 1.0.0
Requires:       rubygem(%{rb_default_ruby_abi}:ruby-dbus)
Supplements:    packageand(snapper:yast2)

Summary:	YaST - file system snapshots review
Url:            http://github.com/yast/yast-snapper/

%description
YaST module for accessing and managing file-system snapshots

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
%{yast_moduledir}/Snapper.rb
%{yast_moduledir}/SnapperDbus.rb
%{yast_desktopdir}/snapper.desktop
%{_datadir}/icons/*
%doc %{yast_docdir}
%license COPYING
