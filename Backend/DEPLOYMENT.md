# NaviBus Backend Deployment Guide

## Automated Deployment to Render

This backend is configured for **automatic deployment** to Render when you push to GitHub.

### 🚀 How It Works

1. **Push to GitHub** → Render automatically detects changes
2. **Build Script** → Runs `build.sh` which:
   - Installs dependencies
   - Collects static files
   - Runs database migrations
   - **Automatically populates bus stops with GPS coordinates**
   - Verifies deployment success

### 📁 Key Files

- `build.sh` - Main build script that runs on Render
- `render.yaml` - Render deployment configuration
- `core/management/commands/populate_stops.py` - Django management command for GPS data
- `populate_bus_stops.py` - Standalone script for local testing
- `verify_deployment.py` - Post-deployment verification
- `stop_coords.json` - GPS coordinates data (1021+ stops)

### 🔄 Deployment Process

```bash
# 1. Make your changes locally
git add .
git commit -m "Your changes"

# 2. Push to GitHub (triggers automatic deployment)
git push origin main

# 3. Render automatically:
#    - Pulls latest code
#    - Runs build.sh
#    - Populates bus stops with GPS coordinates
#    - Starts the server
```

### 📊 What Gets Populated

- **1021+ bus stops** with GPS coordinates
- **Nearby stops API** ready for Flutter app
- **Route data** integration
- **Database optimization** for GPS queries

### 🔍 Monitoring Deployment

1. **GitHub Actions** - Check workflow status
2. **Render Dashboard** - Monitor build logs
3. **Deployment Verification** - Automatic success check

### 📱 API Endpoints Ready

After deployment, these endpoints are automatically available:
- `GET /api/stops/nearby/?lat=19.031784&lng=73.0994121&radius=2` - Find nearby stops
- `GET /api/stops/` - List all stops
- `GET /api/routes/` - List all routes

### 🛠️ Manual Population (if needed)

If you need to manually populate data on Render:

```bash
# Access Render console and run:
python manage.py populate_stops
```

### ✅ Success Indicators

- Build completes without errors
- Verification shows 1000+ stops with coordinates
- API endpoints return GPS data
- Flutter app can find nearby stops

**No manual intervention required!** Just push to GitHub and everything happens automatically.
