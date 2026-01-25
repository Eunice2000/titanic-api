#!/bin/bash
set -e

# Function to wait for database
wait_for_db() {
    echo "Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}..."
    
    # Parse DB_HOST and DB_PORT from DATABASE_URL if not set
    if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ]; then
        if [ -n "$DATABASE_URL" ]; then
            # Extract host and port from DATABASE_URL
            # Format: postgresql://user:password@host:port/database
            DB_HOST=$(echo $DATABASE_URL | sed -e 's|.*@||' -e 's|:.*||')
            DB_PORT=$(echo $DATABASE_URL | sed -e 's|.*:||' -e 's|/.*||')
        else
            DB_HOST="localhost"
            DB_PORT="5432"
        fi
    fi
    
    until nc -z $DB_HOST $DB_PORT; do
        echo "PostgreSQL is unavailable - sleeping"
        sleep 2
    done
    
    echo "PostgreSQL is up and running!"
}

# Wait for database
wait_for_db

# Run database migrations if needed
# In a real production app, you would run:
# flask db upgrade

# Start the application with Gunicorn
echo "Starting Titanic API..."
exec gunicorn \
    --bind 0.0.0.0:5000 \
    --workers 4 \
    --worker-class sync \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    "app:create_app('production')"
