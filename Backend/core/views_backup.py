from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Stop
from .serializers import StopSerializer
import math

@api_view(['GET'])
def get_all_stops(request):
    stops = Stop.objects.all()
    serializer = StopSerializer(stops, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def add_stop(request):
    serializer = StopSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

def calculate_distance(lat1, lon1, lat2, lon2):
    """
    Calculate the great circle distance between two points 
    on the earth (specified in decimal degrees) using Haversine formula
    Returns distance in kilometers
    """
    # Convert decimal degrees to radians
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    
    # Haversine formula
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon/2)**2
    c = 2 * math.asin(math.sqrt(a))
    
    # Radius of earth in kilometers
    r = 6371
    return c * r

@api_view(['GET'])
def get_nearby_stops(request):
    """
    Get bus stops within a specified radius of a given location
    Query parameters:
    - lat: latitude
    - lon: longitude  
    - radius: radius in kilometers (default: 2km)
    - limit: maximum number of results (default: 10)
    """
    try:
        lat = float(request.GET.get('lat', 0))
        lon = float(request.GET.get('lon', 0))
        radius = float(request.GET.get('radius', 2.0))  # 2km default
        limit = int(request.GET.get('limit', 10))
        
        if lat == 0 or lon == 0:
            return Response(
                {'error': 'Latitude and longitude are required'}, 
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get all stops with coordinates
        stops = Stop.objects.filter(
            latitude__isnull=False, 
            longitude__isnull=False
        )
        
        nearby_stops = []
        
        for stop in stops:
            distance = calculate_distance(lat, lon, stop.latitude, stop.longitude)
            if distance <= radius:
                stop_data = {
                    'id': stop.id,
                    'name': stop.name,
                    'latitude': stop.latitude,
                    'longitude': stop.longitude,
                    'distance': round(distance, 2)  # Distance in km
                }
                nearby_stops.append(stop_data)
        
        # Sort by distance and limit results
        nearby_stops.sort(key=lambda x: x['distance'])
        nearby_stops = nearby_stops[:limit]
        
        return Response({
            'count': len(nearby_stops),
            'radius': radius,
            'user_location': {'lat': lat, 'lon': lon},
            'stops': nearby_stops
        })
        
    except ValueError as e:
        return Response(
            {'error': f'Invalid parameter: {str(e)}'}, 
            status=status.HTTP_400_BAD_REQUEST
        )
    except Exception as e:
        return Response(
            {'error': f'Server error: {str(e)}'}, 
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        ).decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Stop
from .serializers import StopSerializer

@api_view(['GET'])
def get_all_stops(request):
    stops = Stop.objects.all()
    serializer = StopSerializer(stops, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def add_stop(request):
    serializer = StopSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
