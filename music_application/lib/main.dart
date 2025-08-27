// ignore_for_file: unnecessary_this
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final appState = AppState(prefs);
  await appState.bootstrap();

  // یک MockServer سراسری می‌سازیم تا اگر سوکت در دسترس نبود از آن استفاده کنیم
  final mock = MockServer();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => appState),
        ChangeNotifierProvider(create: (_) => PlayerQueue()),
        ChangeNotifierProvider(create: (_) => mock),
        Provider(create: (_) => CatalogRepo(SocketClient(host: '10.0.2.2', port: 7070), mock)),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
      ],
      child: const MusicPlayerApp(),
    ),
  );
}

// =============================================================
// Theme + App
// =============================================================
class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      themeMode: appState.themeMode,
      debugShowCheckedModeBanner: false,
      home: const MainScreen(),
    );
  }
}

// =============================================================
// Models
// =============================================================
enum Subscription { standard, premium }
enum ShopSortOption { byRating, byPrice, byDownloads, byTitle, byNewest }

class UserModel {
  String id;
  String username;
  String email;
  String password; // فقط برای شبیه‌سازی
  double credit;
  Subscription subscription;
  String? avatarPath;
  bool rememberMe;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.password,
    this.credit = 200.0,
    this.subscription = Subscription.standard,
    this.avatarPath,
    this.rememberMe = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'password': password,
    'credit': credit,
    'subscription': subscription.name,
    'avatarPath': avatarPath,
    'rememberMe': rememberMe,
  };

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
    id: j['id'] ?? '',
    username: j['username'] ?? '',
    email: j['email'] ?? '',
    password: j['password'] ?? '',
    credit: (j['credit'] ?? 0).toDouble(),
    subscription:
    (j['subscription'] == 'premium') ? Subscription.premium : Subscription.standard,
    avatarPath: j['avatarPath'],
    rememberMe: j['rememberMe'] ?? false,
  );
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String albumArtUrl;
  final String sourceUrl; // برای استریم/دانلود
  final String category; // Pop/Rock/Local/New...
  final bool isRemote; // سروری یا لوکال دیوایس؟
  final DateTime addedAt;
  int playCount;
  double price; // 0 => Free
  double ratingAverage; // 0..5
  int ratingCount;
  int downloads;
  bool downloaded; // آیا فایل دانلود شده؟
  String? localFilePath; // اگر دانلود شده

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumArtUrl,
    required this.sourceUrl,
    required this.category,
    required this.isRemote,
    required this.addedAt,
    this.playCount = 0,
    this.price = 0.0,
    this.ratingAverage = 4.5,
    this.ratingCount = 1,
    this.downloads = 0,
    this.downloaded = false,
    this.localFilePath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'albumArtUrl': albumArtUrl,
    'sourceUrl': sourceUrl,
    'category': category,
    'isRemote': isRemote,
    'addedAt': addedAt.toIso8601String(),
    'playCount': playCount,
    'price': price,
    'ratingAverage': ratingAverage,
    'ratingCount': ratingCount,
    'downloads': downloads,
    'downloaded': downloaded,
    'localFilePath': localFilePath,
  };

  factory Song.fromJson(Map<String, dynamic> j) => Song(
    id: j['id'],
    title: j['title'],
    artist: j['artist'],
    albumArtUrl: j['albumArtUrl'],
    sourceUrl: j['sourceUrl'],
    category: j['category'],
    isRemote: j['isRemote'] ?? true,
    addedAt:
    DateTime.tryParse(j['addedAt'] ?? '') ?? DateTime.now(),
    playCount: j['playCount'] ?? 0,
    price: (j['price'] ?? 0).toDouble(),
    ratingAverage: (j['ratingAverage'] ?? 4.0).toDouble(),
    ratingCount: j['ratingCount'] ?? 1,
    downloads: j['downloads'] ?? 0,
    downloaded: j['downloaded'] ?? false,
    localFilePath: j['localFilePath'],
  );
}

class CommentModel {
  final String id;
  final String user;
  final String text;
  final DateTime createdAt;
  int likes;
  int dislikes;

  CommentModel({
    required this.id,
    required this.user,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.dislikes = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'user': user,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'likes': likes,
    'dislikes': dislikes,
  };

  factory CommentModel.fromJson(Map<String, dynamic> j) => CommentModel(
    id: j['id'],
    user: j['user'],
    text: j['text'],
    createdAt: DateTime.parse(j['createdAt']),
    likes: j['likes'] ?? 0,
    dislikes: j['dislikes'] ?? 0,
  );
}

// =============================================================
// Persistence Keys
// =============================================================
class Keys {
  static const currentUser = 'current_user';
  static const users = 'users_list';
  static const favorites = 'favorite_ids';
  static const lyrics = 'lyrics_map';
  static const downloads = 'downloads_map';
  static const purchased = 'purchased_ids';
  static const shopCache = 'shop_songs_cache';
}

// =============================================================
// AppState (Auth, Profile, Theme, Wallet, Subscription)
// =============================================================
class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  ThemeMode _themeMode = ThemeMode.dark;
  UserModel? _currentUser;

  AppState(this.prefs);

  ThemeMode get themeMode => _themeMode;
  UserModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;
  bool get isPremium => _currentUser?.subscription == Subscription.premium;

  Future<void> bootstrap() async {
    final tm = prefs.getString('theme_mode');
    if (tm != null) {
      _themeMode = (tm == 'light') ? ThemeMode.light : ThemeMode.dark;
    }
    final raw = prefs.getString(Keys.currentUser);
    if (raw != null) {
      final u = UserModel.fromJson(jsonDecode(raw));
      if (u.rememberMe == true) {
        _currentUser = u;
      }
    }
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    prefs.setString('theme_mode', _themeMode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  // -------------------- Users storage --------------------
  List<UserModel> _getAllUsers() {
    final raw = prefs.getString(Keys.users);
    if (raw == null) return [];
    final l = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return l.map(UserModel.fromJson).toList();
  }

  void _saveAllUsers(List<UserModel> users) {
    prefs.setString(Keys.users, jsonEncode(users.map((e) => e.toJson()).toList()));
  }

  String _obscureEmail(String s) => s.trim().toLowerCase();

  // -------------------- Auth --------------------
  String? validatePassword(String pass, String username) {
    if (pass.length < 8) return 'رمز باید حداقل 8 کاراکتر باشد';
    if (!RegExp(r'[A-Z]').hasMatch(pass)) return 'حداقل یک حرف بزرگ لازم است';
    if (!RegExp(r'[a-z]').hasMatch(pass)) return 'حداقل یک حرف کوچک لازم است';
    if (!RegExp(r'[0-9]').hasMatch(pass)) return 'حداقل یک عدد لازم است';
    if (pass.toLowerCase().contains(username.toLowerCase())) {
      return 'رمز نباید شامل نام کاربری باشد';
    }
    return null;
  }

  Future<String?> signUp({
    required String username,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final users = _getAllUsers();
    if (users.any((u) => u.username == username || _obscureEmail(u.email) == _obscureEmail(email))) {
      return 'نام کاربری یا ایمیل تکراری است';
    }
    final err = validatePassword(password, username);
    if (err != null) return err;

    final u = UserModel(
      id: const Uuid().v4(),
      username: username,
      email: email,
      password: password,
      credit: 200,
      subscription: Subscription.standard,
      rememberMe: rememberMe,
    );
    users.add(u);
    _saveAllUsers(users);
    _currentUser = u;
    await prefs.setString(Keys.currentUser, jsonEncode(u.toJson()));
    notifyListeners();
    return null;
  }

  Future<String?> login({required String userOrEmail, required String password, bool rememberMe = true}) async {
    final users = _getAllUsers();
    final found = users.firstWhere(
          (u) => u.username == userOrEmail || _obscureEmail(u.email) == _obscureEmail(userOrEmail),
      orElse: () => UserModel(id: '', username: '', email: '', password: ''),
    );
    if (found.id.isEmpty) return 'کاربر یافت نشد';
    if (found.password != password) return 'رمز عبور اشتباه است';

    found.rememberMe = rememberMe;
    _currentUser = found;
    await prefs.setString(Keys.currentUser, jsonEncode(found.toJson()));
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _currentUser = null;
    await prefs.remove(Keys.currentUser);
    notifyListeners();
  }

  Future<void> updateProfile({String? username, String? email, String? avatarPath}) async {
    if (_currentUser == null) return;
    final users = _getAllUsers();
    final idx = users.indexWhere((e) => e.id == _currentUser!.id);
    if (idx < 0) return;
    if (username != null) users[idx].username = username;
    if (email != null) users[idx].email = email;
    if (avatarPath != null) users[idx].avatarPath = avatarPath;
    _currentUser = users[idx];
    _saveAllUsers(users);
    await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
  }

  Future<String?> changePassword(String oldPass, String newPass) async {
    if (_currentUser == null) return 'وارد حساب نشده‌اید';
    if (_currentUser!.password != oldPass) return 'رمز فعلی اشتباه است';
    final err = validatePassword(newPass, _currentUser!.username);
    if (err != null) return err;
    final users = _getAllUsers();
    final idx = users.indexWhere((e) => e.id == _currentUser!.id);
    users[idx].password = newPass;
    _currentUser = users[idx];
    _saveAllUsers(users);
    await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
    notifyListeners();
    return null;
  }

  Future<String?> forgotPasswordIssueCode() async {
    final code = Random().nextInt(900000) + 100000;
    await prefs.setString('reset_code', code.toString());
    return code.toString();
  }

  Future<String?> forgotPasswordReset(String code, String newPass) async {
    final stored = prefs.getString('reset_code');
    if (stored == null || stored != code) return 'کد نامعتبر است';
    if (_currentUser == null) return 'ابتدا وارد یک حساب شوید یا ثبت‌نام کنید';
    return await changePassword(_currentUser!.password, newPass);
  }

  // -------------------- Wallet / Subscription --------------------
  Future<void> addCredit(double amount) async {
    if (_currentUser == null) return;
    _currentUser!.credit += amount;
    await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
    final users = _getAllUsers();
    final idx = users.indexWhere((e) => e.id == _currentUser!.id);
    if (idx >= 0) {
      users[idx] = _currentUser!;
      _saveAllUsers(users);
    }
    notifyListeners();
  }

  Future<String?> purchase(double amount) async {
    if (_currentUser == null) return 'ابتدا وارد شوید';
    if (_currentUser!.credit < amount) return 'اعتبار کافی نیست';
    _currentUser!.credit -= amount;
    await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
    final users = _getAllUsers();
    final idx = users.indexWhere((e) => e.id == _currentUser!.id);
    if (idx >= 0) {
      users[idx] = _currentUser!;
      _saveAllUsers(users);
    }
    notifyListeners();
    return null;
  }

  Future<void> buySubscriptionMonthly() async {
    final err = await purchase(9.99);
    if (err == null) {
      _currentUser!.subscription = Subscription.premium;
      await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
      final users = _getAllUsers();
      final idx = users.indexWhere((e) => e.id == _currentUser!.id);
      if (idx >= 0) {
        users[idx] = _currentUser!;
        _saveAllUsers(users);
      }
      notifyListeners();
    }
  }

  Future<void> buySubscriptionYearly() async {
    final err = await purchase(99.0);
    if (err == null) {
      _currentUser!.subscription = Subscription.premium;
      await prefs.setString(Keys.currentUser, jsonEncode(_currentUser!.toJson()));
      final users = _getAllUsers();
      final idx = users.indexWhere((e) => e.id == _currentUser!.id);
      if (idx >= 0) {
        users[idx] = _currentUser!;
        _saveAllUsers(users);
      }
      notifyListeners();
    }
  }

  Future<void> deleteAccount() async {
    if (_currentUser == null) return;
    final users = _getAllUsers();
    users.removeWhere((e) => e.id == _currentUser!.id);
    _saveAllUsers(users);
    await logout();
  }
}

// =============================================================
// Favorites, Lyrics, Purchases & Downloads Storage
// =============================================================
class LocalStore {
  final SharedPreferences prefs;
  LocalStore(this.prefs);

  List<String> getFavorites() => prefs.getStringList(Keys.favorites) ?? [];
  Future<void> toggleFavorite(String id) async {
    final favs = getFavorites();
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
    }
    await prefs.setStringList(Keys.favorites, favs);
  }

  Map<String, String> getLyricsMap() {
    final raw = prefs.getString(Keys.lyrics);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw));
  }

  Future<void> saveLyrics(String songId, String text) async {
    final m = getLyricsMap();
    m[songId] = text;
    await prefs.setString(Keys.lyrics, jsonEncode(m));
  }

  Set<String> getPurchasedIds() {
    final l = prefs.getStringList(Keys.purchased) ?? [];
    return l.toSet();
  }

  Future<void> addPurchased(String songId) async {
    final s = getPurchasedIds();
    s.add(songId);
    await prefs.setStringList(Keys.purchased, s.toList());
  }

  Map<String, String> getDownloadsMap() {
    final raw = prefs.getString(Keys.downloads);
    if (raw == null) return {};
    return Map<String, String>.from(jsonDecode(raw));
  }

  Future<void> setDownloaded(String songId, String localPath) async {
    final m = getDownloadsMap();
    m[songId] = localPath;
    await prefs.setString(Keys.downloads, jsonEncode(m));
  }

  Future<void> cacheShopSongs(List<Song> songs) async {
    await prefs.setString(Keys.shopCache, jsonEncode(songs.map((e) => e.toJson()).toList()));
  }

  List<Song> getCachedShopSongs() {
    final raw = prefs.getString(Keys.shopCache);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Song.fromJson(e)).toList();
  }
}

// =============================================================
// Socket client + Repository (با fallback به MockServer)
// =============================================================
class SocketClient {
  final String host;
  final int port;
  const SocketClient({required this.host, required this.port});

  Future<Map<String, dynamic>> _request(Map<String, dynamic> payload) async {
    final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 1));
    socket.write(jsonEncode(payload) + '\n');
    final line = await socket
        .transform(utf8.decoder as StreamTransformer<Uint8List, dynamic>)
        .transform(const LineSplitter())
        .first
        .timeout(const Duration(seconds: 2));
    socket.destroy();
    return jsonDecode(line) as Map<String, dynamic>;
  }

  Future<List<String>> listCategories() async {
    final r = await _request({'type': 'categories'});
    final data = r['categories'] ?? r['data'];
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<List<Song>> listSongsByCategory(String category) async {
    final r = await _request({'type': 'songs_by_category', 'category': category});
    final arr = (r['songs'] ?? r['data'] ?? []) as List;
    return arr.map((e) => Song.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}

class CatalogRepo {
  final SocketClient socket;
  final MockServer fallback;
  CatalogRepo(this.socket, this.fallback);

  Future<List<String>> categories() async {
    try {
      final cats = await socket.listCategories().timeout(const Duration(milliseconds: 1500));
      if (cats.isNotEmpty) return cats;
      return fallback.categories();
    } catch (_) {
      return fallback.categories();
    }
  }

  Future<List<Song>> byCategory(String category) async {
    try {
      final songs =
      await socket.listSongsByCategory(category).timeout(const Duration(milliseconds: 1500));
      if (songs.isNotEmpty) return songs;
      return fallback.listByCategory(category);
    } catch (_) {
      return fallback.listByCategory(category);
    }
  }
}

// =============================================================
// Player Queue + Global AudioPlayer
// =============================================================
class PlayerQueue extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final ConcatenatingAudioSource _playlist = ConcatenatingAudioSource(children: []);
  List<Song> _currentSongs = [];
  Song? _currentSong;

  AudioPlayer get player => _player;
  Song? get currentSong => _currentSong;

  PlayerQueue() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _player.setAudioSource(_playlist, initialIndex: 0, initialPosition: Duration.zero);
    _player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      if (idx < 0 || idx >= _currentSongs.length) return;
      _currentSong = _currentSongs[idx];
      notifyListeners();
    });
  }

  Future<void> setQueue(List<Song> songs, {int startIndex = 0}) async {
    _playlist.clear();
    _currentSongs = songs;
    for (final s in songs) {
      final source = await _audioSourceForSong(s);
      _playlist.add(source);
    }
    await _player.setAudioSource(_playlist, initialIndex: startIndex);
    _currentSong = (startIndex >= 0 && startIndex < _currentSongs.length) ? _currentSongs[startIndex] : null;
    notifyListeners();
  }

  Future<AudioSource> _audioSourceForSong(Song s) async {
    if (s.downloaded && s.localFilePath != null) {
      return AudioSource.uri(Uri.file(s.localFilePath!));
    } else {
      return AudioSource.uri(Uri.parse(s.sourceUrl));
    }
  }

  Future<void> playAt(List<Song> songs, int index) async {
    await setQueue(songs, startIndex: index);
    await _player.play();
  }

  void toggleShuffle() async {
    await _player.setShuffleModeEnabled(!(_player.shuffleModeEnabled));
    notifyListeners();
  }

  void cycleLoop() {
    final m = _player.loopMode;
    if (m == LoopMode.off) {
      _player.setLoopMode(LoopMode.one);
    } else {
      _player.setLoopMode(LoopMode.off);
    }
    notifyListeners();
  }

  void disposePlayer() {
    _player.dispose();
  }
}

// =============================================================
// Library Provider: local device + downloads
// =============================================================
class LibraryProvider extends ChangeNotifier {
  final OnAudioQuery _query = OnAudioQuery();
  List<SongModel> _deviceSongs = [];
  bool _permOk = false;
  bool get permissionOk => _permOk;
  List<SongModel> get deviceSongs => _deviceSongs;

  Future<void> refreshDeviceSongs() async {
    final st = await Permission.audio.request();
    final st2 = await Permission.storage.request();
    _permOk = st.isGranted && st2.isGranted;
    if (!_permOk) {
      notifyListeners();
      return;
    }
    _deviceSongs = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
    notifyListeners();
  }
}

// =============================================================
// Mock Server (offline fallback)
// =============================================================
class MockServer extends ChangeNotifier {
  final Map<String, List<Song>> _byCategory = {};
  final Map<String, List<CommentModel>> _commentsBySong = {};
  final StreamController<Song> _newReleases = StreamController.broadcast();

  Stream<Song> get newReleases => _newReleases.stream;

  MockServer() {
    _seed();
    Timer.periodic(const Duration(seconds: 25), (_) {
      final s = _makeRandomSong();
      _byCategory[s.category]!.insert(0, s);
      _newReleases.add(s);
      notifyListeners();
    });
  }

  void _seed() {
    final now = DateTime.now();

    // آرت‌ورک پایدار از picsum.photos + MP3 های SoundHelix
    final List<Song> base = [
      Song(
        id: 'shop_1',
        title: 'Helix 1',
        artist: 'SoundHelix',
        albumArtUrl: 'https://picsum.photos/seed/helix1/300/300',
        sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
        category: 'Pop',
        isRemote: true,
        addedAt: now.subtract(const Duration(days: 9)),
        price: 1.29,
        ratingAverage: 4.8,
        ratingCount: 250,
        downloads: 5000,
      ),
      Song(
        id: 'shop_2',
        title: 'Helix 2',
        artist: 'SoundHelix',
        albumArtUrl: 'https://picsum.photos/seed/helix2/300/300',
        sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
        category: 'Rock',
        isRemote: true,
        addedAt: now.subtract(const Duration(days: 11)),
        price: 0.0,
        ratingAverage: 4.9,
        ratingCount: 400,
        downloads: 10000,
      ),
      Song(
        id: 'shop_3',
        title: 'Helix 3',
        artist: 'SoundHelix',
        albumArtUrl: 'https://picsum.photos/seed/helix3/300/300',
        sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
        category: 'Classic',
        isRemote: true,
        addedAt: now.subtract(const Duration(days: 6)),
        price: 1.29,
        ratingAverage: 5.0,
        ratingCount: 520,
        downloads: 8000,
      ),
      Song(
        id: 'shop_4',
        title: 'Helix 4',
        artist: 'SoundHelix',
        albumArtUrl: 'https://picsum.photos/seed/helix4/300/300',
        sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
        category: 'Pop',
        isRemote: true,
        addedAt: now.subtract(const Duration(days: 5)),
        price: 0.99,
        ratingAverage: 4.7,
        ratingCount: 300,
        downloads: 7500,
      ),
      Song(
        id: 'shop_5',
        title: 'Helix 5',
        artist: 'SoundHelix',
        albumArtUrl: 'https://picsum.photos/seed/helix5/300/300',
        sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
        category: 'New Releases',
        isRemote: true,
        addedAt: now.subtract(const Duration(days: 1)),
        price: 0.0,
        ratingAverage: 4.6,
        ratingCount: 180,
        downloads: 9200,
      ),
    ];

    _byCategory['Pop'] = base.where((s) => s.category == 'Pop').toList();
    _byCategory['Rock'] = base.where((s) => s.category == 'Rock').toList();
    _byCategory['Classic'] = base.where((s) => s.category == 'Classic').toList();
    _byCategory['New Releases'] = base.where((s) => s.category == 'New Releases').toList();

    for (final s in base) {
      _commentsBySong[s.id] = [
        CommentModel(
          id: const Uuid().v4(),
          user: 'User123',
          text: 'Amazing song!',
          createdAt: now.subtract(const Duration(days: 2)),
          likes: 15,
          dislikes: 1,
        ),
        CommentModel(
          id: const Uuid().v4(),
          user: 'MusicFan',
          text: 'A true classic.',
          createdAt: now.subtract(const Duration(days: 1)),
          likes: 22,
          dislikes: 0,
        ),
      ];
    }
  }

  Song _makeRandomSong() {
    final cats = _byCategory.keys.toList();
    final cat = cats.isEmpty ? 'New Releases' : cats[Random().nextInt(cats.length)];
    return Song(
      id: const Uuid().v4(),
      title: 'New Track ${Random().nextInt(999)}',
      artist: 'Server Artist',
      albumArtUrl: 'https://picsum.photos/seed/new${Random().nextInt(10000)}/300/300',
      sourceUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
      category: cat,
      isRemote: true,
      addedAt: DateTime.now(),
      price: Random().nextBool() ? 0 : 0.89,
      ratingAverage: 4 + Random().nextDouble(),
      ratingCount: Random().nextInt(50) + 1,
      downloads: Random().nextInt(2000),
    );
  }

  List<String> categories() => _byCategory.keys.toList();

  List<Song> listByCategory(String category) => List<Song>.from(_byCategory[category] ?? []);

  void sortCategory(String category, ShopSortOption opt) {
    final l = _byCategory[category];
    if (l == null) return;
    switch (opt) {
      case ShopSortOption.byRating:
        l.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
        break;
      case ShopSortOption.byPrice:
        l.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ShopSortOption.byDownloads:
        l.sort((a, b) => b.downloads.compareTo(a.downloads));
        break;
      case ShopSortOption.byTitle:
        l.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case ShopSortOption.byNewest:
        l.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
    }
    notifyListeners();
  }

  List<CommentModel> commentsFor(String songId) => List<CommentModel>.from(_commentsBySong[songId] ?? []);

  void addComment(String songId, CommentModel c) {
    _commentsBySong.putIfAbsent(songId, () => []);
    _commentsBySong[songId]!.add(c);
    notifyListeners();
  }

  void likeComment(String songId, String commentId, bool up) {
    final l = _commentsBySong[songId];
    if (l == null) return;
    final idx = l.indexWhere((e) => e.id == commentId);
    if (idx < 0) return;
    if (up) {
      l[idx].likes++;
    } else {
      l[idx].dislikes++;
    }
    notifyListeners();
  }

  void sortComments(String songId, {bool byLikes = true}) {
    final l = _commentsBySong[songId];
    if (l == null) return;
    if (byLikes) {
      l.sort((a, b) => b.likes.compareTo(a.likes));
    } else {
      l.sort((a, b) => b.dislikes.compareTo(a.dislikes));
    }
    notifyListeners();
  }

  void rateSong(String songId, double userRating) {
    for (final cat in _byCategory.values) {
      final idx = cat.indexWhere((e) => e.id == songId);
      if (idx >= 0) {
        final s = cat[idx];
        final total = s.ratingAverage * s.ratingCount + userRating;
        final count = s.ratingCount + 1;
        cat[idx] = Song(
          id: s.id,
          title: s.title,
          artist: s.artist,
          albumArtUrl: s.albumArtUrl,
          sourceUrl: s.sourceUrl,
          category: s.category,
          isRemote: s.isRemote,
          addedAt: s.addedAt,
          playCount: s.playCount,
          price: s.price,
          ratingAverage: total / count,
          ratingCount: count,
          downloads: s.downloads,
          downloaded: s.downloaded,
          localFilePath: s.localFilePath,
        );
        notifyListeners();
        break;
      }
    }
  }
}

// =============================================================
// UI: Bottom Nav + Pages
// =============================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selected = 0;
  StreamSubscription<Song>? _sub;

  @override
  void initState() {
    super.initState();
    final server = context.read<MockServer>();
    _sub = server.newReleases.listen((song) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('موزیک جدید: ${song.title}'),
          action: SnackBarAction(
            label: 'مشاهده',
            onPressed: () {
              final app = context.read<AppState>();
              if (app.isLoggedIn) {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ShopCategoryScreen(category: song.category)));
              } else {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => MusicShopEntryScreen(
                  onLoginSuccess: () {},
                )));
              }
            },
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pages = [
      const HomeScreen(),
      app.isLoggedIn ? const MusicShopScreen() : MusicShopEntryScreen(onLoginSuccess: () {}),
      if (app.isLoggedIn) const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selected,
        onDestinationSelected: (i) => setState(() => _selected = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_rounded), label: 'خانه'),
          const NavigationDestination(icon: Icon(Icons.store_rounded), label: 'فروشگاه'),
          if (app.isLoggedIn)
            const NavigationDestination(icon: Icon(Icons.person_rounded), label: 'پروفایل'),
        ],
      ),
    );
  }
}

// =============================================================
// Home
// =============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String q = '';
  ShopSortOption _sort = ShopSortOption.byTitle;

  @override
  void initState() {
    super.initState();
    context.read<LibraryProvider>().refreshDeviceSongs();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lib = context.watch<LibraryProvider>();
    final store = LocalStore(app.prefs);
    final downloads = store.getDownloadsMap(); // songId -> path
    final favs = store.getFavorites().toSet();

    final device = lib.deviceSongs
        .map((m) => Song(
      id: 'dev_${m.id}',
      title: m.title ?? 'Unknown',
      artist: m.artist ?? 'Unknown',
      albumArtUrl: 'https://picsum.photos/seed/dev${m.id}/300/300',
      sourceUrl: m.uri ?? '',
      category: 'Local',
      isRemote: false,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
          m.dateAdded ?? DateTime.now().millisecondsSinceEpoch,
          isUtc: false),
    ))
        .toList();

    final server = context.watch<MockServer>();
    final allShop = server.categories().expand((c) => server.listByCategory(c)).toList();
    final downloaded = allShop.where((s) => downloads.containsKey(s.id)).map((s) {
      final p = downloads[s.id]!;
      return Song(
        id: s.id,
        title: s.title,
        artist: s.artist,
        albumArtUrl: s.albumArtUrl,
        sourceUrl: s.sourceUrl,
        category: 'Downloaded',
        isRemote: false,
        addedAt: s.addedAt,
        price: s.price,
        ratingAverage: s.ratingAverage,
        ratingCount: s.ratingCount,
        downloads: s.downloads,
        downloaded: true,
        localFilePath: p,
      );
    }).toList();

    List<Song> localShow = device.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();
    List<Song> dlShow = downloaded.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();

    int cmp(Song a, Song b) {
      switch (_sort) {
        case ShopSortOption.byTitle:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case ShopSortOption.byNewest:
          return b.addedAt.compareTo(a.addedAt);
        case ShopSortOption.byRating:
          return b.ratingAverage.compareTo(a.ratingAverage);
        case ShopSortOption.byDownloads:
          return b.downloads.compareTo(a.downloads);
        case ShopSortOption.byPrice:
          return a.price.compareTo(b.price);
      }
    }

    localShow.sort(cmp);
    dlShow.sort(cmp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('کتابخانه من'),
        centerTitle: true,
        actions: [
          PopupMenuButton<ShopSortOption>(
            tooltip: 'مرتب‌سازی',
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (c) => const [
              PopupMenuItem(value: ShopSortOption.byTitle, child: Text('بر اساس نام')),
              PopupMenuItem(value: ShopSortOption.byNewest, child: Text('جدیدترین')),
              PopupMenuItem(value: ShopSortOption.byRating, child: Text('امتیاز')),
              PopupMenuItem(value: ShopSortOption.byDownloads, child: Text('دانلود/پخش بیشتر')),
              PopupMenuItem(value: ShopSortOption.byPrice, child: Text('قیمت')),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'جستجو در آهنگ‌ها...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
                onChanged: (v) => setState(() => q = v),
              ),
            ),
          ),
          _buildSection('علاقه‌مندی‌ها', allShop.where((s) => favs.contains(s.id)).toList(), isServer: true),
          _buildSection('محلی (Device)', localShow),
          _buildSection('دانلود شده', dlShow),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Song> songs, {bool isServer = false}) {
    if (songs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverList.builder(
      itemCount: songs.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(title, style: Theme.of(c).textTheme.titleLarge),
          );
        }
        final s = songs[i - 1];
        return InkWell(
          onTap: () {
            context.read<PlayerQueue>().playAt(songs, i - 1);
            Navigator.of(c).push(MaterialPageRoute(builder: (_) => SongDetailScreen(song: s, all: songs)));
          },
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                s.albumArtUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.music_note),
              ),
            ),
            title: Text(s.title),
            subtitle: Text('${s.artist}${s.price > 0 ? ' • ${s.price.toStringAsFixed(2)}\$' : ''}'),
            trailing: isServer ? const Icon(Icons.play_arrow_rounded) : null,
          ),
        );
      },
    );
  }
}

// =============================================================
// Player Screen
// =============================================================
class SongDetailScreen extends StatefulWidget {
  final Song song;
  final List<Song> all;
  const SongDetailScreen({super.key, required this.song, required this.all});

  @override
  State<SongDetailScreen> createState() => _SongDetailScreenState();
}

class _SongDetailScreenState extends State<SongDetailScreen> {
  late final PlayerQueue pq;
  late final AudioPlayer player;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  StreamSubscription? _dsub, _psub, _stsub;

  @override
  void initState() {
    super.initState();
    pq = context.read<PlayerQueue>();
    player = pq.player;

    _dsub = player.durationStream.listen((d) {
      setState(() => duration = d ?? Duration.zero);
    });
    _psub = player.positionStream.listen((p) {
      setState(() => position = p);
    });
    _stsub = player.currentIndexStream.listen((_) => setState(() {}));
  }

  @override
  void dispose() {
    _dsub?.cancel();
    _psub?.cancel();
    _stsub?.cancel();
    super.dispose();
  }

  String fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = LocalStore(app.prefs);
    final favs = store.getFavorites();
    final isFav = favs.contains(widget.song.id);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
            onPressed: () async {
              await store.toggleFavorite(widget.song.id);
              setState(() {});
            },
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.song.albumArtUrl,
                height: MediaQuery.of(context).size.width * 0.7,
                width: MediaQuery.of(context).size.width * 0.7,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 100),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(widget.song.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(widget.song.artist,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 24),

          Slider(
            value: min(position.inMilliseconds.toDouble(), duration.inMilliseconds.toDouble()),
            max: max(1, duration.inMilliseconds.toDouble()),
            onChanged: (v) => player.seek(Duration(milliseconds: v.toInt())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(fmt(position)), Text(fmt(duration))],
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(icon: const Icon(Icons.shuffle), onPressed: () => pq.toggleShuffle(),
                  color: player.shuffleModeEnabled ? Theme.of(context).colorScheme.primary : null),
              IconButton(icon: const Icon(Icons.skip_previous_rounded), iconSize: 38, onPressed: () => player.seekToPrevious()),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                builder: (_, snap) {
                  final playing = snap.data?.playing ?? false;
                  return IconButton(
                    iconSize: 64,
                    color: Theme.of(context).colorScheme.primary,
                    icon: Icon(playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded),
                    onPressed: () => playing ? player.pause() : player.play(),
                  );
                },
              ),
              IconButton(icon: const Icon(Icons.skip_next_rounded), iconSize: 38, onPressed: () => player.seekToNext()),
              IconButton(
                icon: Icon(player.loopMode == LoopMode.one ? Icons.repeat_one : Icons.repeat),
                onPressed: () => pq.cycleLoop(),
                color: player.loopMode != LoopMode.off ? Theme.of(context).colorScheme.primary : null,
              ),
            ],
          ),

          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.lyrics_rounded),
            title: const Text('نمایش/ویرایش متن ترانه (Lyrics)'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => LyricsEditor(songId: widget.song.id)));
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Lyrics Editor
// =============================================================
class LyricsEditor extends StatefulWidget {
  final String songId;
  const LyricsEditor({super.key, required this.songId});

  @override
  State<LyricsEditor> createState() => _LyricsEditorState();
}

class _LyricsEditorState extends State<LyricsEditor> {
  final _c = TextEditingController();

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    final store = LocalStore(app.prefs);
    _c.text = store.getLyricsMap()[widget.songId] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = LocalStore(app.prefs);
    return Scaffold(
      appBar: AppBar(title: const Text('Lyrics')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'متن ترانه را بنویس...',
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await store.saveLyrics(widget.songId, _c.text);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lyrics ذخیره شد')));
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('ذخیره'),
            )
          ],
        ),
      ),
    );
  }
}

// =============================================================
// Music Shop Entry / Login / Signup
// =============================================================
class MusicShopEntryScreen extends StatelessWidget {
  final VoidCallback onLoginSuccess;
  const MusicShopEntryScreen({super.key, required this.onLoginSuccess});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Music Shop'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note_rounded, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 16),
                Text('به فروشگاه موزیک خوش آمدید', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text('برای دیدن آهنگ‌های آنلاین، وارد شوید یا ثبت‌نام کنید.',
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(onLoginSuccess: onLoginSuccess))),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: const Text('ورود (Login)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                  child: const Text('ثبت‌نام (Sign Up)'),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AdWebViewPage(url: 'https://www.spotify.com/')));
                  },
                  icon: const Icon(Icons.public),
                  label: const Text('مشاهده پیشنهاد ویژه داخل برنامه'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final f = GlobalKey<FormState>();
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool remember = true;
  bool obsc = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: f,
              child: Column(
                children: [
                  Text('ورود به حساب', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: userC,
                    decoration: const InputDecoration(labelText: 'نام کاربری یا ایمیل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.isEmpty) ? 'این فیلد را پر کنید' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passC,
                    obscureText: obsc,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(obsc ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => obsc = !obsc)),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'رمز را وارد کنید' : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: remember,
                    onChanged: (v) => setState(() => remember = v ?? true),
                    title: const Text('من را به خاطر بسپار (Remember me)'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          final code = await app.forgotPasswordIssueCode();
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('بازیابی رمز (شبیه‌سازی)'),
                              content: Text('کد ریکاوری: $code\n(در عمل باید ایمیل شود)'),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('باشه'))],
                            ),
                          );
                        },
                        child: const Text('فراموشی رمز؟'),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () async {
                      if (!f.currentState!.validate()) return;
                      final err = await app.login(userOrEmail: userC.text.trim(), password: passC.text, rememberMe: remember);
                      if (err != null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        widget.onLoginSuccess();
                        if (!mounted) return;
                        Navigator.popUntil(context, (r) => r.isFirst);
                      }
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: const Text('ورود'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final f = GlobalKey<FormState>();
  final usernameC = TextEditingController();
  final emailC = TextEditingController();
  final passC = TextEditingController();
  final repC = TextEditingController();
  bool showPass = false;
  bool showRep = false;
  bool remember = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: f,
              child: Column(
                children: [
                  Text('ایجاد حساب کاربری', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: usernameC,
                    decoration: const InputDecoration(labelText: 'نام کاربری', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => (v == null || v.isEmpty) ? 'نام کاربری لازم است' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailC,
                    decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'ایمیل را وارد کنید';
                      if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) return 'ایمیل نامعتبر است';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passC,
                    obscureText: !showPass,
                    decoration: InputDecoration(
                      labelText: 'رمز عبور',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(showPass ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => showPass = !showPass)),
                    ),
                    validator: (v) => app.validatePassword(v ?? '', usernameC.text),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: repC,
                    obscureText: !showRep,
                    decoration: InputDecoration(
                      labelText: 'تکرار رمز عبور',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(icon: Icon(showRep ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => showRep = !showRep)),
                    ),
                    validator: (v) => (v != passC.text) ? 'عدم تطابق رمز' : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: remember,
                    onChanged: (v) => setState(() => remember = v ?? true),
                    title: const Text('من را به خاطر بسپار'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () async {
                      if (!f.currentState!.validate()) return;
                      final err = await app.signUp(
                        username: usernameC.text.trim(),
                        email: emailC.text.trim(),
                        password: passC.text,
                        rememberMe: remember,
                      );
                      if (err != null) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ثبت‌نام موفق!')));
                        Navigator.popUntil(context, (r) => r.isFirst);
                      }
                    },
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    child: const Text('ثبت‌نام'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// Music Shop: Categories  (با سوکت + fallback)
// =============================================================
class MusicShopScreen extends StatefulWidget {
  const MusicShopScreen({super.key});

  @override
  State<MusicShopScreen> createState() => _MusicShopScreenState();
}

class _MusicShopScreenState extends State<MusicShopScreen> {
  late Future<List<String>> _catsFuture;

  @override
  void initState() {
    super.initState();
    _catsFuture = context.read<CatalogRepo>().categories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فروشگاه')),
      body: FutureBuilder<List<String>>(
        future: _catsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ShopError(onRetry: _retry, message: 'خطا در ارتباط با سرور. حالت آفلاین در دسترس است.');
          }
          final cats = snap.data ?? [];
          if (cats.isEmpty) {
            return _ShopError(onRetry: _retry, message: 'دسته‌ای یافت نشد. حالت آفلاین را امتحان کن.');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final c = cats[i];
              return Card(
                child: ListTile(
                  title: Text(c),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopCategoryScreen(category: c))),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _retry() {
    setState(() {
      _catsFuture = context.read<CatalogRepo>().categories();
    });
  }
}

class _ShopError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ShopError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('تلاش مجدد')),
          ],
        ),
      ),
    );
  }
}

class ShopCategoryScreen extends StatefulWidget {
  final String category;
  const ShopCategoryScreen({super.key, required this.category});

  @override
  State<ShopCategoryScreen> createState() => _ShopCategoryScreenState();
}

class _ShopCategoryScreenState extends State<ShopCategoryScreen> {
  ShopSortOption _sort = ShopSortOption.byRating;
  String q = '';
  late Future<List<Song>> _songsFuture;

  @override
  void initState() {
    super.initState();
    _songsFuture = context.read<CatalogRepo>().byCategory(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        actions: [
          IconButton(
            onPressed: () => showSearchDialog(context),
            icon: const Icon(Icons.search),
            tooltip: 'جستجو',
          ),
          PopupMenuButton<ShopSortOption>(
            icon: const Icon(Icons.sort_rounded),
            onSelected: (r) => setState(() => _sort = r),
            itemBuilder: (_) => const [
              PopupMenuItem(value: ShopSortOption.byRating, child: Text('امتیاز')),
              PopupMenuItem(value: ShopSortOption.byPrice, child: Text('قیمت')),
              PopupMenuItem(value: ShopSortOption.byDownloads, child: Text('دانلودها')),
              PopupMenuItem(value: ShopSortOption.byTitle, child: Text('نام')),
              PopupMenuItem(value: ShopSortOption.byNewest, child: Text('جدیدترین')),
            ],
          )
        ],
      ),
      body: FutureBuilder<List<Song>>(
        future: _songsFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          var songs = snap.data ?? [];
          // فیلتر
          songs = songs.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();
          // سورت
          switch (_sort) {
            case ShopSortOption.byRating:
              songs.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
              break;
            case ShopSortOption.byPrice:
              songs.sort((a, b) => a.price.compareTo(b.price));
              break;
            case ShopSortOption.byDownloads:
              songs.sort((a, b) => b.downloads.compareTo(a.downloads));
              break;
            case ShopSortOption.byTitle:
              songs.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
              break;
            case ShopSortOption.byNewest:
              songs.sort((a, b) => b.addedAt.compareTo(a.addedAt));
              break;
          }

          if (songs.isEmpty) {
            return _ShopError(
              onRetry: () => setState(() => _songsFuture = context.read<CatalogRepo>().byCategory(widget.category)),
              message: 'آهنگی برای این دسته موجود نیست.',
            );
          }

          final isPremium = context.read<AppState>().isPremium;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final s = songs[i];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(s.albumArtUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note)),
                  ),
                  title: Text(s.title),
                  subtitle: Text('${s.artist} • ★ ${s.ratingAverage.toStringAsFixed(1)}'),
                  trailing: Text((s.price == 0 || isPremium) ? 'Free' : '\$${s.price}'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ShopSongDetailScreen(song: s))),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void showSearchDialog(BuildContext context) async {
    final c = TextEditingController(text: q);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('جستجو'),
        content: TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'نام آهنگ...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          ElevatedButton(onPressed: () { setState(() => q = c.text); Navigator.pop(context); }, child: const Text('اعمال')),
        ],
      ),
    );
  }
}

// =============================================================
// Shop Song Detail: buy/download, rating, comments
// =============================================================
class ShopSongDetailScreen extends StatefulWidget {
  final Song song;
  const ShopSongDetailScreen({super.key, required this.song});

  @override
  State<ShopSongDetailScreen> createState() => _ShopSongDetailScreenState();
}

class _ShopSongDetailScreenState extends State<ShopSongDetailScreen> {
  double _myRating = 0;
  final commentC = TextEditingController();
  bool downloading = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final store = LocalStore(app.prefs);
    final server = context.watch<MockServer>();

    final purchased = store.getPurchasedIds();
    final isPremium = app.isPremium;
    final canDownloadFree = (widget.song.price == 0.0) || isPremium || purchased.contains(widget.song.id);

    final comments = server.commentsFor(widget.song.id);

    return Scaffold(
      appBar: AppBar(title: Text(widget.song.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.song.albumArtUrl, width: 120, height: 120, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.song.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(widget.song.artist, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(widget.song.ratingAverage.toStringAsFixed(1)),
                      ]),
                    ]),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (canDownloadFree)
                ElevatedButton.icon(
                  onPressed: downloading ? null : () async {
                    setState(() => downloading = true);
                    final path = await _simulateDownload(widget.song);
                    await store.setDownloaded(widget.song.id, path);
                    setState(() => downloading = false);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('دانلود شد (داخل حافظه برنامه)!')));
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(downloading ? 'در حال دانلود...' : 'دانلود'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    final err = await app.purchase(widget.song.price);
                    if (err != null) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                    } else {
                      await store.addPurchased(widget.song.id);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خرید موفق! اکنون می‌توانید دانلود کنید.')));
                      setState(() {});
                    }
                  },
                  icon: const Icon(Icons.shopping_cart_rounded),
                  label: Text('خرید (\$${widget.song.price.toStringAsFixed(2)})'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              const SizedBox(height: 12),

              const Divider(),
              Text('امتیاز دهید', style: Theme.of(context).textTheme.titleLarge),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    onPressed: () {
                      setState(() => _myRating = (i + 1).toDouble());
                      server.rateSong(widget.song.id, _myRating);
                    },
                    icon: Icon(_myRating > i ? Icons.star : Icons.star_border, color: Colors.amber),
                  );
                }),
              ),
              const Divider(),
              const SizedBox(height: 8),

              Text('نظرات', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => server.sortComments(widget.song.id, byLikes: true),
                    icon: const Icon(Icons.thumb_up),
                    label: const Text('سورت بر اساس لایک'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => server.sortComments(widget.song.id, byLikes: false),
                    icon: const Icon(Icons.thumb_down),
                    label: const Text('سورت بر اساس دیسلایک'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...comments.map((c) => Card(
                child: ListTile(
                  title: Text(c.user),
                  subtitle: Text(c.text),
                  trailing: Wrap(spacing: 8, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => server.likeComment(widget.song.id, c.id, true), icon: const Icon(Icons.thumb_up_alt_outlined, size: 18)),
                      Text('${c.likes}'),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => server.likeComment(widget.song.id, c.id, false), icon: const Icon(Icons.thumb_down_alt_outlined, size: 18)),
                      Text('${c.dislikes}'),
                    ]),
                  ]),
                ),
              )),
              const SizedBox(height: 8),
              TextField(
                controller: commentC,
                decoration: InputDecoration(
                  hintText: 'نظر خود را بنویس...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (commentC.text.trim().isEmpty) return;
                      final u = context.read<AppState>().currentUser?.username ?? 'Guest';
                      context.read<MockServer>().addComment(
                        widget.song.id,
                        CommentModel(id: const Uuid().v4(), user: u, text: commentC.text.trim(), createdAt: DateTime.now()),
                      );
                      commentC.clear();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _simulateDownload(Song s) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/${s.id}.txt');
    await f.writeAsString('Downloaded: ${s.title} - ${s.artist} @ ${DateTime.now()}');
    return f.path;
  }
}

// =============================================================
// WebView (In-App Ads)
// =============================================================
class AdWebViewPage extends StatefulWidget {
  final String url;
  const AdWebViewPage({super.key, required this.url});

  @override
  State<AdWebViewPage> createState() => _AdWebViewPageState();
}

class _AdWebViewPageState extends State<AdWebViewPage> {
  late final WebViewController _c;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('تبلیغ')), body: WebViewWidget(controller: _c));
  }
}

// =============================================================
// Profile + Edit + Payment
// =============================================================
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('پروفایل'),
        actions: [
          IconButton(onPressed: () => app.logout(), icon: const Icon(Icons.logout), tooltip: 'خروج'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundImage: (u.avatarPath != null) ? FileImage(File(u.avatarPath!)) : const NetworkImage('https://picsum.photos/seed/useravatar/150/150') as ImageProvider,
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text(u.username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(u.email, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('ویرایش پروفایل'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.photo_camera_back_rounded),
              title: const Text('تغییر عکس پروفایل (گالری/دوربین)'),
              onTap: () async {
                final picker = ImagePicker();
                final img = await showModalBottomSheet<XFile?>(
                  context: context,
                  builder: (_) => SafeArea(
                    child: Wrap(children: [
                      ListTile(
                        leading: const Icon(Icons.photo_library),
                        title: const Text('گالری'),
                        onTap: () async {
                          final x = await picker.pickImage(source: ImageSource.gallery);
                          if (!context.mounted) return;
                          Navigator.pop(context, x);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_camera),
                        title: const Text('دوربین'),
                        onTap: () async {
                          final x = await picker.pickImage(source: ImageSource.camera);
                          if (!context.mounted) return;
                          Navigator.pop(context, x);
                        },
                      ),
                    ]),
                  ),
                );
                if (img != null) {
                  await context.read<AppState>().updateProfile(avatarPath: img.path);
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: const Text('اعتبار'),
              trailing: Text('${u.credit.toStringAsFixed(2)}\$'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen())),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.workspace_premium_rounded),
              title: Text(app.isPremium ? 'اشتراک ویژه (فعال)' : 'خرید اشتراک ویژه'),
              trailing: app.isPremium
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Text('ماهانه 9.99 / سالانه 99'),
              onTap: () async {
                if (app.isPremium) return;
                final plan = await showDialog<String>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('انتخاب پلن'),
                    content: const Text('پلن اشتراک را انتخاب کنید:'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, 'monthly'), child: const Text('ماهانه 9.99')),
                      TextButton(onPressed: () => Navigator.pop(context, 'yearly'), child: const Text('سالانه 99')),
                    ],
                  ),
                );
                if (plan == 'monthly') {
                  await app.buySubscriptionMonthly();
                } else if (plan == 'yearly') {
                  await app.buySubscriptionYearly();
                }
              },
            ),
          ),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.color_lens),
              title: const Text('تغییر تم (روشن/تاریک)'),
              value: app.themeMode == ThemeMode.dark,
              onChanged: (_) => app.toggleTheme(),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('حذف حساب'),
                  content: const Text('مطمئن هستید؟ این عمل غیرقابل بازگشت است.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('خیر')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('بله، حذف کن')),
                  ],
                ),
              );
              if (ok == true) {
                await context.read<AppState>().deleteAccount();
                if (!context.mounted) return;
                Navigator.popUntil(context, (r) => r.isFirst);
              }
            },
            child: const Text('حذف حساب کاربری', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final f = GlobalKey<FormState>();
  final usernameC = TextEditingController();
  final emailC = TextEditingController();
  final oldPassC = TextEditingController();
  final newPassC = TextEditingController();

  @override
  void initState() {
    super.initState();
    final u = context.read<AppState>().currentUser!;
    usernameC.text = u.username;
    emailC.text = u.email;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('ویرایش پروفایل')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: f,
          child: ListView(
            children: [
              TextFormField(
                controller: usernameC,
                decoration: const InputDecoration(labelText: 'نام کاربری', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? 'نباید خالی باشد' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailC,
                decoration: const InputDecoration(labelText: 'ایمیل', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'نباید خالی باشد';
                  if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(v)) return 'ایمیل نامعتبر';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (!f.currentState!.validate()) return;
                  await app.updateProfile(username: usernameC.text.trim(), email: emailC.text.trim());
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره شد')));
                  Navigator.pop(context);
                },
                child: const Text('ذخیره تغییرات'),
              ),
              const SizedBox(height: 24),
              Text('تغییر رمز عبور', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(controller: oldPassC, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'رمز فعلی')),
              const SizedBox(height: 8),
              TextField(controller: newPassC, obscureText: true, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'رمز جدید')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () async {
                  final msg = await app.changePassword(oldPassC.text, newPassC.text);
                  if (!mounted) return;
                  if (msg != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز با موفقیت تغییر کرد')));
                    oldPassC.clear();
                    newPassC.clear();
                  }
                },
                child: const Text('اعمال رمز جدید'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final cardC = TextEditingController();
  final pinC = TextEditingController();
  double amount = 10.0;
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final u = app.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('پرداخت شبیه‌سازی شده')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('مبلغ: ${amount.toStringAsFixed(2)}\$', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: cardC,
            decoration: const InputDecoration(labelText: 'شماره کارت (رندم)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinC,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'PIN (چهار کاراکتر آخر رمز کاربر)',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => obscure = !obscure)),
            ),
            keyboardType: TextInputType.number,
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () async {
              if (cardC.text.isEmpty || pinC.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('همه فیلدها ضروری است')));
                return;
              }
              final pass = u.password;
              final last4 = (pass.length >= 4) ? pass.substring(pass.length - 4) : pass;
              if (pinC.text != last4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN اشتباه است')));
                return;
              }
              await app.addCredit(amount);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پرداخت موفق! اعتبار شما افزایش یافت')));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            child: const Text('پرداخت'),
          ),
        ]),
      ),
    );
  }
}
