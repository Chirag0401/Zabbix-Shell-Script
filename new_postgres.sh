#!/bin/bash

# Define constants
LOG_FILE="/tmp/postgres_installation.log"
STEP_TRACKER="/tmp/postgres_install_step.log"
PG_VERSION="14.10"
PG_USER="postgres14"
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


# Step 1: Create PostgreSQL service file
if check_step 1; then
    log_message "Step 1: Creating PostgreSQL service file..."
    cat <<EOF > /etc/systemd/system/postgresql.service
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
    echo "1" > "$STEP_TRACKER"
fi

# Step 2: Build and install the custom PostgreSQL RPM
if check_step 2; then
    log_message "Step 2: Building and installing the custom PostgreSQL RPM..."
    # sudo yum install -y rpmdevtools && rpmdev-setuptree
   # wget -P ~/rpmbuild/SOURCES/ https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.gz
    # rpmbuild -ba ~/rpmbuild/SPECS/$PG_SPEC_FILE
    sudo yum install /tmp/postgresql-${PG_VERSION}* -y
    echo "2" > "$STEP_TRACKER"
fi

# Step 3: Environment setup for PostgreSQL
if check_step 3; then
    log_message "Step 3: Environment setup for PostgreSQL..."
    sudo mkdir -p /usr/local/pgsql/data
    sudo adduser --system --home=/usr/local/pgsql --shell=/bin/bash $PG_USER
    sudo chown -R $PG_USER:$PG_USER /usr/local/pgsql/
    echo "3" > "$STEP_TRACKER"
fi

# Step 4: Initialize and start PostgreSQL
if check_step 4; then
    log_message "Step 4: Initializing and starting PostgreSQL..."
    sudo su - $PG_USER -c '/usr/bin/initdb -D /usr/local/pgsql/data'
    # sudo su - $PG_USER -c '/usr/bin/pg_ctl -D /usr/local/pgsql/data -l logfile start'
    # sudo su - $PG_USER -c '/usr/bin/pg_ctl -D /usr/local/pgsql/data status'
    sudo systemctl start postgresql.service
    sudo systemctl status postgresql.service
    echo "4" > "$STEP_TRACKER"
fi

log_message "PostgreSQL RPM build, installation, and initial setup complete."

# Clean up step tracker after successful execution
rm -f "$STEP_TRACKER"
