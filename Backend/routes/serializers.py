from rest_framework import serializers
from .models import BusRoute
from core.models import Stop

class StopSerializer(serializers.ModelSerializer):
    class Meta:
        model = Stop
        fields = '__all__'

class BusRouteSerializer(serializers.ModelSerializer):
    start_stop = serializers.SlugRelatedField(slug_field='name', queryset=Stop.objects.all())
    end_stop = serializers.SlugRelatedField(slug_field='name', queryset=Stop.objects.all())

    class Meta:
        model = BusRoute
        fields = '__all__'