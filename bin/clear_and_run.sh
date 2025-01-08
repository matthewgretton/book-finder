#!/bin/bash

# Function to check if a command was successful
check_status() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed"
        exit 1
    fi
}

# Print start message
echo "Starting Rails setup process..."

# Clear Rails cache
echo "Clearing Rails cache..."
rails tmp:cache:clear
check_status "Cache clearing"

# Clean up old compiled assets
echo "Cleaning up old compiled assets..."
rails assets:clobber
check_status "Assets cleanup"

# Precompile assets
echo "Precompiling assets..."
rails assets:precompile
check_status "Assets precompilation"

# Start Rails server
echo "Starting Rails server..."
bin/rails server

# Note: The script will stay running with the server
# Use Ctrl+C to stop the server when needed