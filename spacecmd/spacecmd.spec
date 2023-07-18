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

%{?!python_module:%define python_module() python-%{**} python3-%{**}}

Name:           spacecmd
Version:        4.4.8
Release:        1
Summary:        Command-line interface to Uyuni and SUSE Manager servers

License:        GPL-3.0-or-later
%if "%{_vendor}" == "debbuild"
Packager:       Uyuni packagers <devel@lists.uyuni-project.org>
Group:          admin
%else
Group:          System/Management
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

# {python_module base} is only provided by *SUSE, devel pulls in what we need

%if "%{_vendor}" == "debbuild"
BuildRequires: %{python_module dev >= 3.6}
%else
BuildRequires: %{python_module devel >= 3.6}
%endif
BuildRequires: %{python_module pip}
BuildRequires: %{python_module wheel}
BuildRequires: fdupes
BuildRequires: python-rpm-macros
Requires:       python-rpm
Requires:       python-dateutil
Requires:       file
# Needs the fill path, see https://en.opensuse.org/openSUSE:Build_Service_cross_distribution_howto#update-alternatives_package_is_SUSE_only
Requires(post):   /usr/sbin/update-alternatives
Requires(postun): /usr/sbin/update-alternatives

%python_subpackages

%description
spacecmd is a command-line interface to Uyuni and SUSE Manager servers

%prep
%setup -q

%build
%python_build

%install
%python_install

%{__mkdir_p} %{buildroot}/%{_sysconfdir}
touch %{buildroot}/%{_sysconfdir}/spacecmd.conf

%{__mkdir_p} %{buildroot}/%{_datadir}/bash_completion.d
%{__install} -p -m0644 src/misc/spacecmd-bash-completion %{buildroot}/%{_datadir}/bash_completion.d/spacecmd

%{__mkdir_p} %{buildroot}/%{_mandir}/man1
%{__gzip} -c src/doc/spacecmd.1 > %{buildroot}/%{_mandir}/man1/spacecmd.1.gz

make -C po install PREFIX=$RPM_BUILD_ROOT
%find_lang spacecmd

%python_clone -a %{buildroot}/%{_bindir}/spacecmd
%python_expand %fdupes %{buildroot}%{$python_sitelib}


%post
%python_install_alternative spacecmd

%postun
%python_uninstall_alternative spacecmd

%files %{python_files} -f spacecmd.lang
%defattr(-,root,root)
%python_alternative %{_bindir}/spacecmd
%{python_sitelib}/spacecmd/
%{python_sitelib}/spacecmd-*-info/
%ghost %config %{_sysconfdir}/spacecmd.conf
%dir %{_datadir}/bash_completion.d
%{_datadir}/bash_completion.d/spacecmd
%doc src/doc/README
%license src/doc/COPYING
%doc %{_mandir}/man1/spacecmd.1.gz

%changelog
