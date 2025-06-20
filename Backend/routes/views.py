from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db.models import Prefetch
from .models import BusRoute, RouteStop
from .serializers import BusRouteSerializer
from core.models import Stop
from rapidfuzz import process, fuzz
import redis
from django.conf import settings
from collections import defaultdict, deque
import heapq

# Setup Redis connection (adjust host/port/db as needed)
try:
    redis_client = redis.StrictRedis.from_url(
        "redis://default:fQsJKKdIbbKNTEhXYNiCQ2xDbbDIzhX4@redis-15810.crce206.ap-south-1-1.ec2.redns.redis-cloud.com:15810/0",
        decode_responses=True
    )
    redis_available = True
    # Test connection
    redis_client.ping()
except Exception:
    redis_client = None
    redis_available = False

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

@api_view(['GET'])
def autocomplete_stops(request):
    """
    Autocomplete stop names using fuzzy search and Redis caching.
    Query param: ?q=partial_stop_name
    Returns: List of matching stop names (max 10)
    """
    query = request.GET.get('q', '').strip()
    if not query:
        return Response({'error': 'Missing query parameter q'}, status=400)

    stop_names = None
    if redis_available and redis_client:
        try:
            stop_names = redis_client.get('all_stop_names')
            if stop_names:
                stop_names = stop_names.split('|')
        except Exception:
            stop_names = None
    if not stop_names:
        # Fetch from DB and cache if possible
        stop_names = list(Stop.objects.values_list('name', flat=True))
        if redis_available and redis_client:
            try:
                redis_client.set('all_stop_names', '|'.join(stop_names), ex=3600)  # cache for 1 hour
            except Exception:
                pass

    # Fuzzy match using rapidfuzz
    matches = process.extract(query, stop_names, scorer=fuzz.WRatio, limit=10)
    results = [name for name, score, _ in matches if score > 60]  # threshold can be tuned

    return Response({'results': results})

@api_view(['GET'])
def plan_journey(request):
    """
    Find the best (shortest) path between two stops, possibly using multiple routes (Dijkstra's algorithm).
    Query params: ?start=StopA&end=StopB
    Returns: List of segments, each with route_number, stops, and transfer info.
    """
    start_name = request.GET.get('start')
    end_name = request.GET.get('end')
    if not start_name or not end_name:
        return Response({'error': "Both 'start' and 'end' parameters are required."}, status=400)
    start_name = start_name.strip()
    end_name = end_name.strip()

    # Build graph: stop_name -> list of (neighbor_stop_name, route_number, stop_order)
    graph = defaultdict(list)
    stop_to_routes = defaultdict(list)  # stop_name -> list of (route_number, stop_order)
    route_stops = defaultdict(list)     # route_number -> ordered list of stop names

    for route in BusRoute.objects.prefetch_related('route_stops__stop').all():
        stops = sorted(route.route_stops.all(), key=lambda rs: rs.stop_order)
        stop_names = [rs.stop.name for rs in stops]
        route_stops[route.route_number] = stop_names
        for i, stop in enumerate(stop_names):
            stop_to_routes[stop].append((route.route_number, i))
            if i > 0:
                graph[stop_names[i-1]].append((stop, route.route_number, i))
            if i < len(stop_names) - 1:
                graph[stop].append((stop_names[i+1], route.route_number, i+1))

    # Dijkstra's: (cost, stop, path_so_far, route_so_far, transfer_count)
    heap = [(0, start_name, [], [], 0)]
    visited = dict()  # (stop, route) -> cost
    best_path = None
    best_cost = float('inf')

    while heap:
        cost, stop, path, routes, transfers = heapq.heappop(heap)
        if (stop, tuple(routes)) in visited and visited[(stop, tuple(routes))] <= cost:
            continue
        visited[(stop, tuple(routes))] = cost
        path = path + [stop]
        if stop == end_name:
            best_path = (path, routes, transfers)
            best_cost = cost
            break
        for neighbor, route_number, _ in graph[stop]:
            new_routes = routes.copy()
            if not routes or routes[-1] != route_number:
                new_routes.append(route_number)
                new_transfers = transfers + 1 if routes else 0
            else:
                new_transfers = transfers
            heapq.heappush(heap, (cost + 1, neighbor, path, new_routes, new_transfers))

    if not best_path:
        return Response({'error': 'No path found between stops.'}, status=404)

    # Reconstruct segments: group consecutive stops by route
    path, routes, transfers = best_path
    segments = []
    if not routes:
        return Response({'error': 'No route found.'}, status=404)
    seg_start = path[0]
    seg_route = routes[0]
    seg_stops = [seg_start]
    for i in range(1, len(path)):
        # If route changes, start new segment
        prev_stop = path[i-1]
        curr_stop = path[i]
        # Find which route connects prev_stop to curr_stop
        possible_routes = set(r for r, idx in stop_to_routes[prev_stop]) & set(r for r, idx in stop_to_routes[curr_stop])
        if seg_route not in possible_routes:
            segments.append({'route_number': seg_route, 'stops': seg_stops})
            seg_route = list(possible_routes & set(routes))[0] if possible_routes else routes[0]
            seg_stops = [prev_stop, curr_stop]
        else:
            seg_stops.append(curr_stop)
    segments.append({'route_number': seg_route, 'stops': seg_stops})

    return Response({'segments': segments, 'total_stops': len(path)-1, 'transfers': len(segments)-1})

