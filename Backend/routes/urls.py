from django.urls import path
from . import views
from .data_loader import load_data_endpoint, data_status

urlpatterns = [
    path('routes/', views.get_all_routes),
    path('routes/add/', views.add_route),
    path('routes/search/', views.search_route_path),  # ?start=X&end=Y
    path('routes/info/', views.get_route_schedule_info),
    path('routes/fare/', views.get_fare_for_route),  # ?route_number=X&source_stop=Y&destination_stop=Z
    path('stops/autocomplete/', views.autocomplete_stops),
    path('routes/plan/', views.plan_journey),
    # Data management endpoints
    path('admin/load-data/', load_data_endpoint),
    path('admin/data-status/', data_status),
]
