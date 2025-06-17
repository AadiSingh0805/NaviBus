from django.urls import path
from . import views

urlpatterns = [
    path('stops/', views.get_all_stops),
    path('stops/add/', views.add_stop),
]
