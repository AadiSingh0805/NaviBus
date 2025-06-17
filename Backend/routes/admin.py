from django.contrib import admin
from .models import BusRoute, RouteStop

admin.site.register(BusRoute)
admin.site.register(RouteStop)
