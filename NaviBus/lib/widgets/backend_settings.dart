import 'package:flutter/material.dart';
import 'package:navibus/services/data_service.dart';

class BackendSettingsWidget extends StatefulWidget {
  @override
  _BackendSettingsWidgetState createState() => _BackendSettingsWidgetState();
}

class _BackendSettingsWidgetState extends State<BackendSettingsWidget> {
  bool _useProduction = false;
  bool _loading = true;
  Map<String, dynamic> _backendInfo = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final dataService = DataService.instance;
    final backendInfo = await dataService.getBackendInfo();
    
    setState(() {
      _backendInfo = backendInfo;
      _useProduction = backendInfo['isProduction'] ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleBackend(bool useProduction) async {
    setState(() => _loading = true);
    
    final dataService = DataService.instance;
    await dataService.setBackendMode(useProduction: useProduction);
    
    // Refresh backend info
    await _loadCurrentSettings();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(useProduction 
          ? 'Switched to Production Backend' 
          : 'Switched to Development Backend'),
        backgroundColor: Color(0xFF042F40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading backend info...'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _backendInfo['status'] == true ? Icons.cloud_done : Icons.cloud_off,
                  color: _backendInfo['status'] == true ? Colors.green : Colors.red,
                ),
                SizedBox(width: 8),
                Text(
                  'Backend: ${_backendInfo['mode'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'URL: ${_backendInfo['url'] ?? 'Unknown'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(height: 12),
            SwitchListTile(
              title: Text('Use Production Backend'),
              subtitle: Text(_useProduction 
                ? 'Using Render backend (online)' 
                : 'Using local development server'),
              value: _useProduction,
              onChanged: _toggleBackend,
              activeColor: Color(0xFF042F40),
            ),
          ],
        ),
      ),
    );
  }
}
