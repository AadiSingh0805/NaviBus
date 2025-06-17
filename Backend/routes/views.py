from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import BusRoute, RouteStop
from .serializers import BusRouteSerializer
from core.models import Stop

@api_view(['GET'])
def get_all_routes(request):
    routes = BusRoute.objects.all()
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
        return Response({"error": "Both start and end parameters are required."}, status=400)

    try:
        start_stop = Stop.objects.get(name__iexact=start_name)
        end_stop = Stop.objects.get(name__iexact=end_name)
    except Stop.DoesNotExist:
        return Response({"error": "One or both stops not found."}, status=404)

    routes = BusRoute.objects.all()
    results = []

    for route in routes:
        stops = list(RouteStop.objects.filter(route=route).order_by('stop_order'))
        stop_names = [s.stop.name for s in stops]

        try:
            start_index = stop_names.index(start_name)
            end_index = stop_names.index(end_name)
            if start_index < end_index:
                sub_path = stop_names[start_index:end_index + 1]
                results.append({
                    'route_number': route.route_number,
                    'sub_path': sub_path
                })
        except ValueError:
            continue

    if results:
        return Response(results)
    return Response({"message": "No matching route found."}, status=404)
