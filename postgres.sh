#!/bin/bash

# Function to handle errors
error_handler() {
    echo "ERROR: Script failed at line $1"
    exit 1
}

# Trap any error and call error_handler
trap 'error_handler $LINENO' ERR

echo "Starting RPM build process for PostgreSQL..."

# Install Prerequisites
echo "Installing prerequisites..."
sudo yum install -y rpm-build make gcc libtool wget readline-devel zlib-devel || error_handler $LINENO

# Download PostgreSQL Source Code
echo "Downloading PostgreSQL source code..."
wget https://ftp.postgresql.org/pub/source/v14.1/postgresql-14.1.tar.gz || error_handler $LINENO

# Prepare RPM Building Environment
echo "Preparing RPM building environment..."
mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS} || error_handler $LINENO

# Create Spec File
echo "Creating spec file..."
cat <<EOL > ~/rpmbuild/SPECS/postgresql.spec
%define version 14.1
%define release 1
%define debug_package %{nil}
Summary: PostgreSQL relational database management system
Name: postgresql
Version: %{version}
Release: %{release}
License: PostgreSQL
URL: https://www.postgresql.org/
Source0: https://ftp.postgresql.org/pub/source/v%{version}/postgresql-%{version}.tar.gz
BuildRequires: readline-devel, zlib-devel

%description
PostgreSQL is an advanced object-relational database management system (DBMS).

%prep
%setup -q -n postgresql-%{version}

%build
./configure --prefix=%{_prefix}
make

%install
make install DESTDIR=%{buildroot}

%files
%{_prefix}/bin/*
%{_prefix}/include/*
%{_prefix}/lib/*
# Conditionally include man pages if they exist
%exclude %{_prefix}/share/man/man1/*
/usr/share/postgresql/*
EOL

# Place Source Code
echo "Placing source code in build environment..."
mv postgresql-14.1.tar.gz ~/rpmbuild/SOURCES/ || error_handler $LINENO

# Build RPMs
echo "Building RPMs..."
rpmbuild -ba ~/rpmbuild/SPECS/postgresql.spec || error_handler $LINENO

# Install Resulting RPMs
echo "Installing resulting RPMs..."
sudo yum localinstall ~/rpmbuild/RPMS/x86_64/postgresql-14.1-1.x86_64.rpm --skip-broken || error_handler $LINENO

echo "PostgreSQL RPM build and installation complete."
