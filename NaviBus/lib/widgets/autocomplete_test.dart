import 'package:flutter/material.dart';
import 'package:navibus/services/data_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AutocompleteTestWidget extends StatefulWidget {
  const AutocompleteTestWidget({super.key});

  @override
  State<AutocompleteTestWidget> createState() => _AutocompleteTestWidgetState();
}

class _AutocompleteTestWidgetState extends State<AutocompleteTestWidget> {
  String _testResult = '';
  bool _isLoading = false;

  Future<void> _testAutocomplete() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing autocomplete...';
    });

    try {
      final dataService = DataService.instance;
      final backendUrl = await dataService.getCurrentBackendUrl();
      final testQuery = 'mum'; // Common test query
      final url = Uri.parse('$backendUrl/api/stops/autocomplete/?q=$testQuery');
      
      print('Testing autocomplete endpoint: $url');
      
      final response = await http.get(url).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = List<String>.from(data['results'] ?? []);
        
        setState(() {
          _testResult = '''✅ Autocomplete Working!
Backend: $backendUrl
Query: "$testQuery"
Results (${results.length}):
${results.take(5).join('\n')}
${results.length > 5 ? '... and ${results.length - 5} more' : ''}

Response time: ${data['time']?.toStringAsFixed(2) ?? 'N/A'}s
Cached: ${data['cached'] ?? false}''';
        });
      } else {
        setState(() {
          _testResult = '''❌ Autocomplete Failed
Backend: $backendUrl
Status: ${response.statusCode}
Response: ${response.body}''';
        });
      }
    } catch (e) {
      setState(() {
        _testResult = '''❌ Autocomplete Error
Error: $e''';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Autocomplete Test',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testAutocomplete,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF042F40),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text('Testing...', style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : Text('Test Autocomplete', style: TextStyle(color: Colors.white)),
            ),
            if (_testResult.isNotEmpty) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  _testResult,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
