#!/usr/bin/env bash
# exit on error
set -o errexit

pip install -r requirements.txt

python manage.py collectstatic --no-input
python manage.py migrate

# Populate bus stops with GPS coordinates automatically
echo "🚌 Populating bus stops with GPS coordinates..."
python manage.py populate_stops

# Verify deployment
echo "🔍 Verifying deployment..."
python verify_deployment.py

echo "✅ Build completed successfully with bus stops populated!"
