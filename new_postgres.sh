#!/bin/bash
LOG_FILE="/tmp/postgres_installation.log"
STEP_TRACKER="/tmp/postgres_install_step.log"
PG_VERSION="14.10"
PG_USER="postgres14"
PG_SERVICE_FILE="/etc/systemd/system/postgresql.service"
PG_SPEC_FILE="postgresql.spec"

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

error_handler() {
    log_message "ERROR: Script failed at step $1"
    echo "$1" > "$STEP_TRACKER"
    exit 1
}

check_step() {
    if [ -f "$STEP_TRACKER" ]; then
        LAST_STEP=$(cat "$STEP_TRACKER")
        if [ "$LAST_STEP" -ge "$1" ]; then
            log_message "Skipping step $1 as it was completed in a previous run."
            return 1 
        fi
    fi
    return 0 
}

service_running() {
    if systemctl is-active --quiet postgresql.service; then
        log_message "PostgreSQL service is already running."
        return 0
    else
        return 1
    fi
}

trap 'error_handler $LINENO' ERR

if check_step 1; then
    if [ ! -f "$PG_SERVICE_FILE" ]; then
        log_message "Step 1: Creating PostgreSQL service file..."
        cat <<EOF > "$PG_SERVICE_FILE"
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
    else
        log_message "PostgreSQL service file already exists."
    fi
    echo "1" > "$STEP_TRACKER"
fi

if check_step 2; then
    pg_config_version=$(pg_config --version | awk '{print $NF}')

    if [ "$pg_config_version" == "$PG_VERSION" ]; then
        echo "Postgres $PG_VERSION is already installed...."
    else
    log_message "Step 2: Installing the custom PostgreSQL RPM..."
        sudo yum install /tmp/postgresql-${PG_VERSION}* -y
        echo "2" > "$STEP_TRACKER"
    fi
fi

if check_step 3; then
    log_message "Step 3: Environment setup for PostgreSQL..."
    if [ ! -d "/usr/local/pgsql/data" ]; then
        sudo mkdir -p /usr/local/pgsql/data
        sudo adduser --system --home=/usr/local/pgsql --shell=/bin/bash $PG_USER
        sudo chown -R $PG_USER:$PG_USER /usr/local/pgsql/
        sudo su - $PG_USER -c '/usr/bin/initdb -D /usr/local/pgsql/data'
    else
        log_message "/usr/local/pgsql/data already exists."
    fi
    echo "3" > "$STEP_TRACKER"
fi

if check_step 4; then
    log_message "Step 4: Initializing and starting PostgreSQL..."
    if ! service_running; then
        sudo systemctl enable postgresql.service
        sudo systemctl start postgresql.service
    fi
    sudo systemctl status postgresql.service
    echo "4" > "$STEP_TRACKER"
fi

log_message "PostgreSQL RPM build, installation, and initial setup complete."

rm -f "$STEP_TRACKER"
