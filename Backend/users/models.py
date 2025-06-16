from django.db import models
from django.contrib.auth.models import AbstractUser
from core.models import Stop
from routes.models import BusRoute

class User(AbstractUser):
    pass  

class FavoriteRoute(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'route')

class SearchHistory(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    source_stop = models.ForeignKey(Stop, related_name='searched_from', on_delete=models.CASCADE)
    destination_stop = models.ForeignKey(Stop, related_name='searched_to', on_delete=models.CASCADE)
    searched_at = models.DateTimeField(auto_now_add=True)
    suggested_route = models.ForeignKey(BusRoute, on_delete=models.SET_NULL, null=True, blank=True)
