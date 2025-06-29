# Generated by Django 5.2.1 on 2025-06-17 15:48

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('routes', '0002_remove_busroute_distance_km_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='busroute',
            name='fare_inr',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=6, null=True),
        ),
        migrations.AddField(
            model_name='busroute',
            name='first_bus_time',
            field=models.TimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='busroute',
            name='frequency_minutes',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='busroute',
            name='last_bus_time',
            field=models.TimeField(blank=True, null=True),
        ),
    ]
