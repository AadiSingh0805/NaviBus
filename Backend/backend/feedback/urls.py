from django.urls import path
from .views import feedback_list_create, feedback_detail

urlpatterns = [
    path('feedback/', feedback_list_create, name='feedback-list-create'),
    path('feedback/<int:pk>/', feedback_detail, name='feedback-detail'),
]
