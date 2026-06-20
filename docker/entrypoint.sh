#!/bin/bash
set -e

# Wait for DB
echo "Waiting for DB..."
until pg_isready -h db -U auth_user -d auth_db; do
  sleep 1
done

# Wait for Redis
echo "Waiting for Redis..."
until redis-cli -h redis ping; do
  sleep 1
done

echo "Starting Rails..."
exec "$@"
