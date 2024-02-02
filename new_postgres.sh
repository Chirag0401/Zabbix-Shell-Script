#!/bin/bash

# Define constants
LOG_FILE="/var/log/postgres_installation.log"
STEP_TRACKER="/var/log/postgres_install_step.log"
PG_VERSION="14.1"
PG_USER="postgres12"
PG_SERVICE_FILE="/etc/systemd/system/postgresql.service"
PG_SPEC_FILE="postgresql.spec"

# Function to log messages
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_handler() {
    log_message "ERROR: Script failed at step $1"
    echo "$1" > "$STEP_TRACKER"
    exit 1
}

# Function to check and proceed from the last successful step
check_step() {
    if [ -f "$STEP_TRACKER" ]; then
        LAST_STEP=$(cat "$STEP_TRACKER")
        if [ "$LAST_STEP" -ge "$1" ]; then
            log_message "Skipping step $1 as it was completed in a previous run."
            return 1 # Skip this step
        fi
    fi
    return 0 # Continue with this step
}

# Trap any error and call error_handler with the step number
trap 'error_handler $LINENO' ERR

# Step 1: Install prerequisites
if check_step 1; then
    log_message "Step 1: Installing prerequisites..."
    sudo yum install -y rpm-build make gcc libtool wget readline-devel zlib-devel
    echo "1" > "$STEP_TRACKER"
fi

# Step 2: Prepare RPM Building Environment
if check_step 2; then
    log_message "Step 2: Preparing RPM building environment..."
    mkdir -p ~/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
    echo "2" > "$STEP_TRACKER"
fi

# Step 3: Create PostgreSQL service file
if check_step 3; then
    log_message "Step 3: Creating PostgreSQL service file..."
    cat <<EOF > ~/rpmbuild/SOURCES/postgresql.service
[Unit]
Description=PostgreSQL database server
After=network.target

[Service]
Type=forking

User=$PG_USER

# Location of database directory
Environment=PGDATA=/usr/local/pgsql/data

ExecStart=/usr/bin/pg_ctl start -D \${PGDATA} -s -w -t 300
ExecStop=/usr/bin/pg_ctl stop -D \${PGDATA} -s -m fast
ExecReload=/usr/bin/pg_ctl reload -D \${PGDATA} -s

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300

[Install]
WantedBy=multi-user.target
EOF
    echo "3" > "$STEP_TRACKER"
fi

# Step 4: Create Spec File
if check_step 4; then
    log_message "Step 4: Creating spec file..."
    cat <<EOF > ~/rpmbuild/SPECS/$PG_SPEC_FILE
%define version $PG_VERSION
%define release 1
%define debug_package %{nil}
Summary: PostgreSQL relational database management system
Name: postgresql
Version: %{version}
Release: %{release}
License: PostgreSQL
URL: https://www.postgresql.org/
Source0: https://ftp.postgresql.org/pub/source/v%{version}/postgresql-%{version}.tar.gz
Source1: postgresql.service
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

# Install the systemd service file
install -Dm 644 %{_sourcedir}/postgresql.service %{buildroot}%{_unitdir}/postgresql.service

%files
%{_prefix}/bin/*
%{_prefix}/include/*
%{_prefix}/lib/*
%{_prefix}/share/man/man1/*
/usr/share/postgresql/*
%{_unitdir}/postgresql.service

%post
# Reload systemd to recognize the new service
/sbin/systemctl daemon-reload

%preun
# Only on uninstall, not on upgrade
if [ \$1 -eq 0 ] ; then
    /sbin/systemctl --no-reload disable postgresql.service > /dev/null 2>&1 || :
    /sbin/systemctl stop postgresql.service > /dev/null 2>&1 || :
fi

%postun
# Reload systemd after uninstall
/sbin/systemctl daemon-reload

%changelog
EOF
    echo "4" > "$STEP_TRACKER"
fi

# Step 5: Build and install the custom PostgreSQL RPM
if check_step 5; then
    log_message "Step 5: Building and installing the custom PostgreSQL RPM..."
    sudo yum install -y rpmdevtools && rpmdev-setuptree
    wget -P ~/rpmbuild/SOURCES/ https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.gz
    rpmbuild -ba ~/rpmbuild/SPECS/$PG_SPEC_FILE
    sudo yum localinstall ~/rpmbuild/RPMS/x86_64/postgresql-* -y
    echo "5" > "$STEP_TRACKER"
fi

# Step 6: Environment setup for PostgreSQL
if check_step 6; then
    log_message "Step 6: Environment setup for PostgreSQL..."
    sudo mkdir -p /usr/local/pgsql/data
    sudo adduser --system --home=/usr/local/pgsql --shell=/bin/bash $PG_USER
    sudo chown -R $PG_USER:$PG_USER /usr/local/pgsql/
    echo "6" > "$STEP_TRACKER"
fi

# Step 7: Initialize and start PostgreSQL
if check_step 7; then
    log_message "Step 7: Initializing and starting PostgreSQL..."
    sudo su - $PG_USER -c '/usr/bin/initdb -D /usr/local/pgsql/data'
    sudo su - $PG_USER -c '/usr/bin/pg_ctl -D /usr/local/pgsql/data -l logfile start'
    sudo su - $PG_USER -c '/usr/bin/pg_ctl -D /usr/local/pgsql/data status'
    echo "7" > "$STEP_TRACKER"
fi

log_message "PostgreSQL RPM build, installation, and initial setup complete."

# Clean up step tracker after successful execution
rm -f "$STEP_TRACKER"
