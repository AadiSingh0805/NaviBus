from django.http import JsonResponse
from django.core.management import call_command
from django.views.decorators.csrf import csrf_exempt
from routes.models import BusRoute
from core.models import Stop
import json
import os

@csrf_exempt
def load_data_endpoint(request):
    """Endpoint to manually trigger data loading"""
    try:
        # Check current data count
        routes_before = BusRoute.objects.count()
        stops_before = Stop.objects.count()
        
        # Try to load data
        data_file = 'production_data.json'
        if os.path.exists(data_file):
            call_command('loaddata', data_file)
            
            # Check after loading
            routes_after = BusRoute.objects.count()
            stops_after = Stop.objects.count()
            
            return JsonResponse({
                'success': True,
                'message': 'Data loaded successfully',
                'before': {'routes': routes_before, 'stops': stops_before},
                'after': {'routes': routes_after, 'stops': stops_after},
                'loaded': {
                    'routes': routes_after - routes_before,
                    'stops': stops_after - stops_before
                }
            })
        else:
            return JsonResponse({
                'success': False,
                'message': f'Data file {data_file} not found',
                'current_data': {'routes': routes_before, 'stops': stops_before}
            })
            
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e),
            'message': 'Failed to load data'
        })

def data_status(request):
    """Check current data status"""
    routes_count = BusRoute.objects.count()
    stops_count = Stop.objects.count()
    
    return JsonResponse({
        'routes': routes_count,
        'stops': stops_count,
        'total_records': routes_count + stops_count,
        'data_loaded': routes_count > 0 or stops_count > 0
    })
