import 'package:flutter/material.dart';
import 'package:navibus/services/notification_service.dart';

class NotificationControlPage extends StatefulWidget {
  const NotificationControlPage({super.key});

  @override
  State<NotificationControlPage> createState() => _NotificationControlPageState();
}

class _NotificationControlPageState extends State<NotificationControlPage> {
  final TextEditingController _customMessageController = TextEditingController();

  final List<Map<String, String>> _templates = const [
    {
      'title': 'Your Scheduled Bus Has Arrived',
      'body': 'Route C-1 is now at Vashi Station. Please board on time.'
    },
    {
      'title': 'Bus Strike Today',
      'body': 'Important update: Limited service due to city-wide bus strike today.'
    },
    {
      'title': 'Bus Running Late',
      'body': 'Route 305 is delayed by 12 minutes due to traffic near CBD Belapur.'
    },
  ];

  int _selectedTemplateIndex = 0;
  double _delaySeconds = 0;
  bool _isSending = false;
  final List<String> _activityLog = [];

  @override
  void dispose() {
    _customMessageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final selectedTemplate = _templates[_selectedTemplateIndex];
      final title = selectedTemplate['title']!;
      final customBody = _customMessageController.text.trim();
      final body = customBody.isNotEmpty ? customBody : selectedTemplate['body']!;
      final delay = Duration(seconds: _delaySeconds.round());

      await NotificationService.instance.sendAfter(
        title: title,
        body: body,
        delay: delay,
      );

      final now = TimeOfDay.now().format(context);
      final deliveryInfo = delay.inSeconds == 0
          ? 'sent instantly'
          : 'scheduled in ${delay.inSeconds}s';

      if (!mounted) {
        return;
      }

      setState(() {
        _activityLog.insert(0, '$now - $title ($deliveryInfo)');
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification $deliveryInfo'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedTemplate = _templates[_selectedTemplateIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F5),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFD62828),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 56, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    ),
                    const Text(
                      'Notification Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Send live transport alerts to this device for prototype testing.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    title: 'Alert Templates',
                    child: Column(
                      children: List.generate(_templates.length, (index) {
                        final template = _templates[index];
                        final isSelected = index == _selectedTemplateIndex;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTemplateIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFECEC) : const Color(0xFFF5F5F6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFD62828) : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: const Color(0xFFD62828),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        template['title']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        template['body']!,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    title: 'Custom Message (Optional)',
                    child: TextField(
                      controller: _customMessageController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type your own update or keep template text',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _section(
                    title: 'Delivery Delay',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              _delaySeconds == 0
                                  ? 'Send instantly'
                                  : 'Send in ${_delaySeconds.round()} seconds',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Slider(
                          value: _delaySeconds,
                          min: 0,
                          max: 60,
                          divisions: 12,
                          activeColor: const Color(0xFFD62828),
                          onChanged: (value) {
                            setState(() {
                              _delaySeconds = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendNotification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.notifications_active_outlined),
                      label: Text(
                        _isSending
                            ? 'Sending...'
                            : 'Send "${selectedTemplate['title']}"',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    title: 'Dispatch Activity',
                    child: _activityLog.isEmpty
                        ? const Text(
                            'No notifications sent yet.',
                            style: TextStyle(color: Color(0xFF6B7280)),
                          )
                        : Column(
                            children: _activityLog
                                .map(
                                  (entry) => Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F5F6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(entry),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
