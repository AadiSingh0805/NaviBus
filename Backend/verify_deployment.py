#!/usr/bin/env python3
"""
Post-deployment verification script
Checks if bus stops were populated correctly
"""
import os
import django
import sys

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'navibus_backend.settings')
django.setup()

from core.models import Stop

def verify_deployment():
    """Verify that bus stops were populated correctly"""
    
    total_stops = Stop.objects.count()
    stops_with_coords = Stop.objects.filter(
        latitude__isnull=False, 
        longitude__isnull=False
    ).count()
    
    print(f"🔍 Deployment Verification:")
    print(f"  • Total stops in database: {total_stops}")
    print(f"  • Stops with GPS coordinates: {stops_with_coords}")
    print(f"  • Coverage: {(stops_with_coords/total_stops*100):.1f}%" if total_stops > 0 else "  • Coverage: 0%")
    
    if stops_with_coords >= 1000:  # Expecting around 1021 stops
        print("✅ SUCCESS: Bus stops populated correctly!")
        return True
    else:
        print("⚠️  WARNING: Less than expected number of stops with coordinates")
        return False

if __name__ == "__main__":
    verify_deployment()
