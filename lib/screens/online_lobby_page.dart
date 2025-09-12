import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';            // <-- NEW
import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/game_logic/online_controller.dart';
import 'package:invisitactoe/screens/online_match_page.dart';

class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({super.key});

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> {
  String? shareCode;
  bool busy = false;
  String? error;
  final joinCtrl = TextEditingController();

  @override
  void dispose() {
    joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureAuthed() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  Future<void> _createRoomFlow() async {
    setState(() { busy = true; error = null; });
    try {
      await _ensureAuthed();  // <-- ensure we have a user
      final (controller, code) = await OnlineController.createRoom();
      setState(() => shareCode = code);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Share this code'),
          content: SelectableText(
            code,
            style: const TextStyle(fontSize: 22, letterSpacing: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code)),
              child: const Text('Copy'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineMatchPage(title: 'Online (You are X)', controller: controller),
        ),
      );

      if (!mounted) return;
      setState(() { shareCode = null; joinCtrl.clear(); });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _joinRoomFlow() async {
    setState(() { busy = true; error = null; });
    try {
      await _ensureAuthed();  // <-- ensure we have a user
      final code = joinCtrl.text.trim().toUpperCase();
      if (code.isEmpty) throw Exception('Enter a room code.');
      final controller = await OnlineController.joinWithCode(code);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineMatchPage(title: 'Online (You are O)', controller: controller),
        ),
      );

      if (!mounted) return;
      setState(() { shareCode = null; joinCtrl.clear(); });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Hero(
              tag: '__notebook_bg__',
              child: Image.asset(BackgroundManager.current, fit: BoxFit.cover),
            ),
          ),

          // Back
          Positioned(
            top: safeTop + 12,
            left: 25,
            child: PaperButton(
              onTap: () => Navigator.pop(context),
              child: Image.asset('assets/images/back_arrow_handwritten.png', width: 40, height: 40),
            ),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: screenW * 0.02),

                    // Create room
                    PaperButton(
                      onTap: () { if (!busy) _createRoomFlow(); },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text('Create Room'),
                      ),
                    ),

                    if (shareCode != null) ...[
                      const SizedBox(height: 8),
                      SelectableText('Code: $shareCode'),
                    ],

                    const SizedBox(height: 24),

                    // Join by code
                    TextField(
                      controller: joinCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) { if (!busy) _joinRoomFlow(); },
                      decoration: InputDecoration(
                        labelText: 'Enter room code',
                        border: const OutlineInputBorder(),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Paste',
                              icon: const Icon(Icons.paste),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  joinCtrl.text = data!.text!.trim().toUpperCase();
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.clear),
                              onPressed: () => joinCtrl.clear(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    PaperButton(
                      onTap: () { if (!busy) _joinRoomFlow(); },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        child: Text('Join'),
                      ),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                    ],

                    if (busy) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
