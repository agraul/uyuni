#
# spec file for package spacecmd
#
# Copyright (c) 2023 SUSE LLC
# Copyright (c) 2008-2018 Red Hat, Inc.
# Copyright (c) 2011 Aron Parsons <aronparsons@gmail.com>
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via https://bugs.opensuse.org/
#

Name:           spacecmd
Version:        5.0
Release:        1
Summary:        Command-line interface to Uyuni and SUSE Manager servers

License:        GPL-3.0-or-later
%if "%{_vendor}" == "debbuild"
Packager:       Uyuni packagers <devel@lists.uyuni-project.org>
Group:          admin
%else
Group:          Applications/System
%endif
URL:            https://github.com/uyuni-project/uyuni
Source:         https://github.com/spacewalkproject/spacewalk/archive/%{name}-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

BuildRequires:  make
%if "%{_vendor}" == "debbuild" || 0%{?rhel}
BuildRequires:  gettext
%endif
%if "%{_vendor}" == "debbuild"
BuildRequires:  intltool
%endif

BuildRequires:  python-rpm-macros
BuildRequires: %{python_module base >= 3.6}
BuildRequires: %{python_module devel >= 3.6}
Requires:       python-rpm
Requires:       python-dateutil
Requires:       file

%description
spacecmd is a command-line interface to Uyuni and SUSE Manager servers

%prep
%setup -q

%build
%pyproject_wheel

%install
%pyproject_install

%{__mkdir_p} %{buildroot}/%{_sysconfdir}
touch %{buildroot}/%{_sysconfdir}/spacecmd.conf

%{__mkdir_p} %{buildroot}/%{_sysconfdir}/bash_completion.d
%{__install} -p -m0644 src/misc/spacecmd-bash-completion %{buildroot}/%{_sysconfdir}/bash_completion.d/spacecmd


%{__mkdir_p} %{buildroot}/%{_mandir}/man1
%{__gzip} -c src/doc/spacecmd.1 > %{buildroot}/%{_mandir}/man1/spacecmd.1.gz

%python_clone %{buildroot}/%{_bindir}/spacecmd

make -C po install PREFIX=$RPM_BUILD_ROOT
%python_find_lang spacecmd

%files -f spacecmd.lang
%defattr(-,root,root)
%{_bindir}/spacecmd
%{python_sitelib}/spacecmd/
%ghost %config %{_sysconfdir}/spacecmd.conf
%dir %{_sysconfdir}/bash_completion.d
%{_sysconfdir}/bash_completion.d/spacecmd
%doc src/doc/README src/doc/COPYING
%doc %{_mandir}/man1/spacecmd.1.gz

%changelog
