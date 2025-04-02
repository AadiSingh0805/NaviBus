from django.urls import path, include
from django.contrib import admin

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),  # Replace 'your_app_name' with your actual app name
    path('feedback/', include('feedback.urls')),  # Ensure feedback API is included
]
