import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api_constants.dart';
import '../services/local_service.dart';
import '../core/localization.dart';
import '../services/biometric_service.dart';

class TerminalWidget extends StatefulWidget {
  final String id;
  final String title;
  final bool isEditMode;
  final bool isLocalMode;
  final bool requireBiometric;

  const TerminalWidget({super.key, required this.id, required this.title, required this.isEditMode, this.isLocalMode = false, this.requireBiometric = false});

  // Static registry to append logs to active Terminal widgets instantly from voice commands!
  static final Map<String, void Function(String message)> activeTerminals = {};

  @override
  State<TerminalWidget> createState() => _TerminalWidgetState();
}

class _TerminalWidgetState extends State<TerminalWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _logs = [];

  @override
  void dispose() {
    TerminalWidget.activeTerminals.remove(widget.id);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    
    // Register this terminal instance to receive instant voice/command logs locally
    TerminalWidget.activeTerminals[widget.id] = (message) {
      if (mounted) {
         setState(() {
            _logs.add({"message": message, "type": "sent"});
         });
         _scrollToBottom();
      }
    };
    
    // Initial connection message
    _logs.add({'message': 'System initialized. Awaiting commands...', 'type': 'system'});

    SocketService.socket?.on('terminal-message', (data) {
       if (data['widgetId'] == widget.id && mounted) {
           setState(() {
              _logs.add({
                 'message': data['message'],
                 'type': data['type'] ?? 'received'
              });
           });
           _scrollToBottom();
       }
    });
  }

  void _fetchLogs() async {
     // Local mode doesn't fetch logs from server yet
     if (widget.isLocalMode) {
       if (mounted) setState(() => _logs.add({'message': 'Local mode terminal ready.', 'type': 'system'}));
       return;
     }

     try {
         final token = await ApiService.getToken();
         if (token == null || token.isEmpty) {
           if (mounted) setState(() => _logs.add({'message': 'No auth token found. Please login again.', 'type': 'error'}));
           return;
         }
         final res = await http.get(
            Uri.parse('${ApiConstants.baseUrl}/api/terminals/${widget.id}/messages'),
            // Use x-auth-token header (matches server expectations)
            headers: {'x-auth-token': token, 'Content-Type': 'application/json'}
         );
         if (res.statusCode == 200 && mounted) {
             final List<dynamic> data = json.decode(res.body);
             setState(() {
                _logs.clear();
                _logs.add({'message': 'Secure connection established. Last ${data.length} logs fetched.', 'type': 'system'});
                // data is newest first. We take the 50 newest, then reverse them so oldest is first.
                for (var msg in data.take(50).toList().reversed) {
                   _logs.add({'message': msg['message'], 'type': msg['type']});
                }
             });
             _scrollToBottom();
         } else if (mounted) {
           setState(() => _logs.add({'message': 'Server error ${res.statusCode}. Check your connection.', 'type': 'error'}));
         }
     } catch (e) {
         if (mounted) setState(() => _logs.add({'message': 'ERROR: Failed to connect to secure relay.', 'type': 'error'}));
     }
  }

  void _scrollToBottom() {
      Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
              _scrollController.animateTo(
                 _scrollController.position.maxScrollExtent,
                 duration: const Duration(milliseconds: 200),
                 curve: Curves.easeOut,
              );
          }
      });
  }

  void _sendCommand() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      if (text.toLowerCase() == 'clear') {
         setState(() => _logs.clear());
         _controller.clear();
         return;
      }
      
      if (widget.requireBiometric) {
        bool auth = await BiometricService.authenticate(context);
        if (!auth) return;
      }
      
      setState(() {
        _logs.add({"message": text, "type": "sent"});
      });
      _scrollToBottom();
      _controller.clear();
      
      try {
         if (widget.isLocalMode) {
           await LocalService.sendCommand(widget.id, text);
           if (mounted) {
              setState(() { _logs.add({"message": "✅", "type": "system"}); });
           }
         } else {
           await ApiService.sendCommand(widget.id, text);
         }
      } catch (e) {
         if (mounted) {
            setState(() { _logs.add({"message": "CONNECTION FATAL ERROR: $e", "type": "error"}); });
            _scrollToBottom();
         }
      }
    }
  }

  Color _getLogColor(String type) {
     switch (type) {
        case 'sent': return Colors.cyanAccent.shade400;
        case 'received': return Colors.greenAccent.shade400;
        case 'system': return Colors.amberAccent;
        case 'error': return Colors.redAccent.shade400;
        default: return Colors.white70;
     }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF030507),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
           BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: -2)
        ]
      ),
      child: IgnorePointer(
        ignoring: widget.isEditMode,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mac-style Terminal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF10141a),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: Colors.white10))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                     children: [
                        _buildDot(Colors.redAccent),
                        const SizedBox(width: 6),
                        _buildDot(Colors.amber),
                        const SizedBox(width: 6),
                        _buildDot(Colors.greenAccent),
                     ],
                  ),
                  Text(widget.title.toUpperCase(), style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Courier', letterSpacing: 1.2)),
                  GestureDetector(
                    onTap: _fetchLogs,
                    child: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 16),
                  ),
                ],
              ),
            ),
            
            // Terminal Body
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final isSent = log['type'] == 'sent';
                    final isSys = log['type'] == 'system' || log['type'] == 'error';
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: RichText(
                         text: TextSpan(
                            children: [
                               if (!isSys) TextSpan(text: isSent ? "user@device:~\$ " : "[relay] >> ", style: const TextStyle(color: Colors.white54, fontFamily: 'Courier', fontSize: 11)),
                               TextSpan(text: log['message'], style: TextStyle(
                                  fontFamily: 'Courier',
                                  color: _getLogColor(log['type']),
                                  fontSize: 12,
                                  fontWeight: isSent ? FontWeight.bold : FontWeight.normal
                               )),
                            ]
                         )
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Input Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: const BoxDecoration(
                 color: Color(0xFF10141a),
                 borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                 border: Border(top: BorderSide(color: Colors.white10))
              ),
              child: Row(
                children: [
                  const Text("root:~\$ ", style: TextStyle(color: Colors.amberAccent, fontFamily: 'Courier', fontSize: 13)),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(fontFamily: 'Courier', color: Colors.cyanAccent, fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: AppLocalization.get('terminal_hint'),
                        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
                        contentPadding: EdgeInsets.zero,
                        isDense: true
                      ),
                      onSubmitted: (_) => _sendCommand(),
                    ),
                  ),
                  InkWell(
                     onTap: _sendCommand,
                     child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.cyanAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.send, size: 16, color: Colors.cyanAccent),
                     ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  
  Widget _buildDot(Color color) {
     return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
