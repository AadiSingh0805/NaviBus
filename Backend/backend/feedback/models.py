from django.db import models

class Feedback(models.Model):
    CATEGORY_CHOICES = [
        ('Bus Delay', 'Bus Delay'),
        ('App Bug', 'App Bug'),
        ('Payment Issue', 'Payment Issue'),
        ('Driver Behavior', 'Driver Behavior'),
        ('Other', 'Other'),
    ]

    name = models.CharField(max_length=100)  # Customer Name
    category = models.CharField(max_length=50, choices=CATEGORY_CHOICES)
    description = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} - {self.category}"
