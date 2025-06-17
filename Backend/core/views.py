from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Stop
from .serializers import StopSerializer

@api_view(['GET'])
def get_all_stops(request):
    stops = Stop.objects.all()
    serializer = StopSerializer(stops, many=True)
    return Response(serializer.data)

@api_view(['POST'])
def add_stop(request):
    serializer = StopSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
