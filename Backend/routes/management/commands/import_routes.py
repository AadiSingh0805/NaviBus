import csv
import json

from django.core.management.base import BaseCommand
from core.models import Stop
from routes.models import BusRoute, RouteStop

class Command(BaseCommand):
    help = 'Import bus routes from a CSV file'

    def add_arguments(self, parser):
        parser.add_argument('csv_file', type=str, help=r'C:\Users\HP\VEDA\Projects\NaviBus\Backend\merged_routes.csv')

    def handle(self, *args, **options):
        csv_file_path = options['csv_file']

        def clean_stop_name(name):
            return name.strip().replace('"', '').replace('[', '').replace(']', '')

        def parse_stops(stops_str):
            try:
                stops = json.loads(stops_str)
                return [clean_stop_name(stop) for stop in stops]
            except Exception as e:
                self.stdout.write(self.style.WARNING(f"Failed to parse stops: {e}"))
                return []

        def get_or_create_stop(name):
            stop, _ = Stop.objects.get_or_create(name=name)
            return stop

        imported_count = 0
        skipped_count = 0

        with open(csv_file_path, newline='', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                route_number = row['Route Number'].strip()
                source_dest = row['Source and Destination'].strip()
                stop_names = parse_stops(row['Stops'])

                if not stop_names:
                    self.stdout.write(self.style.WARNING(f"No stops found for route {route_number}, skipping..."))
                    skipped_count += 1
                    continue

                start_stop = get_or_create_stop(stop_names[0])
                end_stop = get_or_create_stop(stop_names[-1])

                bus_route, created = BusRoute.objects.get_or_create(
                    route_number=route_number,
                    defaults={
                        'source_destination': source_dest,
                        'start_stop': start_stop,
                        'end_stop': end_stop,
                        'active': True
                    }
                )

                if not created:
                    self.stdout.write(self.style.WARNING(f"Route {route_number} already exists, skipping..."))
                    skipped_count += 1
                    continue

                for order, stop_name in enumerate(stop_names, start=1):
                    stop = get_or_create_stop(stop_name)
                    RouteStop.objects.create(
                        route=bus_route,
                        stop=stop,
                        stop_order=order
                    )

                self.stdout.write(self.style.SUCCESS(f"Added route {route_number} with {len(stop_names)} stops."))
                imported_count += 1

        self.stdout.write(self.style.SUCCESS(f"\nFinished! Imported: {imported_count}, Skipped: {skipped_count}"))
