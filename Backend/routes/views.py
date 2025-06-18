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

    # Prefetch stops efficiently
    routes = BusRoute.objects.prefetch_related(
        Prefetch(
            'route_stops',
            queryset=RouteStop.objects.select_related('stop').order_by('stop_order')
        )
    )

    results = []
    for route in routes:
        stop_names = [rs.stop.name for rs in route.route_stops.all()]
        try:
            start_index = stop_names.index(start_name)
            end_index = stop_names.index(end_name)
            if start_index < end_index:
                results.append({
                    'route_number': route.route_number,
                    'sub_path': stop_names[start_index:end_index + 1],
                    'first_bus_time_weekday': route.first_bus_time_weekday,
                    'last_bus_time_weekday': route.last_bus_time_weekday,
                    'first_bus_time_sunday': route.first_bus_time_sunday,
                    'last_bus_time_sunday': route.last_bus_time_sunday,
                    'frequency_weekday': route.average_frequency_minutes,
                    'frequency_sunday': route.average_frequency_minutes_sunday,
                    'fare': route.average_fare
                })
        except ValueError:
            continue

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
