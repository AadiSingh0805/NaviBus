#!/usr/bin/env python3
"""
Django management command to populate bus stops with GPS coordinates
Usage: python manage.py populate_stops
"""
from django.core.management.base import BaseCommand
from django.conf import settings
from core.models import Stop
import json
import os

class Command(BaseCommand):
    help = 'Populate bus stops with GPS coordinates from stop_coords.json'

    def handle(self, *args, **options):
        """Load bus stops with GPS coordinates from stop_coords.json"""
        
        # Look for the JSON file in the project root
        json_file_path = os.path.join(settings.BASE_DIR, 'stop_coords.json')
        
        if not os.path.exists(json_file_path):
            self.stdout.write(
                self.style.ERROR(f'Error: {json_file_path} not found!')
            )
            return
        
        try:
            with open(json_file_path, 'r', encoding='utf-8') as file:
                bus_stops_data = json.load(file)
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error reading JSON file: {e}')
            )
            return
        
        self.stdout.write(f"Found {len(bus_stops_data)} bus stops in stop_coords.json")
        
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
                    self.stdout.write(
                        self.style.WARNING(f'Skipping stop with unknown format: {stop_data}')
                    )
                    error_count += 1
                    continue
                
                # Validate data
                if not stop_name:
                    self.stdout.write(
                        self.style.WARNING(f'Skipping stop with empty name: {stop_data}')
                    )
                    error_count += 1
                    continue
                
                if latitude is None or longitude is None:
                    self.stdout.write(
                        self.style.WARNING(f'Skipping stop {stop_name} - missing coordinates')
                    )
                    error_count += 1
                    continue
                
                # Convert to float
                latitude = float(latitude)
                longitude = float(longitude)
                
                # Validate coordinate ranges
                if not (-90 <= latitude <= 90) or not (-180 <= longitude <= 180):
                    self.stdout.write(
                        self.style.WARNING(f'Invalid coordinates for {stop_name}: {latitude}, {longitude}')
                    )
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
                    self.stdout.write(f"✅ Created: {stop_name}")
                else:
                    # Update existing stop with new coordinates
                    if stop.latitude != latitude or stop.longitude != longitude:
                        stop.latitude = latitude
                        stop.longitude = longitude
                        stop.save()
                        updated_count += 1
                        self.stdout.write(f"🔄 Updated: {stop_name}")
                    else:
                        self.stdout.write(f"⏭️  Unchanged: {stop_name}")
                        
            except (ValueError, TypeError) as e:
                self.stdout.write(
                    self.style.ERROR(f'Error processing stop {stop_data}: {e}')
                )
                error_count += 1
                continue
            except Exception as e:
                self.stdout.write(
                    self.style.ERROR(f'Unexpected error for stop {stop_data}: {e}')
                )
                error_count += 1
                continue
        
        # Final summary
        self.stdout.write(
            self.style.SUCCESS(
                f'\n📊 Population Summary:\n'
                f'✅ Created: {created_count} stops\n'
                f'🔄 Updated: {updated_count} stops\n'
                f'❌ Errors: {error_count} stops\n'
                f'📍 Total in database: {Stop.objects.count()} stops'
            )
        )
        
        if error_count > 0:
            self.stdout.write(
                self.style.WARNING(f'⚠️  {error_count} stops had errors. Check the output above.')
            )
