from django.db import migrations
from django.conf import settings
import json
import os

def populate_stops_from_json(apps, schema_editor):
    """Populate bus stops with GPS coordinates from stop_coords.json"""
    Stop = apps.get_model('core', 'Stop')
    
    # Look for the JSON file in the project root
    json_file_path = os.path.join(settings.BASE_DIR, 'stop_coords.json')
    
    if not os.path.exists(json_file_path):
        print(f'Warning: {json_file_path} not found! Skipping population.')
        return
    
    try:
        with open(json_file_path, 'r', encoding='utf-8') as file:
            bus_stops_data = json.load(file)
    except Exception as e:
        print(f'Error reading JSON file: {e}')
        return
    
    print(f"Found {len(bus_stops_data)} bus stops in stop_coords.json")
    
    created_count = 0
    updated_count = 0
    error_count = 0
    
    for stop_data in bus_stops_data:
        try:
            # Handle both formats: old (stop_name, latitude, longitude) and new (name, coords)
            if 'stop_name' in stop_data:
                # Old format
                stop_name = stop_data.get('stop_name', '').strip()
                latitude = stop_data.get('latitude')
                longitude = stop_data.get('longitude')
            elif 'name' in stop_data:
                # New format
                stop_name = stop_data.get('name', '').strip()
                coords = stop_data.get('coords')
                if coords and len(coords) >= 2:
                    latitude = coords[0]
                    longitude = coords[1]
                else:
                    latitude = None
                    longitude = None
            else:
                print(f'Skipping stop with unknown format: {stop_data}')
                error_count += 1
                continue
            
            # Validate data
            if not stop_name:
                print(f'Skipping stop with empty name: {stop_data}')
                error_count += 1
                continue
            
            if latitude is None or longitude is None:
                print(f'Skipping stop {stop_name} - missing coordinates')
                error_count += 1
                continue
            
            # Convert to float
            latitude = float(latitude)
            longitude = float(longitude)
            
            # Validate coordinate ranges
            if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
                print(f'Invalid coordinates for {stop_name}: {latitude}, {longitude}')
                error_count += 1
                continue
            
            # Create or update the stop
            stop, created = Stop.objects.get_or_create(
                name=stop_name,
                defaults={
                    'latitude': latitude,
                    'longitude': longitude
                }
            )
            
            if created:
                created_count += 1
                print(f"✅ Created: {stop_name}")
            else:
                # Update existing stop with new coordinates
                if stop.latitude != latitude or stop.longitude != longitude:
                    stop.latitude = latitude
                    stop.longitude = longitude
                    stop.save()
                    updated_count += 1
                    print(f"🔄 Updated: {stop_name}")
                        
        except (ValueError, TypeError) as e:
            print(f'Error processing stop {stop_data}: {e}')
            error_count += 1
            continue
        except Exception as e:
            print(f'Unexpected error for stop {stop_data}: {e}')
            error_count += 1
            continue
    
    # Final summary
    print(f'📊 Migration Population Summary:')
    print(f'✅ Created: {created_count} stops')
    print(f'🔄 Updated: {updated_count} stops')
    print(f'❌ Errors: {error_count} stops')
    print(f'📍 Total in database: {Stop.objects.count()} stops')

def reverse_populate_stops(apps, schema_editor):
    """Reverse migration - this would delete all stops, so we'll do nothing"""
    pass

class Migration(migrations.Migration):

    dependencies = [
        ('core', '0001_initial'),  # Replace with your latest migration
    ]

    operations = [
        migrations.RunPython(populate_stops_from_json, reverse_populate_stops),
    ]
