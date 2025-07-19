import 'package:flutter_test/flutter_test.dart';
import 'package:navibus/services/data_service.dart';

void main() {
  group('DataService Tests', () {
    late DataService dataService;

    setUpAll(() async {
      // Initialize Flutter bindings for testing
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      dataService = DataService.instance;
    });

    test('should be singleton', () {
      final instance1 = DataService.instance;
      final instance2 = DataService.instance;
      expect(instance1, same(instance2));
    });

    test('should get data source info', () async {
      final info = await dataService.getDataSourceInfo();
      expect(info, isNotEmpty);
      expect(info.contains('Data') || info.contains('Mode') || info.contains('❓'), isTrue);
    });

    test('should check backend availability', () async {
      final isAvailable = await dataService.isBackendAvailable();
      expect(isAvailable, isA<bool>());
    });

    test('should get all data (fallback to assets)', () async {
      final data = await dataService.getAllData();
      expect(data, isA<Map<String, dynamic>>());
      expect(data.containsKey('routes'), isTrue);
      expect(data.containsKey('stops'), isTrue);
      expect(data.containsKey('source'), isTrue);
    });

    test('should search routes locally', () async {
      final routes = await dataService.searchRoutes('Vashi', 'Thane');
      expect(routes, isA<List<dynamic>>());
      // Should either find routes or return empty list
    });

    test('should get stop suggestions', () async {
      final suggestions = await dataService.getStopSuggestions('Vashi');
      expect(suggestions, isA<List<String>>());
      // Should either find suggestions or return empty list
    });

    test('should calculate fare locally', () async {
      final fareData = await dataService.getFare(
        routeNumber: '8',
        sourceStop: 'Vashi',
        destinationStop: 'Thane',
      );
      expect(fareData, isA<Map<String, dynamic>>());
      expect(fareData.containsKey('fare'), isTrue);
    });
  });
}
