import csv
import ast
from django.core.management.base import BaseCommand
from routes.models import BusRoute, RouteStop
from core.models import Stop

class Command(BaseCommand):
    help = 'Import routes from CSV'

    def add_arguments(self, parser):
        parser.add_argument('csv_file', type=str)

    def handle(self, *args, **options):
        csv_file_path = options['csv_file']

        with open(csv_file_path, newline='', encoding='utf-8') as csvfile:
            reader = csv.DictReader(csvfile)
            for row in reader:
                # Extract fields with flexible header names
                route_number = row.get("Route Number") or row.get("Route No") or row.get("Route") or row.get("Route Nu")
                source_dest = row.get("Source and Destination") or row.get("Route Name")
                stops_raw = row.get("Stops")

                if not (route_number and source_dest and stops_raw):
                    self.stdout.write(self.style.WARNING(f"Skipping row due to missing data: {row}"))
                    continue

                # Safely parse stops
                try:
                    stops = ast.literal_eval(stops_raw)
                    if not isinstance(stops, list):
                        raise ValueError("Stops is not a list")
                except:
                    stops = [s.strip() for s in stops_raw.split(",") if s.strip()]

                # Normalize arrows and split source/destination
                normalized = (source_dest.replace("→", "↔")
                                          .replace("←", "↔")
                                          .replace(" to ", "↔")
                                          .replace("-", "↔")
                                          .replace("—", "↔"))
                if "↔" in normalized:
                    parts = [s.strip() for s in normalized.split("↔", 1)]
                    if len(parts) != 2:
                        self.stdout.write(self.style.ERROR(f"Invalid split: {source_dest}"))
                        continue
                    source_name, dest_name = parts
                else:
                    self.stdout.write(self.style.ERROR(f"Invalid format in source/destination: {source_dest}"))
                    continue

                # Create or get Stop objects
                source_stop, _ = Stop.objects.get_or_create(name=source_name)
                dest_stop, _ = Stop.objects.get_or_create(name=dest_name)

                # Create BusRoute
                route, created = BusRoute.objects.get_or_create(
                    route_number=route_number,
                    defaults={
                        'start_stop': source_stop,
                        'end_stop': dest_stop
                    }
                )
                if not created:
                    route.start_stop = source_stop
                    route.end_stop = dest_stop
                    route.save()

                # Add intermediate stops
                for idx, stop_name in enumerate(stops):
                    stop_name = stop_name.strip()
                    if not stop_name:
                        continue
                    stop, _ = Stop.objects.get_or_create(name=stop_name)
                    RouteStop.objects.get_or_create(
                        route=route,
                        stop_order=idx,
                        defaults={
                            'stop': stop,
                            'distance_from_start': 0.0  # You can later update this if needed
                        }
                    )

                self.stdout.write(self.style.SUCCESS(f"Imported route: {route_number}"))
