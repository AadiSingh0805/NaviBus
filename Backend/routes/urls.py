from django.urls import path
from . import views

urlpatterns = [
    path('routes/', views.get_all_routes),
    path('routes/add/', views.add_route),
    path('routes/search/', views.search_route_path),  # ?start=X&end=Y
    path('routes/info/', views.get_route_schedule_info),
]
