import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_client.dart';

class SocketServerProvider extends ChangeNotifier {
  final SocketClient client;
  SocketServerProvider(this.client);

  List<String> _categories = [];
  List<String> get categories => _categories;

  Map<String, dynamic>? lastNewRelease;
  StreamSubscription? _sub;

  Future<void> ensureConnected() async {
    if (!client.isConnected) {
      await client.connect();
      _sub = client.events.listen((e) {
        if (e['event'] == 'new_release') {
          lastNewRelease = e;
          notifyListeners();
        }
      });
    }
  }

  // AUTH
  Future<Map<String, dynamic>> signup(String u, String e, String p) async {
    await ensureConnected();
    final r = await client.request('signup', data: {'username': u, 'email': e, 'password': p});
    client.setToken(r['token'] as String?);
    return r;
  }

  Future<Map<String, dynamic>> login(String userOrEmail, String p) async {
    await ensureConnected();
    final r = await client.request('login', data: {'userOrEmail': userOrEmail, 'password': p});
    client.setToken(r['token'] as String?);
    return r;
  }

  Future<Map<String, dynamic>> me() async {
    await ensureConnected();
    return await client.request('me');
  }

  Future<Map<String, dynamic>> updateProfile({String? username, String? email}) async {
    await ensureConnected();
    return await client.request('updateProfile', data: {'username': username, 'email': email});
  }

  Future<Map<String, dynamic>> addCredit(double amount) async {
    await ensureConnected();
    return await client.request('addCredit', data: {'amount': amount});
  }

  Future<Map<String, dynamic>> subscription(String plan) async {
    await ensureConnected();
    return await client.request('subscription', data: {'plan': plan});
  }

  Future<Map<String, dynamic>> purchase(String songId) async {
    await ensureConnected();
    return await client.request('purchase', data: {'songId': songId});
  }

  // SONGS
  Future<void> loadCategories() async {
    await ensureConnected();
    final r = await client.request('categories');
    final any = r['result'] ?? r;
    if (any is List) _categories = any.cast<String>();
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> songsByCategory(String cat) async {
    await ensureConnected();
    final r = await client.request('songs', data: {'category': cat});
    final any = r['result'] ?? r;
    if (any is List) return any.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> rateSong(String id, double v) async {
    await ensureConnected();
    await client.request('rate', data: {'songId': id, 'value': v});
  }

  Future<List<Map<String, dynamic>>> comments(String id) async {
    await ensureConnected();
    final r = await client.request('comments', data: {'songId': id});
    final any = r['result'] ?? r;
    if (any is List) return any.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> addComment(String id, String text) async {
    await ensureConnected();
    await client.request('addComment', data: {'songId': id, 'text': text});
  }

  Future<void> likeComment(String cid, bool up) async {
    await ensureConnected();
    await client.request('likeComment', data: {'commentId': cid, 'up': up});
  }

  @override
  void dispose() {
    _sub?.cancel();
    client.dispose();
    super.dispose();
  }
}
