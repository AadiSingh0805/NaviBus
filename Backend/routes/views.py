from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Prefetch
from .models import BusRoute, RouteStop
from .serializers import BusRouteSerializer
from core.models import Stop

@api_view(['GET'])
def get_all_routes(request):
    routes = BusRoute.objects.select_related('start_stop', 'end_stop').all()
    serializer = BusRouteSerializer(routes, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def add_route(request):
    serializer = BusRouteSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
def search_route_path(request):
    start_name = request.GET.get('start')
    end_name = request.GET.get('end')

    if not start_name or not end_name:
        return Response({"error": "Both 'start' and 'end' parameters are required."}, status=400)

    try:
        start_stop = Stop.objects.get(name__iexact=start_name)
        end_stop = Stop.objects.get(name__iexact=end_name)
    except Stop.DoesNotExist:
        return Response({"error": "Start or End stop not found."}, status=404)

    routes = BusRoute.objects.prefetch_related(
        Prefetch(
            'route_stops',
            queryset=RouteStop.objects.select_related('stop').order_by('stop_order')
        )
    )

    results = []
    for route in routes:
        stop_names = [rs.stop.name.strip().lower() for rs in route.route_stops.all()]
        src = start_name.strip().lower()
        dst = end_name.strip().lower()
        if src == dst:
            continue
        if src in stop_names and dst in stop_names:
            start_index = stop_names.index(src)
            end_index = stop_names.index(dst)
            step = 1 if start_index < end_index else -1
            sub_path = stop_names[start_index:end_index+step:step] if step == 1 else stop_names[start_index:end_index-1:step]
            results.append({
                'route_number': route.route_number,
                'sub_path': [rs.stop.name for rs in route.route_stops.all()][start_index:end_index+step:step] if step == 1 else [rs.stop.name for rs in route.route_stops.all()][start_index:end_index-1:step],
                'first_bus_time_weekday': route.first_bus_time_weekday,
                'last_bus_time_weekday': route.last_bus_time_weekday,
                'first_bus_time_sunday': route.first_bus_time_sunday,
                'last_bus_time_sunday': route.last_bus_time_sunday,
                'frequency_weekday': route.average_frequency_minutes,
                'frequency_sunday': route.average_frequency_minutes_sunday,
                'fare': route.average_fare
            })

    if results:
        return Response(results)
    return Response({"message": "No route passes through both stops in order."}, status=404)

@api_view(['GET'])
def get_route_schedule_info(request):
    route_number = request.GET.get('route_number')
    if not route_number:
        return Response({"error": "route_number parameter is required."}, status=400)

    try:
        route = BusRoute.objects.get(route_number__iexact=route_number)
        data = {
            "route_number": route.route_number,
            "first_bus_time_weekday": route.first_bus_time_weekday,
            "last_bus_time_weekday": route.last_bus_time_weekday,
            "first_bus_time_sunday": route.first_bus_time_sunday,
            "last_bus_time_sunday": route.last_bus_time_sunday,
            "frequency_weekday": route.average_frequency_minutes,
            "frequency_sunday": route.average_frequency_minutes_sunday,
            "fare": route.average_fare
        }
        return Response(data)
    except BusRoute.DoesNotExist:
        return Response({"error": f"No route found for route number '{route_number}'"}, status=404)

# Fare patterns
AC_FARE_PATTERN = [10, 12, 15, 18, 20, 22, 25, 27, 30, 32, 35, 40, 45, 50, 50, 55, 55, 60, 60, 65, 70, 70, 75, 75, 80, 80, 85, 85, 90, 90, 95, 95, 100, 100, 105, 105, 110, 110, 115, 115, 120]
NON_AC_FARE_PATTERN = [7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31, 33, 35, 37, 39, 41, 43, 45, 47]
AC_MIN_FARE = 10
NON_AC_MIN_FARE = 7

def calculate_fare(num_stops, bus_type):
    if bus_type == "AC":
        pattern = AC_FARE_PATTERN
        min_fare = AC_MIN_FARE
    else:
        pattern = NON_AC_FARE_PATTERN
        min_fare = NON_AC_MIN_FARE

    block = (num_stops - 1) // 5
    if block < len(pattern):
        fare = pattern[block]
    else:
        fare = min_fare
    return fare

@api_view(['GET'])
def get_fare_for_route(request):
    route_number = request.GET.get('route_number')
    source_stop = request.GET.get('source_stop')
    destination_stop = request.GET.get('destination_stop')

    if not route_number or not source_stop or not destination_stop:
        return Response({
            "error": "Missing parameter(s).",
            "received": {
                "route_number": route_number,
                "source_stop": source_stop,
                "destination_stop": destination_stop
            }
        }, status=400)

    try:
        route = BusRoute.objects.prefetch_related(
            Prefetch(
                'route_stops',
                queryset=RouteStop.objects.select_related('stop').order_by('stop_order')
            )
        ).get(route_number__iexact=route_number)
        
        stops = list(route.route_stops.all())
        stop_names = [rs.stop.name.strip().lower() for rs in stops]

        src = source_stop.strip().lower()
        dst = destination_stop.strip().lower()

        if src == dst:
            return Response({"error": "Source and destination stops are the same."}, status=400)

        if src in stop_names and dst in stop_names:
            start_index = stop_names.index(src)
            end_index = stop_names.index(dst)

            if start_index < end_index:
                sub_stops = stops[start_index:end_index + 1]
            else:
                sub_stops = stops[end_index:start_index + 1][::-1]

            num_stops = len(sub_stops)
            if num_stops < 2:
                return Response({"error": "No valid path between source and destination."}, status=400)

            # Determine bus type
            route_number_upper = route.route_number.upper()
            if any(x in route_number_upper for x in [".AC", " AC", "AC.", "-AC", "_AC", "AC"]):
                bus_type = "AC"
            else:
                bus_type = "NON_AC"

            fare = calculate_fare(num_stops, bus_type)

            return Response({
                "route_number": route.route_number,
                "bus_type": bus_type,
                "source_stop": source_stop,
                "destination_stop": destination_stop,
                "num_stops": num_stops,
                "fare": fare,
                "stops": [s.stop.name for s in sub_stops]
            })
        else:
            return Response({"error": "Source or destination stop not found in this route."}, status=404)

    except BusRoute.DoesNotExist:
        return Response({"error": "Route not found."}, status=404)

