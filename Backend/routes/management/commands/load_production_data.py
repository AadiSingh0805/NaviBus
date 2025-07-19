import os
import json
from django.core.management.base import BaseCommand
from django.core.management import call_command
from routes.models import BusRoute, RouteStop
from core.models import Stop

class Command(BaseCommand):
    help = 'Load production data from JSON file'

    def add_arguments(self, parser):
        parser.add_argument(
            '--file',
            type=str,
            default='production_data.json',
            help='JSON file containing the data to load'
        )

    def handle(self, *args, **options):
        file_path = options['file']
        
        if not os.path.exists(file_path):
            self.stdout.write(
                self.style.ERROR(f'File {file_path} does not exist')
            )
            return

        self.stdout.write('Loading production data...')
        
        try:
            call_command('loaddata', file_path)
            self.stdout.write(
                self.style.SUCCESS('Successfully loaded production data')
            )
            
            # Print statistics
            routes_count = BusRoute.objects.count()
            stops_count = Stop.objects.count()
            route_stops_count = RouteStop.objects.count()
            
            self.stdout.write(
                self.style.SUCCESS(
                    f'Data loaded: {routes_count} routes, {stops_count} stops, {route_stops_count} route-stops'
                )
            )
            
        except Exception as e:
            self.stdout.write(
                self.style.ERROR(f'Error loading data: {e}')
            )
