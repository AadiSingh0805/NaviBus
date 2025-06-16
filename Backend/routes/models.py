from django.db import models
from core.models import Stop  # Make sure Stop has latitude & longitude fields handled

class BusRoute(models.Model):
    """
    Represents a bus route with a unique route number,
    start and end stops, and optional distance.
    """
    route_number = models.CharField(max_length=20, unique=True)
    start_stop = models.ForeignKey(Stop, related_name='route_starts', on_delete=models.CASCADE)
    end_stop = models.ForeignKey(Stop, related_name='route_ends', on_delete=models.CASCADE)
    distance_km = models.FloatField(null=True, blank=True)
    active = models.BooleanField(default=True)

    def __str__(self):
        return f"Route {self.route_number}"


class RouteStop(models.Model):
    """
    Represents an individual stop in a bus route with stop order,
    timing, and fare details.
    """
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE, related_name='route_stops')
    stop = models.ForeignKey(Stop, on_delete=models.CASCADE)
    stop_order = models.PositiveIntegerField()
    distance_from_start = models.FloatField()
    fare_from_prev = models.FloatField(null=True, blank=True)
    arrival_time = models.TimeField(null=True, blank=True)
    departure_time = models.TimeField(null=True, blank=True)
    is_major_stop = models.BooleanField(default=False)

    class Meta:
        unique_together = ('route', 'stop_order')
        ordering = ['stop_order']

    def __str__(self):
        return f"{self.route.route_number} - Stop {self.stop.name} (#{self.stop_order})"


class Bus(models.Model):
    """
    Represents a physical bus assigned to a route.
    """
    bus_identifier = models.CharField(max_length=50, unique=True)  # e.g., "MH-43-A-1234" or "Bus_23"
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE)

    def __str__(self):
        return self.bus_identifier


class Schedule(models.Model):
    """
    Defines a recurring or fixed schedule for buses on a route.
    """
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE)
    bus = models.ForeignKey(Bus, on_delete=models.SET_NULL, null=True, blank=True)
    departure_time = models.TimeField()
    repeat_pattern = models.CharField(max_length=50, default="Daily")  # Future: convert to choices
    valid_from = models.DateField()
    valid_to = models.DateField()

    def __str__(self):
        return f"{self.route.route_number} @ {self.departure_time} ({self.repeat_pattern})"
