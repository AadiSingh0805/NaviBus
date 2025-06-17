from django.db import models
from core.models import Stop  # Importing Stop model from core

class BusRoute(models.Model):
    route_number = models.CharField(max_length=20, unique=True, db_index=True)
    source_destination = models.CharField(max_length=255, null=True, blank=True)
    start_stop = models.ForeignKey(Stop, related_name='route_starts', on_delete=models.CASCADE)
    end_stop = models.ForeignKey(Stop, related_name='route_ends', on_delete=models.CASCADE)
    active = models.BooleanField(default=True)

    # New fields
    first_bus_time_weekday = models.TimeField(null=True, blank=True)
    last_bus_time_weekday = models.TimeField(null=True, blank=True)
    first_bus_time_sunday = models.TimeField(null=True, blank=True)
    last_bus_time_sunday = models.TimeField(null=True, blank=True)
    average_frequency_minutes = models.IntegerField(null=True, blank=True)
    average_frequency_minutes_sunday = models.IntegerField(null=True, blank=True)
    average_fare = models.FloatField(null=True, blank=True)

    def __str__(self):
        return f"Route {self.route_number} ({self.start_stop.name} → {self.end_stop.name})"




class RouteStop(models.Model):
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE, related_name='route_stops')
    stop = models.ForeignKey(Stop, on_delete=models.CASCADE)
    stop_order = models.PositiveIntegerField()

    class Meta:
        unique_together = ('route', 'stop_order')
        ordering = ['stop_order']
        indexes = [
            models.Index(fields=['route', 'stop']),
            models.Index(fields=['stop']),
        ]

    def __str__(self):
        return f"{self.route.route_number} - Stop {self.stop.name} (#{self.stop_order})"


class Bus(models.Model):
    bus_identifier = models.CharField(max_length=50, unique=True, db_index=True)
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE, related_name='buses')
    status = models.CharField(max_length=20, default="In Service")  # e.g., "In Service", "Out of Service"
    capacity = models.PositiveIntegerField(null=True, blank=True)  # e.g., 50 passengers

    def __str__(self):
        return self.bus_identifier


class Schedule(models.Model):
    """
    Defines a recurring or fixed schedule for buses on a route.
    """
    route = models.ForeignKey(BusRoute, on_delete=models.CASCADE)
    bus = models.ForeignKey(Bus, on_delete=models.SET_NULL, null=True, blank=True)
    departure_time = models.TimeField(null=True, blank=True)  # Not populated now
    repeat_pattern = models.CharField(max_length=50, default="Daily", null=True, blank=True)  # Future: convert to choices
    valid_from = models.DateField(null=True, blank=True)
    valid_to = models.DateField(null=True, blank=True)

    def __str__(self):
        return f"{self.route.route_number} @ {self.departure_time} ({self.repeat_pattern})"