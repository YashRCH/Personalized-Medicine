import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Advisor AI',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF343541),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF343541),
          elevation: 1,
        ),
      ),
      home: const ChatScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? explanation;
  final List<dynamic>? citations;

  ChatMessage({required this.text, required this.isUser, this.explanation, this.citations});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [
    ChatMessage(text: 'Hello! I am your AI medical assistant. How can I help you today?', isUser: false),
  ];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, dynamic> _biomarkers = {};

  Future<void> _uploadReport() async {
    PlatformFile? result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (result != null && result.path != null) {
      final filePath = result.path!;
      
      setState(() {
        _messages.add(ChatMessage(text: 'Uploading report...', isUser: true));
      });
      _scrollToBottom();
      
      try {
        final apiUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
        var request = http.MultipartRequest('POST', Uri.parse('$apiUrl/upload-report'));
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
        
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            _biomarkers = data['biomarkers'];
            String keys = _biomarkers.keys.join(', ');
            _messages.add(ChatMessage(
              text: 'Successfully extracted biomarkers: $keys.\n\nYou can now ask me questions about your report.',
              isUser: false,
            ));
          });
          _scrollToBottom();
        } else {
          setState(() {
            _messages.add(ChatMessage(text: 'Failed to extract report. Status: ${response.statusCode}', isUser: false));
          });
        }
      } catch (e) {
        setState(() {
          _messages.add(ChatMessage(text: 'Error uploading report: $e', isUser: false));
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _scrollToBottom();
    
    try {
      final apiUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final response = await http.post(
        Uri.parse('$apiUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'query': text,
          'biomarkers': _biomarkers, 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final respObj = data['response'];
        if (respObj is Map) {
          final advice = respObj['advice'] ?? 'No advice provided';
          final explanation = respObj['explanation'];
          final citations = respObj['citations'];
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(
                text: advice, 
                isUser: false,
                explanation: explanation,
                citations: citations,
              ));
            });
            _scrollToBottom();
          }
        } else {
          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(text: respObj.toString(), isUser: false));
            });
            _scrollToBottom();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _messages.add(ChatMessage(text: 'Error connecting to backend: ${response.statusCode}', isUser: false));
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: 'Failed to connect to backend: $e', isUser: false));
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(ChatMessage message) {
    final bgColor = message.isUser ? const Color(0xFF343541) : const Color(0xFF444654);
    final avatarColor = message.isUser ? const Color(0xFF5436DA) : const Color(0xFF10A37F);
    final avatarIcon = message.isUser ? Icons.person : Icons.auto_awesome;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
      color: bgColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: avatarColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(avatarIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: Color(0xFFECECF1),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      if (message.explanation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Reasoning', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                message.explanation!,
                                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (message.citations != null && message.citations!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: message.citations!.map((c) => Chip(
                            label: Text(c.toString(), style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.transparent,
                            side: const BorderSide(color: Color(0xFF10A37F)),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      backgroundColor: const Color(0xFF202123),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
               padding: const EdgeInsets.all(12.0),
               child: OutlinedButton.icon(
                 onPressed: () {},
                 icon: const Icon(Icons.add, color: Colors.white),
                 label: const Text('New Chat', style: TextStyle(color: Colors.white)),
                 style: OutlinedButton.styleFrom(
                   minimumSize: const Size(double.infinity, 45),
                   alignment: Alignment.centerLeft,
                   side: const BorderSide(color: Color(0xFF4D4D4F)),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                 ),
               ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildHistoryItem('Current Conversation', true),
                  _buildHistoryItem('Previous Consult', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minLeadingWidth: 20,
        dense: true,
        onTap: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    
    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text('Health Advisor AI', style: TextStyle(fontSize: 16)),
        centerTitle: true,
      ),
      drawer: isDesktop ? null : _buildSidebar(),
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 260, child: _buildSidebar()),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text('How can I help you today?',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white70)),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return _buildMessage(_messages[index]);
                          },
                        ),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF353740).withValues(alpha: 0),
            const Color(0xFF343541),
          ],
          stops: const [0.0, 0.5],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              if (_biomarkers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Color(0xFF10A37F), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Report loaded with ${_biomarkers.length} biomarkers',
                        style: const TextStyle(color: Color(0xFF10A37F), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF40414F),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file, color: Colors.white70),
                      onPressed: _uploadReport,
                      tooltip: 'Upload Blood Report',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        onSubmitted: _handleSubmitted,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Message Health Advisor...',
                          hintStyle: TextStyle(color: Color(0xFFC5C5D2)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFF10A37F)),
                      onPressed: () => _handleSubmitted(_textController.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'AI can make mistakes. Consider verifying important information.',
                style: TextStyle(color: Color(0xFFC5C5D2), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
