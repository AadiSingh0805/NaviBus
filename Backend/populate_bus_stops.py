#!/usr/bin/env python3
"""
Script to populate bus stops with GPS coordinates from temp.json
"""
import os
import django
import json
import sys

# Setup Django
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'navibus_backend.settings')
django.setup()

from core.models import Stop

def populate_bus_stops():
    """Load bus stops with GPS coordinates from stop_coords.json"""
    
    # Read the JSON file
    json_file_path = os.path.join(os.path.dirname(__file__), 'stop_coords.json')
    
    if not os.path.exists(json_file_path):
        print(f"Error: {json_file_path} not found!")
        return
    
    with open(json_file_path, 'r', encoding='utf-8') as file:
        bus_stops_data = json.load(file)
    
    print(f"Found {len(bus_stops_data)} bus stops in stop_coords.json")
    
    created_count = 0
    updated_count = 0
    error_count = 0
    
    for stop_data in bus_stops_data:
        try:
            name = stop_data['name']
            coordinates = stop_data['coords']
            
            # Skip if coordinates are None
            if coordinates is None:
                print(f"⚠️  Skipping {name} - missing coordinates")
                error_count += 1
                continue
                
            latitude = coordinates[0]
            longitude = coordinates[1]
            
            # Validate coordinate ranges
            if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
                print(f"⚠️  Invalid coordinates for {name}: {latitude}, {longitude}")
                error_count += 1
                continue
            
            # Check if stop already exists
            stop, created = Stop.objects.get_or_create(
                name=name,
                defaults={
                    'latitude': latitude,
                    'longitude': longitude
                }
            )
            
            if created:
                created_count += 1
                print(f"✅ Created: {name} ({latitude}, {longitude})")
            else:
                # Update coordinates if they were missing or different
                if stop.latitude is None or stop.longitude is None or stop.latitude != latitude or stop.longitude != longitude:
                    stop.latitude = latitude
                    stop.longitude = longitude
                    stop.save()
                    updated_count += 1
                    print(f"🔄 Updated: {name} with coordinates ({latitude}, {longitude})")
                else:
                    print(f"⏭️  Already exists: {name}")
                    
        except KeyError as e:
            print(f"❌ Error processing stop: {stop_data} - Missing key: {e}")
            error_count += 1
        except (ValueError, TypeError) as e:
            print(f"❌ Error processing stop: {stop_data} - Invalid data: {e}")
            error_count += 1
        except Exception as e:
            print(f"❌ Error processing stop: {stop_data} - {e}")
            error_count += 1
    
    print(f"\n📊 Summary:")
    print(f"  • Created: {created_count} stops")
    print(f"  • Updated: {updated_count} stops")
    print(f"  • Errors: {error_count} stops")
    print(f"  • Total stops in database: {Stop.objects.count()}")

if __name__ == "__main__":
    populate_bus_stops()
