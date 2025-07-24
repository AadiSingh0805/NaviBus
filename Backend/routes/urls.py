from django.urls import path
from . import views
from .data_loader import load_data_endpoint, data_status

urlpatterns = [
    path('routes/', views.get_all_routes),
    path('routes/add/', views.add_route),
    path('routes/search/', views.search_route_path),  # ?start=X&end=Y
    path('routes/fuzzy-search/', views.fuzzy_search_routes),  # ?route_number=X (fuzzy search)
    path('routes/details/', views.get_route_details),  # ?route_number=X (exact details)
    path('routes/info/', views.get_route_schedule_info),
    path('routes/fare/', views.get_fare_for_route),  # ?route_number=X&source_stop=Y&destination_stop=Z
    path('stops/autocomplete/', views.autocomplete_stops),
    path('routes/plan/', views.plan_journey),
    # Testing endpoints
    path('routes/test-redis/', views.test_redis_connectivity),
    # Data management endpoints
    path('admin/load-data/', load_data_endpoint),
    path('admin/data-status/', data_status),
]
