import pandas as pd
from django.core.management.base import BaseCommand
from routes.models import BusRoute

class Command(BaseCommand):
    help = 'Check for existing routes with missing schedule data'

    def add_arguments(self, parser):
        parser.add_argument('excel_path', type=str, help=r'C:\Users\HP\VEDA\Projects\NaviBus\Backend\detail_routes.xls')

    def handle(self, *args, **kwargs):
        excel_path = kwargs['excel_path']
        try:
            df = pd.read_excel(excel_path)
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"Error reading Excel file: {e}"))
            return

        df.columns = [col.strip() for col in df.columns]

        for _, row in df.iterrows():
            route_number = str(row.get("Route Number", "")).strip()
            if not route_number:
                continue

            try:
                route = BusRoute.objects.get(route_number__iexact=route_number)
                missing_fields = []

                if not route.first_bus_time:
                    missing_fields.append("first_bus_time")
                if not route.last_bus_time:
                    missing_fields.append("last_bus_time")
                if not route.first_bus_time_sunday:
                    missing_fields.append("first_bus_time_sunday")
                if not route.last_bus_time_sunday:
                    missing_fields.append("last_bus_time_sunday")
                if route.frequency is None:
                    missing_fields.append("frequency")
                if route.fare is None:
                    missing_fields.append("fare")

                if missing_fields:
                    self.stdout.write(
                        self.style.WARNING(f"Route '{route_number}' is missing: {', '.join(missing_fields)}")
                    )

            except BusRoute.DoesNotExist:
                self.stdout.write(self.style.NOTICE(f"Route '{route_number}' not found in DB. Skipping..."))
