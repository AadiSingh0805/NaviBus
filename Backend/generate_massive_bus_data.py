#!/usr/bin/env python3
"""
NaviBus Massive Data Generator
Creates 50,000+ realistic bus travel records following real-world patterns
"""

import csv
import json
import random
import datetime
from datetime import datetime, timedelta
from typing import List, Dict, Tuple
import math

class NaviBusMassiveDataGenerator:
    def __init__(self):
        self.routes_data = []
        self.merged_routes = {}
        self.load_data()
        
        # Real-world Mumbai demographic patterns
        self.age_groups = ["Child", "Adult", "Student", "Senior"]
        self.age_weights = [0.15, 0.55, 0.20, 0.10]
        
        self.genders = ["Male", "Female", "Other"]
        self.gender_weights = [0.52, 0.46, 0.02]
        
        self.ticket_types = ["Single", "Return", "Daily", "Weekly", "Monthly"]
        self.ticket_weights = [0.65, 0.15, 0.08, 0.07, 0.05]
        
        # Mumbai seasons and travel patterns
        self.seasons = {
            (1, 2, 3): "Winter",
            (4, 5, 6): "Summer", 
            (7, 8, 9): "Monsoon",
            (10, 11, 12): "Winter"
        }
        
        # Peak hour patterns (Mumbai rush hours)
        self.peak_hours = [
            (7, 9),   # Morning rush
            (17, 20)  # Evening rush
        ]
        
        # Fare types and concessions
        self.fare_types = [
            {"id": 1, "code": "REGULAR", "discount": 0.0},
            {"id": 2, "code": "STUDENT", "discount": 0.25},
            {"id": 3, "code": "SENIOR", "discount": 0.50},
            {"id": 4, "code": "CHILD", "discount": 0.50},
            {"id": 5, "code": "DISABLED", "discount": 0.75},
            {"id": 6, "code": "MONTHLY", "discount": 0.15},
            {"id": 7, "code": "WEEKLY", "discount": 0.10},
            {"id": 8, "code": "DAILY", "discount": 0.05}
        ]
        
        # Bus fleet data
        self.bus_fleet = self.generate_bus_fleet()
        
    def load_data(self):
        """Load routes master data and merged routes data"""
        try:
            # Load routes master data
            with open('routes_master_data.csv', 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                self.routes_data = list(reader)
            
            # Load merged routes for stop-to-stop logic
            with open('merged_routes.csv', 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    route_num = row['Route Number']
                    stops = json.loads(row['Stops'])
                    self.merged_routes[route_num] = stops
                    
        except FileNotFoundError as e:
            print(f"Error loading data: {e}")
            self.routes_data = []
            self.merged_routes = {}
    
    def generate_bus_fleet(self) -> List[Dict]:
        """Generate realistic bus fleet with proper numbering"""
        fleet = []
        bus_id = 1
        
        for route in self.routes_data:
            route_id = int(route['route_id'])
            route_name = route['route_name']
            bus_type = route['bus_type']
            
            # Each route has 3-8 buses depending on frequency
            frequency = int(route.get('frequency_weekday', 30))
            num_buses = max(3, min(8, frequency // 10))
            
            for i in range(num_buses):
                # Generate realistic Maharashtra bus numbers
                registration = f"MH04{chr(65 + random.randint(0, 25))}{chr(65 + random.randint(0, 25))}{random.randint(1000, 9999)}"
                
                # Bus capacity based on type
                if bus_type == "Electric":
                    capacity = random.randint(35, 42)
                    fuel_type = "Electric"
                elif bus_type == "AC":
                    capacity = random.randint(32, 40)
                    fuel_type = random.choice(["CNG", "Electric", "Diesel"])
                else:  # Non-AC
                    capacity = random.randint(44, 55)
                    fuel_type = random.choice(["Diesel", "CNG"])
                
                fleet.append({
                    "bus_id": bus_id,
                    "route_id": route_id,
                    "route_name": route_name,
                    "registration": registration,
                    "bus_type": bus_type,
                    "fuel_type": fuel_type,
                    "capacity": capacity
                })
                bus_id += 1
                
        return fleet
    
    def get_random_stops_for_route(self, route_name: str) -> Tuple[str, str]:
        """Get random source and destination stops for a route"""
        if route_name in self.merged_routes:
            stops = self.merged_routes[route_name]
            if len(stops) >= 2:
                # Passenger can board at any stop and get off at any later stop
                source_idx = random.randint(0, len(stops) - 2)
                dest_idx = random.randint(source_idx + 1, len(stops) - 1)
                return stops[source_idx], stops[dest_idx]
        
        # Fallback to route master data if merged routes not available
        route_data = next((r for r in self.routes_data if r['route_name'] == route_name), None)
        if route_data:
            return route_data['start_point'], route_data['end_point']
        
        return "Unknown Source", "Unknown Destination"
    
    def calculate_dynamic_fare(self, base_fare: float, source: str, dest: str, 
                             route_data: Dict, passenger_profile: Dict) -> Tuple[float, float, bool]:
        """Calculate dynamic fare based on distance, stops, and passenger type"""
        try:
            base_fare = float(base_fare)
        except (ValueError, TypeError):
            base_fare = 20.0
        
        # Distance-based fare adjustment
        if route_data.get('route_name') in self.merged_routes:
            stops = self.merged_routes[route_data.get('route_name')]
            try:
                source_idx = stops.index(source)
                dest_idx = stops.index(dest)
                stops_traveled = abs(dest_idx - source_idx)
                total_stops = len(stops)
                
                # Fare proportional to stops traveled
                distance_multiplier = stops_traveled / total_stops
                base_fare = base_fare * max(0.3, distance_multiplier)
            except ValueError:
                # If stops not found, use full fare
                pass
        
        # Apply concessions
        age_group = passenger_profile['age_group']
        ticket_type = passenger_profile['ticket_type']
        
        discount = 0.0
        concession_flag = False
        
        if age_group == "Child":
            discount = 0.50
            concession_flag = True
        elif age_group == "Student":
            discount = 0.25
            concession_flag = True
        elif age_group == "Senior":
            discount = 0.50
            concession_flag = True
        elif ticket_type in ["Weekly", "Monthly", "Daily"]:
            discount = {"Daily": 0.05, "Weekly": 0.10, "Monthly": 0.15}.get(ticket_type, 0.0)
            concession_flag = discount > 0
        
        actual_fare = base_fare * (1 - discount)
        
        # Return ticket doubles the fare
        if ticket_type == "Return":
            actual_fare *= 2
        
        return round(base_fare, 2), round(actual_fare, 2), concession_flag
    
    def generate_realistic_passenger(self, time_of_day: int, day_of_week: str) -> Dict:
        """Generate realistic passenger profile based on time and day"""
        # Time-based passenger patterns
        if 6 <= time_of_day <= 9:  # Morning rush - more office goers
            age_weights = [0.10, 0.65, 0.15, 0.10]
        elif 17 <= time_of_day <= 20:  # Evening rush
            age_weights = [0.12, 0.60, 0.18, 0.10]
        elif 9 <= time_of_day <= 16:  # Daytime - more seniors, students
            age_weights = [0.15, 0.45, 0.25, 0.15]
        else:  # Off-peak
            age_weights = [0.20, 0.50, 0.20, 0.10]
        
        age_group = random.choices(self.age_groups, weights=age_weights)[0]
        gender = random.choices(self.genders, weights=self.gender_weights)[0]
        
        # Ticket type based on passenger type
        if age_group == "Student":
            ticket_type = random.choices(["Single", "Monthly", "Weekly"], weights=[0.4, 0.4, 0.2])[0]
        elif age_group == "Adult" and day_of_week in ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]:
            ticket_type = random.choices(["Single", "Monthly", "Weekly", "Daily"], weights=[0.5, 0.25, 0.15, 0.1])[0]
        else:
            ticket_type = random.choices(["Single", "Return"], weights=[0.7, 0.3])[0]
        
        return {
            "age_group": age_group,
            "gender": gender,
            "ticket_type": ticket_type
        }
    
    def generate_time_distribution(self, start_time: str, end_time: str, frequency: int) -> List[str]:
        """Generate realistic time distribution based on frequency"""
        try:
            start_h, start_m = map(int, start_time.split(':'))
            end_h, end_m = map(int, end_time.split(':'))
            
            start_minutes = start_h * 60 + start_m
            end_minutes = end_h * 60 + end_m
            
            # Handle next day scenarios
            if end_minutes < start_minutes:
                end_minutes += 24 * 60
            
            operating_minutes = end_minutes - start_minutes
            
            times = []
            if frequency > 0:
                interval = operating_minutes / frequency
                current_time = start_minutes
                
                for _ in range(frequency):
                    # Add some randomness (±5 minutes)
                    actual_time = current_time + random.randint(-5, 5)
                    hours = (actual_time // 60) % 24
                    minutes = actual_time % 60
                    times.append(f"{hours:02d}:{minutes:02d}:00")
                    current_time += interval
            
            return times
            
        except Exception:
            # Fallback to random times
            return [f"{random.randint(6, 22):02d}:{random.randint(0, 59):02d}:00" 
                   for _ in range(max(1, frequency // 3))]
    
    def get_season(self, month: int) -> str:
        """Get season based on month"""
        for months, season in self.seasons.items():
            if month in months:
                return season
        return "Winter"
    
    def is_peak_hour(self, hour: int) -> bool:
        """Check if given hour is peak hour"""
        return any(start <= hour < end for start, end in self.peak_hours)
    
    def is_holiday(self, date: datetime) -> bool:
        """Simple holiday detection (weekends and some fixed dates)"""
        if date.weekday() >= 5:  # Saturday, Sunday
            return True
        
        # Some fixed holidays (simplified)
        holidays = [
            (1, 26),   # Republic Day
            (8, 15),   # Independence Day
            (10, 2),   # Gandhi Jayanti
        ]
        
        return (date.month, date.day) in holidays
    
    def generate_massive_dataset(self, num_records: int = 50000) -> List[Dict]:
        """Generate massive realistic dataset"""
        records = []
        transaction_id = 1
        passenger_id = 10001
        
        # Date range: Last 12 months
        end_date = datetime.now()
        start_date = end_date - timedelta(days=365)
        
        print(f"Generating {num_records} records...")
        
        records_per_route = num_records // len(self.routes_data)
        
        for route_idx, route in enumerate(self.routes_data):
            route_id = int(route['route_id'])
            route_name = route['route_name']
            
            # Get buses for this route
            route_buses = [bus for bus in self.bus_fleet if bus['route_id'] == route_id]
            if not route_buses:
                continue
            
            print(f"Processing Route {route_name} ({route_idx + 1}/{len(self.routes_data)})")
            
            # Generate time schedules
            try:
                frequency_weekday = int(route.get('frequency_weekday', 30))
                frequency_sunday = int(route.get('frequency_sunday', frequency_weekday))
                first_bus = route.get('first_bus_weekday', '06:00:00')
                last_bus = route.get('last_bus_weekday', '22:00:00')
            except (ValueError, TypeError):
                frequency_weekday = 30
                frequency_sunday = 25
                first_bus = '06:00:00'
                last_bus = '22:00:00'
            
            # Generate records for this route
            route_records = 0
            attempts = 0
            max_attempts = records_per_route * 3
            
            while route_records < records_per_route and attempts < max_attempts:
                attempts += 1
                
                # Random date in the past year
                random_days = random.randint(0, 365)
                current_date = start_date + timedelta(days=random_days)
                day_of_week = current_date.strftime('%A')
                
                # Choose frequency based on day
                if day_of_week == 'Sunday':
                    frequency = frequency_sunday
                else:
                    frequency = frequency_weekday
                
                if frequency <= 0:
                    continue
                
                # Generate bus schedules for this day
                bus_times = self.generate_time_distribution(first_bus, last_bus, frequency)
                
                # Generate passengers for random bus trips
                num_trips = random.randint(1, min(5, len(bus_times)))
                
                for _ in range(num_trips):
                    if route_records >= records_per_route:
                        break
                    
                    # Random bus and time
                    bus = random.choice(route_buses)
                    bus_time = random.choice(bus_times)
                    
                    # Generate realistic passenger count (1-15 passengers per trip)
                    passenger_count = random.choices(
                        range(1, 16),
                        weights=[8, 6, 5, 4, 3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1]
                    )[0]
                    
                    for _ in range(passenger_count):
                        if route_records >= records_per_route:
                            break
                        
                        # Get random stops for this passenger
                        source_stop, dest_stop = self.get_random_stops_for_route(route_name)
                        
                        # Generate passenger profile
                        hour = int(bus_time.split(':')[0])
                        passenger_profile = self.generate_realistic_passenger(hour, day_of_week)
                        
                        # Calculate fare
                        base_fare, actual_fare, concession_flag = self.calculate_dynamic_fare(
                            route.get('average_fare', 20.0),
                            source_stop,
                            dest_stop,
                            route,
                            passenger_profile
                        )
                        
                        # Get fare type
                        fare_type = next(
                            ft for ft in self.fare_types 
                            if ft['code'] == {
                                'Child': 'CHILD',
                                'Student': 'STUDENT', 
                                'Senior': 'SENIOR',
                                'Daily': 'DAILY',
                                'Weekly': 'WEEKLY',
                                'Monthly': 'MONTHLY'
                            }.get(passenger_profile['age_group'], 
                                  passenger_profile['ticket_type'].upper() if passenger_profile['ticket_type'] in ['Daily', 'Weekly', 'Monthly'] else 'REGULAR')
                        )
                        
                        # Time dimension
                        time_id = current_date.timetuple().tm_yday
                        
                        # Create record
                        record = {
                            'transaction_id': transaction_id,
                            'date': current_date.strftime('%Y-%m-%d'),
                            'time_id': time_id,
                            'passenger_id': passenger_id,
                            'route_id': route_id,
                            'route_name': route_name,
                            'bus_id': bus['bus_id'],
                            'bus_number': bus['registration'],
                            'bus_type': bus['bus_type'],
                            'fuel_type': bus['fuel_type'],
                            'capacity': bus['capacity'],
                            'source_stop': source_stop,
                            'destination_stop': dest_stop,
                            'boarding_time': bus_time,
                            'age_group': passenger_profile['age_group'],
                            'gender': passenger_profile['gender'],
                            'ticket_type': passenger_profile['ticket_type'],
                            'fare_type_id': fare_type['id'],
                            'fare_code': fare_type['code'],
                            'discount_percent': fare_type['discount'] * 100,
                            'base_fare': base_fare,
                            'actual_fare': actual_fare,
                            'concession_flag': 'TRUE' if concession_flag else 'FALSE',
                            'zone_source': route.get('zone_source', 'Unknown'),
                            'zone_dest': route.get('zone_dest', 'Unknown'),
                            'region_source': route.get('region_source', 'Unknown'),
                            'region_dest': route.get('region_dest', 'Unknown'),
                            'distance_km': route.get('distance_km', 0),
                            'day_of_week': day_of_week,
                            'season': self.get_season(current_date.month),
                            'holiday_flag': 'TRUE' if self.is_holiday(current_date) else 'FALSE',
                            'peak_hour_flag': 'TRUE' if self.is_peak_hour(hour) else 'FALSE',
                            'frequency_weekday': frequency_weekday,
                            'frequency_sunday': frequency_sunday,
                            'first_bus': first_bus,
                            'last_bus': last_bus
                        }
                        
                        records.append(record)
                        transaction_id += 1
                        passenger_id += 1
                        route_records += 1
        
        print(f"Generated {len(records)} total records")
        return records
    
    def save_to_csv(self, records: List[Dict], filename: str):
        """Save records to CSV file"""
        if not records:
            print("No records to save")
            return
        
        fieldnames = [
            'transaction_id', 'date', 'time_id', 'passenger_id', 'route_id', 'route_name',
            'bus_id', 'bus_number', 'bus_type', 'fuel_type', 'capacity',
            'source_stop', 'destination_stop', 'boarding_time',
            'age_group', 'gender', 'ticket_type', 'fare_type_id', 'fare_code',
            'discount_percent', 'base_fare', 'actual_fare', 'concession_flag',
            'zone_source', 'zone_dest', 'region_source', 'region_dest', 'distance_km',
            'day_of_week', 'season', 'holiday_flag', 'peak_hour_flag',
            'frequency_weekday', 'frequency_sunday', 'first_bus', 'last_bus'
        ]
        
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            # Add header comment
            csvfile.write(f"# NaviBus Massive Data Warehouse - {len(records)} Records\n")
            csvfile.write(f"# Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n") 
            csvfile.write(f"# Realistic Mumbai bus travel patterns with stop-to-stop logic\n\n")
            
            writer.writerows(records)
        
        print(f"Saved {len(records)} records to {filename}")

def main():
    """Main execution function"""
    print("NaviBus Massive Data Generator")
    print("=" * 50)
    
    generator = NaviBusMassiveDataGenerator()
    
    if not generator.routes_data:
        print("Error: Could not load route data. Please ensure routes_master_data.csv exists.")
        return
    
    print(f"Loaded {len(generator.routes_data)} routes")
    print(f"Generated {len(generator.bus_fleet)} buses in fleet")
    print(f"Loaded stop data for {len(generator.merged_routes)} routes")
    
    # Generate different dataset sizes
    datasets = [
        (10000, "navibus_massive_10k.csv"),
        (50000, "navibus_massive_50k.csv"),
        (100000, "navibus_massive_100k.csv")
    ]
    
    for num_records, filename in datasets:
        print(f"\nGenerating {num_records} records...")
        records = generator.generate_massive_dataset(num_records)
        generator.save_to_csv(records, filename)
        
        # Print summary statistics
        if records:
            print(f"\nDataset Summary for {filename}:")
            print(f"Total Records: {len(records):,}")
            print(f"Date Range: {min(r['date'] for r in records)} to {max(r['date'] for r in records)}")
            print(f"Total Passengers: {len(set(r['passenger_id'] for r in records)):,}")
            print(f"Total Revenue: ₹{sum(float(r['actual_fare']) for r in records):,.2f}")
            print(f"Average Fare: ₹{sum(float(r['actual_fare']) for r in records) / len(records):.2f}")
            
            # Bus type distribution
            bus_types = {}
            for record in records:
                bus_type = record['bus_type']
                bus_types[bus_type] = bus_types.get(bus_type, 0) + 1
            
            print("Bus Type Distribution:")
            for bus_type, count in bus_types.items():
                percentage = (count / len(records)) * 100
                print(f"  {bus_type}: {count:,} ({percentage:.1f}%)")

if __name__ == "__main__":
    main()
