#
# spec file for package rhnlib
#
# Copyright (c) 2024 SUSE LLC
# Copyright (c) 2008-2018 Red Hat, Inc.
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

# Goal:
# Build for:
# - SLE 15 with Python3.6 and Python3.11
# - SLE 12/RHEL 7 with Python 2.7
# - RHEL8 with platform Python

%{?!python_module:%define python_module() python-%{**} python3-%{**}}

%if "%{_vendor}" == "debbuild"
# For making sure we can set the right args for deb distros
%global is_deb 1
%endif

%{?sle15allpythons}
Name:           rhnlib
Version:        5.1.1
Release:        0
Summary:        Python libraries for the Spacewalk project
License:        GPL-2.0-only
URL:            https://github.com/uyuni-project/uyuni
Source0:        %{name}-%{version}.tar.gz
%if "%{_vendor}" == "debbuild"
Group:          python
Packager:       Uyuni Project <devel@lists.uyuni-project.org>
%endif
BuildArch:      noarch
BuildRequires:  make
BuildRequires:  python-rpm-macros
BuildRequires:  %{python_module devel}
BuildRequires:  %{python_module setuptools}

%define python_subpackage_only 1
%python_subpackages

%description
rhnlib is a collection of python modules used by the Spacewalk software.

%package -n python-rhnlib
Summary:        Python libraries for the Spacewalk project
Requires:       python-pyOpenSSL

Conflicts:      rhn-client-tools < 1.3.3
Conflicts:      rhn-custom-info < 5.4.7
Conflicts:      rhncfg < 5.10.45
Conflicts:      rhnclient < 0.10
Conflicts:      rhnpush < 5.5.10
Conflicts:      spacewalk-proxy < 1.3.6
Conflicts:      spacewalk-proxy-installer < 1.3.2
Provides:       rhnlib = %{version}-%{release}
Obsoletes:      rhnlib < %{version}-%{release}

%description -n python-rhnlib
rhnlib is a collection of python modules used by the Spacewalk software.

%prep 
%setup -q

# Recreate the rhn module
mkdir rhn
pushd rhn
for pyfile in $(ls ../*.py)
do
  ln -s $pyfile
done
popd

if [ ! -e setup.py ]; then
    sed -e 's/@VERSION@/%{version}/' -e 's/@NAME@/%{name}/' setup.py.in > setup.py
fi
if [ ! -e setup.cfg ]; then
    sed 's/@RELEASE@/%{release}/' setup.cfg.in > setup.cfg
fi

%build
# trailing ';' is required expand to executable and not flavor name
%python_expand make -f Makefile.rhnlib PYTHON=$python;

%install
%python_install

%if "%{_vendor}" == "debbuild"

%post -n python2-rhnlib
# Do late-stage bytecompilation, per debian policy
pycompile -p python2-rhnlib -V -3.0

%preun -n python2-rhnlib
# Ensure all *.py[co] files are deleted, per debian policy
pyclean -p python2-rhnlib

%if 0%{?build_py3}
%post -n python3-rhnlib
# Do late-stage bytecompilation, per debian policy
py3compile -p python3-rhnlib -V -4.0

%preun -n python3-rhnlib
# Ensure all *.py[co] files are deleted, per debian policy
py3clean -p python3-rhnlib
%endif
%endif

%files %{python_files rhnlib}
%defattr(-,root,root)
%license COPYING
%doc ChangeLog README TODO
%{python_sitelib}/rhn/*
%{python_sitelib}/rhnlib*

%changelog
