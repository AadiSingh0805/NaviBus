import 'package:flutter/material.dart';
import 'package:navibus/services/data_service.dart';
import 'package:navibus/utils/data_sync_util.dart';

class OfflineNotificationBanner extends StatefulWidget {
  const OfflineNotificationBanner({super.key});

  @override
  State<OfflineNotificationBanner> createState() => _OfflineNotificationBannerState();
}

class _OfflineNotificationBannerState extends State<OfflineNotificationBanner> {
  bool isVisible = false;
  String message = '';
  bool isBackendAvailable = true;

  @override
  void initState() {
    super.initState();
    _checkDataSource();
  }

  Future<void> _checkDataSource() async {
    try {
      final dataService = DataService.instance;
      final backendAvailable = await dataService.isBackendAvailable();
      final hasOfflineData = await DataSyncUtil.hasOfflineData();
      
      setState(() {
        isBackendAvailable = backendAvailable;
        
        if (!backendAvailable && hasOfflineData) {
          // Backend down, using offline data
          isVisible = true;
          message = '📱 Using offline data - Backend unavailable';
        } else if (!backendAvailable && !hasOfflineData) {
          // Backend down, no offline data
          isVisible = true;
          message = '⚠️ Backend unavailable - Limited functionality';
        } else if (backendAvailable && hasOfflineData) {
          // Backend available but user has offline data downloaded
          isVisible = false; // Don't show when backend is working
          message = '✅ Backend connected';
        } else {
          // Normal operation
          isVisible = false;
          message = '';
        }
      });
    } catch (e) {
      setState(() {
        isVisible = true;
        message = '❓ Connection status unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isVisible || message.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBackendAvailable 
            ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)] // Green for online
            : [const Color(0xFFFF9800), const Color(0xFFF57C00)], // Orange for offline
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isBackendAvailable ? Icons.cloud_done : Icons.cloud_off,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isBackendAvailable)
            IconButton(
              onPressed: () {
                setState(() {
                  isVisible = false;
                });
              },
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
              padding: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}

class DataDownloadWidget extends StatefulWidget {
  const DataDownloadWidget({super.key});

  @override
  State<DataDownloadWidget> createState() => _DataDownloadWidgetState();
}

class _DataDownloadWidgetState extends State<DataDownloadWidget> {
  bool isDownloading = false;
  bool hasOfflineData = false;
  String offlineDataInfo = '';

  @override
  void initState() {
    super.initState();
    _checkOfflineData();
  }

  Future<void> _checkOfflineData() async {
    final hasData = await DataSyncUtil.hasOfflineData();
    final info = await DataSyncUtil.getOfflineDataInfo();
    
    setState(() {
      hasOfflineData = hasData;
      offlineDataInfo = info['message'] ?? '';
    });
  }

  Future<void> _downloadData() async {
    setState(() {
      isDownloading = true;
    });

    final result = await DataSyncUtil.downloadLatestData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      
      if (result['success']) {
        await _checkOfflineData();
      }
    }

    setState(() {
      isDownloading = false;
    });
  }

  Future<void> _clearData() async {
    final success = await DataSyncUtil.clearOfflineData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Offline data cleared' : 'Failed to clear data'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      
      if (success) {
        await _checkOfflineData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.download_for_offline,
                  color: const Color(0xFF042F40),
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Offline Data',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF042F40),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (hasOfflineData) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        offlineDataInfo,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            Text(
              hasOfflineData 
                ? 'Update your offline data to get the latest routes and schedules.'
                : 'Download route data for offline use when the backend is unavailable.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isDownloading ? null : _downloadData,
                    icon: isDownloading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.download, color: Colors.white),
                    label: Text(
                      hasOfflineData 
                        ? (isDownloading ? 'Updating...' : 'Update Data')
                        : (isDownloading ? 'Downloading...' : 'Download Data'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF042F40),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                if (hasOfflineData) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _clearData,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Clear', style: TextStyle(color: Colors.red)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
