from django.core.management.base import BaseCommand
from django.utils.dateparse import parse_time
from routes.models import BusRoute
import pandas as pd
import os
import datetime
import re

class Command(BaseCommand):
    help = 'Import detailed route info from Excel and update BusRoute fields'

    def add_arguments(self, parser):
        parser.add_argument(
            'excel_file',
            type=str,
            help='Full path to the Excel file (e.g., D:/NMMT_FLUTTER/NaviBus/Backend/copied_detailed_routes.xlsx)'
        )
        
    def handle(self, *args, **kwargs):
        file_path = kwargs['excel_file']

        if not os.path.exists(file_path):
            self.stderr.write(self.style.ERROR(f"❌ File not found: {file_path}"))
            return

        try:
            df = pd.read_excel(file_path, header=0)
            df.columns = df.columns.str.strip()
            print(f"🔍 Columns from Excel: {df.columns.tolist()}")
        except Exception as e:
            self.stderr.write(self.style.ERROR(f"❌ Error reading Excel: {e}"))
            return

        def safe_time(val):
            if pd.isna(val):
                return None
            if isinstance(val, datetime.time):
                return val
            if isinstance(val, datetime.datetime):
                return val.time()
            val_str = str(val).strip().replace('.', ':').replace('::', ':')

            if val_str.isdigit() and len(val_str) in [3, 4]:
                val_str = val_str[:-2] + ":" + val_str[-2:]

            try:
                return pd.to_datetime(val_str).time()
            except:
                try:
                    return parse_time(val_str)
                except:
                    return None

        def safe_freq(val, context=""):
            if pd.isna(val):
                print(f"[{context}] Frequency is NaN")
                return None
            s = str(val).lower()
            s = s.replace('–', '-').replace('−', '-').replace('mins', '').replace('min', '').replace('approx', '').replace('…', '')
            numbers = re.findall(r'\d+(?:\.\d+)?', s)
            if not numbers:
                print(f"[{context}] No numbers found in string: '{s}'")
                return None
            nums = [float(n) for n in numbers]
            avg = round(sum(nums) / len(nums))
            print(f"[{context}] Parsed frequency: {nums} -> Avg: {avg}")
            return avg

        def safe_fare(val):
            if pd.isna(val):
                return None
            s = str(val).replace('Rs.', '').replace('₹', '').replace(',', '').strip()
            try:
                return float(s)
            except ValueError:
                print(f"⚠️ Unable to parse fare value: '{val}'")
                return None

        updated, skipped = 0, 0

        for idx, row in df.iterrows():
            route_no = row.get('Route No.') or row.get('Route No')
            if pd.isna(route_no):
                self.stderr.write(self.style.WARNING(f"⚠️ Row {idx+2}: missing Route No. — skipping"))
                skipped += 1
                continue

            route_no = str(route_no).strip()
            try:
                route = BusRoute.objects.get(route_number=route_no)
            except BusRoute.DoesNotExist:
                self.stderr.write(self.style.WARNING(f"⚠️ Route {route_no} not found — skipping"))
                skipped += 1
                continue

            freq_weekday_raw = row.get('Frequency (in Minutes)')
            freq_sunday_raw = row.get('Frequency (in Minutes).1')

            print(f"\n--- 🚌 Route {route_no} ---")
            print(f"⏱ Weekday Freq Raw: {freq_weekday_raw}")
            print(f"⏱ Sunday Freq Raw: {freq_sunday_raw}")

            route.first_bus_time_weekday    = safe_time(row.get('Frist Bus Time'))
            route.first_bus_time_sunday     = safe_time(row.get('Frist Bus Time.1'))
            route.last_bus_time_weekday     = safe_time(row.get('Last Bus Time'))
            route.last_bus_time_sunday      = safe_time(row.get('Last Bus Time.1'))
            route.average_frequency_minutes = safe_freq(freq_weekday_raw, context="Weekday")
            route.average_frequency_minutes_sunday = safe_freq(freq_sunday_raw, context="Sunday")

            fare_val = row.get('Fare')
            parsed_fare = safe_fare(fare_val)
            print(f"💰 Fare Raw: {fare_val} | Parsed: {parsed_fare}")
            route.average_fare = parsed_fare

            route.save()
            self.stdout.write(self.style.SUCCESS(f"✅ Updated Route {route_no}"))
            updated += 1

        self.stdout.write(self.style.SUCCESS(f"\n🚀 Done: {updated} updated, {skipped} skipped."))
