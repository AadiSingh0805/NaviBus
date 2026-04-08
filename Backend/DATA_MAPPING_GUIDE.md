# NaviBus Data Warehouse - Data Mapping & Faker.js Requirements

## 📊 **AVAILABLE DATA FROM PRODUCTION**
✅ **Routes Data** (73 routes from production_data.json)
- route_number, start_stop, end_stop, active status
- Timing data: first_bus_time_weekday/sunday, last_bus_time_weekday/sunday
- Frequency: average_frequency_minutes (weekday/sunday)
- Fare: average_fare

✅ **Stops Data** (1,251 stops from core.stop)
- stop names, but missing latitude/longitude coordinates

✅ **Route-Stop Relationships** 
- Complete mapping of which stops belong to which routes
- Stop order sequence for each route

## 🎭 **DATA TO BE MOCKED WITH FAKER.JS**

### **1. Time Dimension (730 records - 2 years)**
```javascript
// Generate 2024-2025 calendar
const timeData = {
  dates: generateDateRange('2024-01-01', '2025-12-31'),
  holidays: [
    '2024-01-26', '2024-08-15', '2024-10-02', // National holidays
    '2024-03-25', '2024-05-01', // Regional holidays
    // Add Diwali, Holi, Eid dates
  ],
  seasons: {
    'Winter': ['Oct', 'Nov', 'Dec', 'Jan', 'Feb'],
    'Summer': ['Mar', 'Apr', 'May'],
    'Monsoon': ['Jun', 'Jul', 'Aug', 'Sep']
  }
}
```

### **2. Passenger Demographics (50,000+ records)**
```javascript
const passengerProfiles = {
  ageGroups: {
    'Child': 20,    // 0-12 years
    'Adult': 65,    // 13-59 years  
    'Senior': 15    // 60+ years
  },
  genderDistribution: {
    'Male': 45,
    'Female': 50,
    'Other': 5
  },
  ticketTypes: {
    'Single': 70,
    'Return': 15,
    'Daily': 10,
    'Weekly': 3,
    'Monthly': 2
  }
}
```

### **3. Bus Fleet Data (300-500 buses)**
```javascript
const busSpecs = {
  registrationFormat: 'MH04AB1234', // Maharashtra pattern
  fuelTypes: {
    'Diesel': 60,
    'CNG': 35,
    'Electric': 5
  },
  capacity: {
    'Non-AC': faker.number.int({min: 40, max: 60}),
    'AC': faker.number.int({min: 30, max: 45})
  },
  manufacturingYear: faker.date.between({
    from: '2015-01-01',
    to: '2024-12-31'
  }).getFullYear()
}
```

### **4. Geographic Data (1,251 locations)**
```javascript
const mumbaiRegions = {
  coordinates: {
    // Mumbai bounding box
    north: 19.2812, south: 18.8942,
    east: 72.9781, west: 72.7747
  },
  zones: [
    'Central_Mumbai', 'Western_Mumbai', 'Eastern_Mumbai',
    'Harbour_Line', 'Thane', 'Panvel', 'Navi_Mumbai'
  ],
  amenities: [
    'Shelter', 'Seating', 'Display_Board', 
    'Toilet', 'Parking', 'Food_Stall', 'ATM'
  ]
}
```

## 🔄 **DERIVED/CALCULATED FIELDS**

### **From Existing Data:**
- **Bus Type**: Extract from route_number (contains "AC", "E.AC", "EL.AC", "V.AC")
- **Number of Stops**: Count from RouteStop relationships
- **Route Distance**: Estimate based on stop count and route type
- **Day Type**: Weekday/Sunday from available timing data
- **Peak Hours**: 7-10 AM, 5-8 PM = TRUE

### **Business Logic Calculations:**
```javascript
// Distance estimation
const estimateDistance = (stopCount, routeType) => {
  const baseDistance = stopCount * 1.5; // km per stop
  const multiplier = routeType.includes('EL') ? 1.8 : 1.2; // Express vs Regular
  return Math.round(baseDistance * multiplier);
}

// Fare calculation with discounts
const calculateActualFare = (baseFare, fareTypeId) => {
  const discounts = {
    1: 0.00,   // Regular
    2: 0.25,   // Student
    3: 0.50,   // Senior
    4: 0.50,   // Child
    5: 0.75,   // Disabled
    6: 0.15,   // Monthly
    7: 0.10    // Weekly
  };
  return baseFare * (1 - discounts[fareTypeId]);
}
```

## 📈 **SAMPLE DATA VOLUMES**

| Dimension | Records | Source |
|-----------|---------|---------|
| **Time** | 730 | MOCK (2024-2025) |
| **Routes** | 73 | AVAILABLE |
| **Stops** | 1,251 | AVAILABLE |
| **Buses** | 400 | MOCK |
| **Passengers** | 50,000+ | MOCK |
| **Transactions** | 1M+ | MOCK |
| **Fare Types** | 10 | DEFINED |

## 🎯 **FAKER.JS IMPLEMENTATION PRIORITY**

### **Phase 1: Core Dimensions**
1. ✅ Time dimension with holidays/seasons
2. ✅ Geographic coordinates for all stops
3. ✅ Bus fleet with realistic specifications

### **Phase 2: Transaction Data** 
1. 🔄 Passenger demographics
2. 🔄 Travel patterns (realistic boarding times)
3. 🔄 Seasonal variations in ridership

### **Phase 3: Advanced Analytics**
1. 🔄 Route performance metrics
2. 🔄 Fuel consumption data
3. 🔄 Maintenance schedules

## 📋 **CSV FILES CREATED**

1. **routes_master_data.csv** - Route information with derived fields
2. **fare_types_master.csv** - Complete fare structure
3. **bus_fleet_data.csv** - Bus specifications template
4. **locations_master.csv** - Geographic data template
5. **time_dimension.csv** - Time dimension template
6. **passenger_transactions.csv** - Transaction data template

## 🚀 **NEXT STEPS**

1. **Implement Faker.js scripts** for each dimension
2. **Generate realistic coordinates** for Mumbai stops
3. **Create passenger travel patterns** based on route popularity
4. **Build seasonal ridership models**
5. **Generate historical transaction data** for analytics

Each CSV file contains sample data and clear instructions for faker.js implementation!
