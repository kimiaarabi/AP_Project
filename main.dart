import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';


class ServerSong {
  final String title;
  final String filename;
  final String? artist;

  ServerSong({required this.title, required this.filename, this.artist});

  factory ServerSong.fromJson(Map<String, dynamic> json) {
    return ServerSong(
      title: json['title'] ?? 'Unknown Title',
      filename: json['filename'] ?? json['filenameOrId'] ?? 'Unknown Filename',
      artist: json['artist'],
    );
  }
}

class Playlist {
  final String name;
  final int songCount;
  final List<String> songIdentifiers;

  Playlist({required this.name, required this.songCount, required this.songIdentifiers});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'] ?? 'Unknown Playlist',
      songCount: json['song_count'] ?? 0,
      songIdentifiers: json['songs'] != null ? List<String>.from(json['songs']) : [],
    );

  }
}
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            textStyle: const TextStyle(fontSize: 16, color: Colors.white),


          ),
        ),
      ),
      home: const LoginPage(),
    );
  }
}


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  final TextEditingController _ipController = TextEditingController(text: '10.0.2.2');
  final TextEditingController _portController = TextEditingController(text: '12345');

  final TextEditingController _emailController = TextEditingController(text: "test@example.com");
  final TextEditingController _passwordController = TextEditingController(text: "password123");
  bool _isLoading = false;
  String _loginPageMessage = '';

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  Future<void> _handleEmailLogin() async {
    if (!mounted) return;
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() { _loginPageMessage = 'لطفاً ایمیل و رمز عبور را وارد کنید.';});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage)));
      return;
    }
    setState(() { _isLoading = true; _loginPageMessage = 'در حال اتصال و ارسال اطلاعات...'; });

    Socket? loginSocket;
    try {
      loginSocket = await Socket.connect(
        _ipController.text,
        int.parse(_portController.text),
        timeout: const Duration(seconds: 5),
      );

      if (!mounted) { loginSocket.destroy(); return; }

      Map<String, dynamic> loginData = {
        'action': 'login_email',
        'email': _emailController.text,
        'password': _passwordController.text,
      };
      loginSocket.writeln(jsonEncode(loginData));
      print("Login attempt sent: ${jsonEncode(loginData)}");

      await loginSocket.firstWhere((data) {
        final responseStr = utf8.decode(data).trim();
        print("Login response from server: $responseStr");
        if (!mounted) return true;

        try {
          final decodedJson = jsonDecode(responseStr);
          if (decodedJson is Map && decodedJson['status'] == 'success') {
            setState(() { _loginPageMessage = 'ورود موفقیت آمیز بود!'; _isLoading = false; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.green));
            _navigateToHome();
            return true;
          } else {
            String errorMessage = decodedJson is Map ? (decodedJson['message'] ?? 'خطای نامشخص در ورود.') : 'پاسخ نامعتبر از سرور.';
            setState(() { _loginPageMessage = errorMessage; _isLoading = false; });
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.red));
            return true;
          }
        } catch (e) {
          setState(() { _loginPageMessage = 'خطا در پردازش پاسخ سرور.'; _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.red));
          return true;
        }
      }).timeout(const Duration(seconds: 5), onTimeout: (){
        if (!mounted) return ;
        setState(() { _loginPageMessage = 'پاسخی از سرور دریافت نشد (тайм-аут).'; _isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.orange));
      });

    } on SocketException catch (e) {
      if (!mounted) return;
      setState(() { _loginPageMessage = 'خطای اتصال: ${e.osError?.message ?? e.message}'; _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      setState(() { _loginPageMessage = 'خطای ناشناخته: $e'; _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_loginPageMessage), backgroundColor: Colors.red));
    } finally {
      loginSocket?.destroy();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loginPageMessage = ''; });
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (!mounted) return;
      if (googleUser == null) {
        setState(() { _isLoading = false; });
        return;
      }
      print('Google Sign-In success: ${googleUser.displayName}');
      setState(() { _isLoading = false; });
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('ورود با گوگل موفقیت آمیز بود: ${googleUser.displayName}'), backgroundColor: Colors.green,));
      }
      _navigateToHome();
    } catch (error) {
      print('Google Sign-In error: $error');
      if (!mounted) return;
      setState(() { _isLoading = false; });
      if (scaffoldMessenger.mounted) {
        scaffoldMessenger.showSnackBar(SnackBar(content: Text('خطا در ورود با گوگل: $error'), backgroundColor: Colors.red,));
      }
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => MyHomePage(title: 'Music App Home', serverIp: _ipController.text, serverPort: _portController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(
                Icons.music_note_rounded,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'به اپلیکیشن موسیقی خوش آمدید',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColorDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'برای ادامه وارد شوید',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'IP سرور',
                        prefixIcon: Icon(Icons.computer_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'پورت',
                        prefixIcon: Icon(Icons.settings_ethernet_outlined),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'ایمیل',
                  prefixIcon: Icon(Icons.email_outlined),
                  hintText: 'test@example.com',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز عبور',
                  prefixIcon: Icon(Icons.lock_outline),
                  hintText: 'password123',
                ),
              ),
              const SizedBox(height: 12),
              if (_loginPageMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical:8.0),
                  child: Text(_loginPageMessage, style: TextStyle(color: _loginPageMessage.contains("موفق") ? Colors.green : Colors.red), textAlign: TextAlign.center,),
                ),
              const SizedBox(height: 12),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _handleEmailLogin,
                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                child: const Text('ورود', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text('یا', style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 24.0,
                  width: 24.0,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata_outlined, size: 24.0),
                ),
                label: const Text('ورود با حساب گوگل'),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 1,
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('صفحه ثبت نام/فراموشی رمز (پیاده‌سازی نشده)')),
                  );
                },
                child: Text('حساب کاربری ندارید؟ ثبت نام کنید', style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, this.serverIp, this.serverPort});
  final String title;
  final String? serverIp;
  final String? serverPort;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  String _serverResponse = 'No response yet.';
  Socket? _socket;
  bool _isConnected = false;

  List<ServerSong> _serverSongs = [];
  List<Playlist> _myPlaylists = [];

  final TextEditingController _echoMessageController = TextEditingController();
  final TextEditingController _songTitleController = TextEditingController();
  final TextEditingController _songArtistController = TextEditingController();
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: widget.serverIp ?? '10.0.2.2');
    _portController = TextEditingController(text: widget.serverPort ?? '12345');

  }

  Future<void> _connectToServer() async {
    if (!mounted) return;
    if (_isConnected && _socket != null) {
      _disconnectFromServer();
      return;
    }
    final String ip = _ipController.text;
    final int? port = int.tryParse(_portController.text);
    if (port == null) {
      setState(() { _serverResponse = "Invalid port number."; });
      return;
    }
    setState(() { _serverResponse = 'Connecting to $ip:$port...'; });
    try {
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      if (!mounted) { _socket?.destroy(); return; }
      _isConnected = true;
      setState(() { _serverResponse = 'Connected to server!'; });

      _fetchServerSongs();
      _fetchMyPlaylists();

      _socket!.listen(
            (List<int> data) {
          if (!mounted) return;
          final String responseStr = utf8.decode(data).trim();
          setState(() { _serverResponse = 'Server: $responseStr'; });
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          try {
            final decodedJson = jsonDecode(responseStr);
            print('JSON from server: $decodedJson');
            if (decodedJson is Map && decodedJson.containsKey('status')) {
              if (decodedJson['status'] == 'success') {
                if (decodedJson['songs'] != null && decodedJson['songs'] is List) {
                  List<dynamic> songsListJson = decodedJson['songs'];
                  if (!mounted) return;
                  setState(() { _serverSongs = songsListJson.map((json) => ServerSong.fromJson(json as Map<String,dynamic>)).toList(); });
                } else if (decodedJson['playlists'] != null && decodedJson['playlists'] is List) {
                  List<dynamic> playlistsJson = decodedJson['playlists'];
                  if (!mounted) return;
                  setState(() { _myPlaylists = playlistsJson.map((json) => Playlist.fromJson(json as Map<String,dynamic>)).toList(); });
                }
                if(decodedJson['message'] != null && scaffoldMessenger.mounted) {
                  scaffoldMessenger.showSnackBar(SnackBar(content: Text('Server: ${decodedJson['message']}'), backgroundColor: Colors.green, duration: const Duration(seconds: 2),));
                }
              } else if (decodedJson['status'] == 'error' && decodedJson['message'] != null && scaffoldMessenger.mounted) {
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: ${decodedJson['message']}'), backgroundColor: Colors.red, duration: const Duration(seconds: 2),));
              } else if (decodedJson['status'] == 'info' && decodedJson['message'] != null && scaffoldMessenger.mounted) {
                scaffoldMessenger.showSnackBar(SnackBar(content: Text('Info: ${decodedJson['message']}'), backgroundColor: Colors.blue, duration: const Duration(seconds: 2),));
              }
            }
          } catch (e) { print('Could not decode JSON from server: $e. Response: $responseStr'); }
        },
        onError: (error) {
          if (!mounted) return;
          setState(() { _serverResponse = 'Server error: $error'; _isConnected = false; });
          _socket?.destroy(); _socket = null;
        },
        onDone: () {
          if (!mounted) return;
          setState(() { _serverResponse = 'Server disconnected.'; _isConnected = false; });
          _socket?.destroy(); _socket = null; _clearData();
        },
        cancelOnError: true,
      );
    } on SocketException catch (e) {
      if (!mounted) return;
      setState(() { _serverResponse = 'Connection error: ${e.osError?.message ?? e.message}'; _isConnected = false; _socket = null; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _serverResponse = 'Error: $e'; _isConnected = false; _socket = null; });
    }
  }

  void _disconnectFromServer() {
    _socket?.destroy(); _socket = null; _isConnected = false;
    if (!mounted) return;
    setState(() { _serverResponse = "Disconnected."; _clearData(); });
  }

  void _clearData() {
    if (!mounted) return;
    setState(() { _serverSongs = []; _myPlaylists = []; });
  }

  void _sendMessageMap(Map<String, dynamic> messageMap) {
    if (!mounted) return;
    if (_socket != null && _isConnected) {
      final String jsonRequest = jsonEncode(messageMap);
      _socket!.writeln(jsonRequest);
      print('Sent to server: $jsonRequest');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not connected to server. Please connect first.')));
      setState(() { _serverResponse = 'Not connected to server. Please connect first.'; });
    }
  }

  void _fetchServerSongs() { if (!mounted) return; _sendMessageMap({'action': 'get_server_songs'}); }
  void _fetchMyPlaylists() { if (!mounted) return; _sendMessageMap({'action': 'get_my_playlists'}); }

  void _showAddToPlaylistDialog(ServerSong song) {
    if (!mounted) return;
    if (_myPlaylists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No playlists available. Create one or load your playlists.')));
      _fetchMyPlaylists();
      return;
    }
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Add "${song.title}" to Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: _myPlaylists.isEmpty
                ? const Text("No playlists found. Create one first.")
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _myPlaylists.length,
              itemBuilder: (BuildContext listContext, int index) {
                Playlist playlist = _myPlaylists[index];
                return ListTile(
                  title: Text(playlist.name),
                  subtitle: Text('${playlist.songCount} songs'),
                  onTap: () {
                    if (!mounted) return;
                    _sendMessageMap({
                      'action': 'add_song_to_playlist',
                      'playlist_name': playlist.name,
                      'song_identifier': song.filename,
                    });
                    Navigator.of(dialogContext).pop();

                    Future.delayed(const Duration(milliseconds: 500), () => _fetchMyPlaylists());
                  },
                );
              },
            ),
          ),
          actions: <Widget>[ TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop())],
        );
      },
    );
  }

  void _simulatePlaySong(ServerSong song) {
    if (!mounted) return;
    _sendMessageMap({'action': 'play_song', 'song_identifier': song.filename});
  }

  @override
  void dispose() {
    _ipController.dispose(); _portController.dispose(); _echoMessageController.dispose();
    _songTitleController.dispose(); _songArtistController.dispose(); _playlistNameController.dispose();
    _socket?.destroy();
    super.dispose();
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).primaryColor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Logout', onPressed: () {
            _disconnectFromServer();
            if (!mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginPage()));
          }),
          Padding(padding: const EdgeInsets.only(right: 12.0, left: 8.0), child: Icon(Icons.circle, color: _isConnected ? Colors.greenAccent[700] : Colors.redAccent, size: 16))
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildSectionTitle('Server Connection'),
              Row(children: [Expanded(child: TextField(controller: _ipController, decoration: const InputDecoration(labelText: 'Server IP'))), const SizedBox(width: 8), SizedBox(width: 110, child: TextField(controller: _portController, decoration: const InputDecoration(labelText: 'Port'), keyboardType: TextInputType.number))]), const SizedBox(height: 10),
              ElevatedButton(onPressed: _connectToServer, style: ElevatedButton.styleFrom(backgroundColor: _isConnected ? Colors.orange[700] : Colors.green[700]), child: Text(_isConnected ? 'Disconnect' : 'Connect to Server', style: const TextStyle(color: Colors.white))), const SizedBox(height: 10),
              Text('Server Response:', style: Theme.of(context).textTheme.bodySmall),
              Container(margin: const EdgeInsets.symmetric(vertical: 8.0), padding: const EdgeInsets.all(8.0), width: double.infinity, constraints: const BoxConstraints(minHeight: 60), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4.0), color: Colors.grey[50]), child: SingleChildScrollView(child: Text(_serverResponse))),

              _buildSectionTitle('Server Music Library'),
              ElevatedButton.icon(icon: const Icon(Icons.library_music_outlined), onPressed: _fetchServerSongs, label: const Text('Load Server Songs')),
              _serverSongs.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Center(child: Text('No server songs loaded.', style: TextStyle(color: Colors.grey[600]))))
                  : Container(constraints: const BoxConstraints(maxHeight: 200), child: ListView.builder(itemCount: _serverSongs.length, itemBuilder: (ctx, i) => Card(
                elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.music_note_rounded, color: Theme.of(context).primaryColor),
                  title: Text(_serverSongs[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(_serverSongs[i].artist ?? _serverSongs[i].filename,  maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: Icon(Icons.play_circle_outline_rounded, color: Colors.green[600]), iconSize: 28, tooltip: "Play (Simulated)", onPressed: () => _simulatePlaySong(_serverSongs[i])),
                    IconButton(icon: Icon(Icons.playlist_add_rounded, color: Colors.blue[600]), iconSize: 28, tooltip: "Add to Playlist", onPressed: () => _showAddToPlaylistDialog(_serverSongs[i])),
                  ]),
                ),
              ))),

              _buildSectionTitle('My Playlists'),
              ElevatedButton.icon(icon: const Icon(Icons.list_alt_rounded), onPressed: _fetchMyPlaylists, label: const Text('Load My Playlists')),
              _myPlaylists.isEmpty
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Center(child: Text('No playlists created/loaded.', style: TextStyle(color: Colors.grey[600]))))
                  : Container(constraints: const BoxConstraints(maxHeight: 150), child: ListView.builder(itemCount: _myPlaylists.length, itemBuilder: (ctx, i) => Card(
                elevation: 1, margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(Icons.queue_music_rounded, color: Theme.of(context).primaryColor),
                  title: Text(_myPlaylists[i].name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('${_myPlaylists[i].songCount} songs'),
                ),
              ))),

              _buildSectionTitle('Create New Playlist'),
              TextField(controller: _playlistNameController, decoration: const InputDecoration(labelText: 'Playlist Name')), const SizedBox(height: 8), ElevatedButton.icon(icon: const Icon(Icons.add_box_outlined), onPressed: () { if (_playlistNameController.text.isNotEmpty) { _sendMessageMap({'action': 'create_playlist', 'playlist_name': _playlistNameController.text}); _playlistNameController.clear(); Future.delayed(const Duration(milliseconds: 300), () => _fetchMyPlaylists());} else { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a playlist name.')));}}, label: const Text('Create Playlist')),

              _buildSectionTitle('Upload Song Metadata'),
              TextField(controller: _songTitleController, decoration: const InputDecoration(labelText: 'Song Title')), const SizedBox(height: 8), TextField(controller: _songArtistController, decoration: const InputDecoration(labelText: 'Song Artist (Optional)')), const SizedBox(height: 8), ElevatedButton.icon(icon: const Icon(Icons.upload_file_outlined), onPressed: () { if (_songTitleController.text.isNotEmpty) { _sendMessageMap({'action': 'upload_song_metadata', 'title': _songTitleController.text, 'artist': _songArtistController.text}); _songTitleController.clear(); _songArtistController.clear(); } else { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a song title.')));}}, label: const Text('Upload Song Metadata')),

              _buildSectionTitle('Echo Test'),
              TextField(controller: _echoMessageController, decoration: const InputDecoration(labelText: 'Message for Echo')), const SizedBox(height: 8), ElevatedButton(onPressed: () => _sendMessageMap({'action': 'echo', 'data': _echoMessageController.text}), child: const Text('Send Echo')), const SizedBox(height: 8), ElevatedButton(onPressed: () => _sendMessageMap({'action': 'ping', 'data': ''}), child: const Text('Send Ping')),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}