#!/bin/bash
# scripts/start_hub.sh

# Exit on error
set -e

# Navigate to project root
cd "$(dirname "$0")/.."

# Load environment
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Log start
echo "[$(date)] Starting OTS Hub..."

# Check for virtualenv (common names)
if [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

# Run Uvicorn
# Bind to 0.0.0.0 (required for Cloudflare Tunnel to access if running in container, 
# or just good practice. Tunnel connects to localhost:8000 usually)
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --log-level info
