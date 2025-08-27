//package org.example;
//
//import java.io.*;
//import java.net.*;
//import java.util.*;
//import java.util.concurrent.*;
//import com.google.gson.*;
//
//public class SocketMusicServer {
//    public static void main(String[] args) throws Exception {
//        int port = 29168;
//        ServerState state = new ServerState();
//        state.seedData();
//
//        ServerSocket serverSocket = new ServerSocket(port);
//        System.out.println("Socket server listening on port " + port + " ...");
//
//        // پخش "new_release" دوره‌ای
//        ScheduledExecutorService sched = Executors.newSingleThreadScheduledExecutor();
//        sched.scheduleAtFixedRate(() -> {
//            try {
//                Song s = state.makeRandomSong();
//                state.addSong(s);
//                Map<String, Object> ev = new HashMap<>();
//                ev.put("event", "new_release");
//                ev.put("song", s.toMap());
//                state.broadcast(ev);
//            } catch (Exception ignored) {}
//        }, 25, 25, TimeUnit.SECONDS);
//
//        while (true) {
//            Socket sock = serverSocket.accept();
//            new ClientHandler(sock, state).start();
//        }
//    }
//}
//
//// ====== مدل‌ها و وضعیت ======
//class User {
//    String id, username, email, password; // ساده و دموی
//    double credit = 200.0;
//    boolean premium = false;
//    Set<String> purchased = new HashSet<>();
//    User(String id, String u, String e, String p) { this.id=id; this.username=u; this.email=e; this.password=p; }
//    Map<String,Object> toMap() {
//        Map<String,Object> m = new LinkedHashMap<>();
//        m.put("id", id); m.put("username", username); m.put("email", email);
//        m.put("credit", credit); m.put("subscription", premium ? "premium" : "standard");
//        return m;
//    }
//}
//
//class Song {
//    String id, title, artist, category, albumArtUrl, sourceUrl;
//    int playCount = 0, ratingCount = 1, downloads = 0;
//    double price = 0.0, ratingAverage = 4.5;
//    Date addedAt = new Date();
//    Song(String id, String t, String a, String c, double price, double rating, int dl, String art, String url) {
//        this.id=id; this.title=t; this.artist=a; this.category=c; this.price=price;
//        this.ratingAverage=rating; this.downloads=dl; this.albumArtUrl=art; this.sourceUrl=url;
//        this.addedAt = new Date();
//    }
//    Map<String,Object> toMap() {
//        Map<String,Object> m = new LinkedHashMap<>();
//        m.put("id", id); m.put("title", title); m.put("artist", artist); m.put("category", category);
//        m.put("price", price); m.put("ratingAverage", ratingAverage); m.put("ratingCount", ratingCount);
//        m.put("downloads", downloads); m.put("albumArtUrl", albumArtUrl); m.put("sourceUrl", sourceUrl);
//        m.put("addedAt", iso(addedAt));
//        return m;
//    }
//    static String iso(Date d){ return new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(d); }
//}
//
//class Comment {
//    String id, songId, user, text;
//    int likes=0, dislikes=0;
//    Date createdAt = new Date();
//    Comment(String id, String sid, String u, String t){ this.id=id; this.songId=sid; this.user=u; this.text=t; }
//    Map<String,Object> toMap(){
//        Map<String,Object> m = new LinkedHashMap<>();
//        m.put("id", id); m.put("songId", songId); m.put("user", user); m.put("text", text);
//        m.put("likes", likes); m.put("dislikes", dislikes);
//        m.put("createdAt", Song.iso(createdAt));
//        return m;
//    }
//}
//
//class ServerState {
//    final Gson gson = new Gson();
//    final Map<String, User> usersById = new ConcurrentHashMap<>();
//    final Map<String, User> usersByName = new ConcurrentHashMap<>();
//    final Map<String, User> usersByEmail = new ConcurrentHashMap<>();
//    final Map<String, String> tokens = new ConcurrentHashMap<>(); // token -> userId
//
//    final Map<String, List<Song>> byCategory = new ConcurrentHashMap<>();
//    final Map<String, Song> songsById = new ConcurrentHashMap<>();
//    final Map<String, List<Comment>> commentsBySong = new ConcurrentHashMap<>();
//
//    // کلاینت‌های متصل برای broadcast
//    final Set<PrintWriter> clients = ConcurrentHashMap.newKeySet();
//
//    void addClient(PrintWriter out){ clients.add(out); }
//    void removeClient(PrintWriter out){ clients.remove(out); }
//
//    void broadcast(Map<String, Object> event) {
//        String line = gson.toJson(event);
//        for (PrintWriter out : clients) {
//            try { out.println(line); out.flush(); } catch (Exception ignored) {}
//        }
//    }
//
//    synchronized void addSong(Song s) {
//        songsById.put(s.id, s);
//        byCategory.computeIfAbsent(s.category, k->new CopyOnWriteArrayList<>()).add(0, s);
//        commentsBySong.putIfAbsent(s.id, new CopyOnWriteArrayList<>());
//    }
//
//    List<String> categories() { return new ArrayList<>(byCategory.keySet()); }
//
//    Song makeRandomSong() {
//        String[] cats = byCategory.keySet().isEmpty() ? new String[]{"New Releases"} : byCategory.keySet().toArray(new String[0]);
//        String cat = cats[new Random().nextInt(cats.length)];
//        String id = UUID.randomUUID().toString();
//        return new Song(
//            id, "New Track " + (100 + new Random().nextInt(900)), "Server Artist", cat,
//            new Random().nextBoolean()? 0.0 : 0.89,
//            4.0 + new Random().nextDouble(), new Random().nextInt(3000),
//            "https://picsum.photos/seed/" + id.substring(0,6) + "/600/600",
//            "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3"
//        );
//    }
//
//    void seedData() {
//        if (songsById.isEmpty()) {
//            addSong(new Song(UUID.randomUUID().toString(), "As It Was", "Harry Styles", "Pop", 1.29, 4.8, 5000,
//                "https://picsum.photos/seed/asitwas/600/600",
//                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3"));
//            addSong(new Song(UUID.randomUUID().toString(), "Smells Like Teen Spirit", "Nirvana", "Rock", 0.0, 4.9, 10000,
//                "https://picsum.photos/seed/teen-spirit/600/600",
//                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3"));
//            addSong(new Song(UUID.randomUUID().toString(), "Billie Jean", "Michael Jackson", "Classic", 1.29, 5.0, 8000,
//                "https://picsum.photos/seed/billiejean/600/600",
//                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3"));
//            addSong(new Song(UUID.randomUUID().toString(), "Rolling in the Deep", "Adele", "Pop", 0.99, 4.7, 7500,
//                "https://picsum.photos/seed/rolling/600/600",
//                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3"));
//            addSong(new Song(UUID.randomUUID().toString(), "Uptown Funk", "Mark Ronson ft. Bruno Mars", "New Releases", 0.0, 4.6, 9200,
//                "https://picsum.photos/seed/uptown/600/600",
//                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3"));
//
//            signup("demo", "demo@example.com", "DemoPass123");
//            System.out.println("Seeded songs + demo user (demo/DemoPass123).");
//        }
//    }
//
//    synchronized Map<String,Object> signup(String u, String e, String p){
//        if (usersByName.containsKey(u) || usersByEmail.containsKey(e)) {
//            throw new RuntimeException("username or email exists");
//        }
//        String id = UUID.randomUUID().toString();
//        User user = new User(id, u, e, p);
//        usersById.put(id, user);
//        usersByName.put(u, user);
//        usersByEmail.put(e, user);
//        String token = UUID.randomUUID().toString();
//        tokens.put(token, id);
//        Map<String,Object> res = new LinkedHashMap<>();
//        res.put("token", token);
//        res.put("user", user.toMap());
//        return res;
//    }
//
//    synchronized Map<String,Object> login(String idOrMail, String p){
//        User u = usersByName.get(idOrMail);
//        if (u == null) u = usersByEmail.get(idOrMail);
//        if (u == null) throw new RuntimeException("user not found");
//        if (!Objects.equals(u.password, p)) throw new RuntimeException("invalid password");
//        String token = UUID.randomUUID().toString();
//        tokens.put(token, u.id);
//        Map<String,Object> res = new LinkedHashMap<>();
//        res.put("token", token);
//        res.put("user", u.toMap());
//        return res;
//    }
//
//    User authed(String token){
//        if (token == null) throw new RuntimeException("no token");
//        String uid = tokens.get(token);
//        if (uid == null) throw new RuntimeException("invalid token");
//        User u = usersById.get(uid);
//        if (u == null) throw new RuntimeException("invalid token");
//        return u;
//    }
//}
//
//// ====== هندلر کلاینت ======
//class ClientHandler extends Thread {
//    private final Socket sock;
//    private final ServerState state;
//    private final Gson gson = new Gson();
//    private PrintWriter out;
//
//    ClientHandler(Socket s, ServerState st){ this.sock=s; this.state=st; }
//
//    public void run(){
//        try (BufferedReader br = new BufferedReader(new InputStreamReader(sock.getInputStream(),"UTF-8"))) {
//            out = new PrintWriter(new OutputStreamWriter(sock.getOutputStream(),"UTF-8"), true);
//            state.addClient(out);
//            String line;
//            while ((line = br.readLine()) != null) {
//                try {
//                    handle(line);
//                } catch (Exception ex) {
//                    // بی‌صدا
//                }
//            }
//        } catch (Exception ignored) {
//        } finally {
//            if (out != null) state.removeClient(out);
//            try { sock.close(); } catch (Exception ignored) {}
//        }
//    }
//
//    private void handle(String line) {
//        Map<?,?> m = gson.fromJson(line, Map.class);
//        String reqId = (String) m.get("reqId");
//        String action = (String) m.get("action");
//        String token = (String) m.get("token");
//        Map<?,?> data = (Map<?,?>) m.get("data");
//
//        Map<String,Object> result = new LinkedHashMap<>();
//        try {
//            Object res = switch (action) {
//                case "signup" -> {
//                    String u = (String) data.get("username");
//                    String e = (String) data.get("email");
//                    String p = (String) data.get("password");
//                    yield state.signup(u, e, p);
//                }
//                case "login" -> {
//                    String u = (String) data.get("userOrEmail");
//                    String p = (String) data.get("password");
//                    yield state.login(u, p);
//                }
//                case "me" -> {
//                    User me = state.authed(token);
//                    yield me.toMap();
//                }
//                case "updateProfile" -> {
//                    User me = state.authed(token);
//                    String newU = data != null ? (String) data.get("username") : null;
//                    String newE = data != null ? (String) data.get("email") : null;
//                    synchronized (state) {
//                        if (newU != null && !newU.isBlank()) {
//                            state.usersByName.remove(me.username);
//                            me.username = newU;
//                            state.usersByName.put(me.username, me);
//                        }
//                        if (newE != null && !newE.isBlank()) {
//                            state.usersByEmail.remove(me.email);
//                            me.email = newE;
//                            state.usersByEmail.put(me.email, me);
//                        }
//                    }
//                    yield me.toMap();
//                }
//                case "addCredit" -> {
//                    User me = state.authed(token);
//                    double amount = ((Number) data.get("amount")).doubleValue();
//                    me.credit += amount;
//                    yield Map.of("credit", me.credit);
//                }
//                case "subscription" -> {
//                    User me = state.authed(token);
//                    String plan = (String) data.get("plan"); // monthly/yearly
//                    me.premium = true; // برای دمو
//                    yield Map.of("subscription", me.premium ? "premium" : "standard");
//                }
//                case "purchase" -> {
//                    User me = state.authed(token);
//                    String songId = (String) data.get("songId");
//                    Song s = state.songsById.get(songId);
//                    if (s == null) throw new RuntimeException("song not found");
//                    if (s.price > 0 && !me.premium) {
//                        if (me.credit < s.price) throw new RuntimeException("insufficient credit");
//                        me.credit -= s.price;
//                    }
//                    me.purchased.add(songId);
//                    s.downloads++;
//                    yield Map.of("ok", true, "credit", me.credit);
//                }
//                case "categories" -> state.categories();
//                case "songs" -> {
//                    String cat = (String) data.get("category");
//                    List<Song> list = state.byCategory.getOrDefault(cat, List.of());
//                    List<Map<String,Object>> mapped = new ArrayList<>();
//                    for (Song s : list) mapped.add(s.toMap());
//                    yield mapped;
//                }
//                case "rate" -> {
//                    String songId = (String) data.get("songId");
//                    double value = ((Number) data.get("value")).doubleValue();
//                    Song s = state.songsById.get(songId);
//                    if (s == null) throw new RuntimeException("song not found");
//                    synchronized (s) {
//                        double total = s.ratingAverage * s.ratingCount + value;
//                        s.ratingCount += 1;
//                        s.ratingAverage = total / s.ratingCount;
//                    }
//                    yield Map.of("ratingAverage", s.ratingAverage, "ratingCount", s.ratingCount);
//                }
//                case "comments" -> {
//                    String songId = (String) data.get("songId");
//                    List<Comment> list = state.commentsBySong.getOrDefault(songId, List.of());
//                    List<Map<String,Object>> mapped = new ArrayList<>();
//                    for (Comment c : list) mapped.add(c.toMap());
//                    yield mapped;
//                }
//                case "addComment" -> {
//                    User me = state.authed(token);
//                    String songId = (String) data.get("songId");
//                    String text = (String) data.get("text");
//                    Comment c = new Comment(UUID.randomUUID().toString(), songId, me.username, text);
//                    state.commentsBySong.computeIfAbsent(songId, k->new CopyOnWriteArrayList<>()).add(c);
//                    yield c.toMap();
//                }
//                case "likeComment" -> {
//                    String cid = (String) data.get("commentId");
//                    boolean up = Boolean.TRUE.equals(data.get("up"));
//                    for (List<Comment> list : state.commentsBySong.values()) {
//                        for (Comment c : list) {
//                            if (c.id.equals(cid)) {
//                                if (up) c.likes++; else c.dislikes++;
//                                yield Map.of("likes", c.likes, "dislikes", c.dislikes);
//                            }
//                        }
//                    }
//                    throw new RuntimeException("comment not found");
//                }
//                default -> throw new RuntimeException("unknown action: " + action);
//            };
//            result.put("reqId", reqId);
//            result.put("ok", true);
//            result.put("result", res);
//        } catch (Exception ex) {
//            result.put("reqId", reqId);
//            result.put("ok", false);
//            result.put("error", ex.getMessage());
//        }
//        out.println(gson.toJson(result));
//        out.flush();
//    }
//}




package org.example;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;
import com.google.gson.*;

// ====== ENTRYPOINT ======
public class SocketMusicServer {
    public static void main(String[] args) throws Exception {
        final int port = 29168;
        final String DATA_PATH = "server-data.json";

        ServerState state = new ServerState();
        state.setDataPath(DATA_PATH);

        boolean loaded = state.loadFromDisk(DATA_PATH);
        if (!loaded || !state.hasAnyData()) {
            state.seedData();
            state.saveToDisk(DATA_PATH);
        }

        ServerSocket serverSocket = new ServerSocket(port);
        System.out.println("Socket server listening on port " + port + " ...");

        ScheduledExecutorService sched = Executors.newSingleThreadScheduledExecutor();
        sched.scheduleAtFixedRate(() -> {
            try { state.saveToDisk(DATA_PATH); } catch (Exception ignored) {}
        }, 15, 15, TimeUnit.SECONDS);

        sched.scheduleAtFixedRate(() -> {
            try {
                Song s = state.makeRandomSong();
                state.addSong(s);
                state.saveToDisk(DATA_PATH);
                Map<String, Object> ev = new HashMap<>();
                ev.put("event", "new_release");
                ev.put("song", s.toMap());
                state.broadcast(ev);
            } catch (Exception ignored) {}
        }, 25, 25, TimeUnit.SECONDS);

        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try { state.saveToDisk(DATA_PATH); } catch (Exception ignored) {}
        }));

        while (true) {
            Socket sock = serverSocket.accept();
            new ClientHandler(sock, state).start();
        }
    }
}

// ====== مدل‌ها و وضعیت ======
class User {
    String id, username, email, password;
    double credit = 200.0;
    boolean premium = false;
    Set<String> purchased = new HashSet<>();

    User(String id, String u, String e, String p) { this.id=id; this.username=u; this.email=e; this.password=p; }

    Map<String,Object> toMap() {
        Map<String,Object> m = new LinkedHashMap<>();
        m.put("id", id); m.put("username", username); m.put("email", email);
        m.put("credit", credit); m.put("subscription", premium ? "premium" : "standard");
        return m;
    }

    Map<String,Object> toJson(){
        Map<String,Object> m = new LinkedHashMap<>();
        m.put("id", id); m.put("username", username); m.put("email", email);
        m.put("password", password);
        m.put("credit", credit); m.put("premium", premium);
        m.put("purchased", new ArrayList<>(purchased));
        return m;
    }

    @SuppressWarnings("unchecked")
    static User fromJson(Map<?,?> j){
        User u = new User(
            (String) j.get("id"),
            (String) j.get("username"),
            (String) j.get("email"),
            (String) j.get("password")
        );
        Object cr = j.get("credit"); if (cr instanceof Number n) u.credit = n.doubleValue();
        Object pr = j.get("premium"); if (pr instanceof Boolean b) u.premium = b;
        Object pur = j.get("purchased");
        if (pur instanceof List<?> l) for(Object x:l) u.purchased.add(String.valueOf(x));
        return u;
    }
}

class Song {
    String id, title, artist, category, albumArtUrl, sourceUrl;
    int playCount = 0, ratingCount = 1, downloads = 0;
    double price = 0.0, ratingAverage = 4.5;
    Date addedAt = new Date();

    Song(String id, String t, String a, String c, double price, double rating, int dl, String art, String url) {
        this.id=id; this.title=t; this.artist=a; this.category=c; this.price=price;
        this.ratingAverage=rating; this.downloads=dl; this.albumArtUrl=art; this.sourceUrl=url;
        this.addedAt = new Date();
    }

    Map<String,Object> toMap() {
        Map<String,Object> m = new LinkedHashMap<>();
        m.put("id", id); m.put("title", title); m.put("artist", artist); m.put("category", category);
        m.put("price", price); m.put("ratingAverage", ratingAverage); m.put("ratingCount", ratingCount);
        m.put("downloads", downloads); m.put("albumArtUrl", albumArtUrl); m.put("sourceUrl", sourceUrl);
        m.put("addedAt", iso(addedAt));
        return m;
    }

    static String iso(Date d){ return new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").format(d); }

    // === هلپرهای امن برای تبدیل ===
    private static double getDouble(Object v, double def) {
        if (v instanceof Number n) return n.doubleValue();
        if (v == null) return def;
        try { return Double.parseDouble(v.toString()); } catch (Exception e) { return def; }
    }
    private static int getInt(Object v, int def) {
        if (v instanceof Number n) return n.intValue();
        if (v == null) return def;
        try { return Integer.parseInt(v.toString()); } catch (Exception e) { return def; }
    }

    // ⚠️ امضای جدید: Map<String,Object> و عدم استفاده از getOrDefault
    static Song fromMap(Map<String,Object> m){
        Song s = new Song(
            (String)m.get("id"),
            (String)m.get("title"),
            (String)m.get("artist"),
            (String)m.get("category"),
            getDouble(m.get("price"), 0.0),
            getDouble(m.get("ratingAverage"), 4.5),
            getInt(m.get("downloads"), 0),
            (String)m.get("albumArtUrl"),
            (String)m.get("sourceUrl")
        );
        Object rc = m.get("ratingCount"); if (rc instanceof Number n) s.ratingCount = n.intValue();
        Object ad = m.get("addedAt"); if (ad instanceof String str) {
            try { s.addedAt = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").parse(str); } catch(Exception ignore){}
        }
        return s;
    }
}

class Comment {
    String id, songId, user, text;
    int likes=0, dislikes=0;
    Date createdAt = new Date();

    Comment(String id, String sid, String u, String t){ this.id=id; this.songId=sid; this.user=u; this.text=t; }

    Map<String,Object> toMap(){
        Map<String,Object> m = new LinkedHashMap<>();
        m.put("id", id); m.put("songId", songId); m.put("user", user); m.put("text", text);
        m.put("likes", likes); m.put("dislikes", dislikes);
        m.put("createdAt", Song.iso(createdAt));
        return m;
    }

    static Comment fromMap(Map<?,?> m){
        Comment c = new Comment(
            (String)m.get("id"),
            (String)m.get("songId"),
            (String)m.get("user"),
            (String)m.get("text")
        );
        Object lk = m.get("likes"); if (lk instanceof Number n) c.likes = n.intValue();
        Object dk = m.get("dislikes"); if (dk instanceof Number n) c.dislikes = n.intValue();
        Object ct = m.get("createdAt"); if (ct instanceof String str) {
            try { c.createdAt = new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'").parse(str); } catch(Exception ignore){}
        }
        return c;
    }
}

class ServerState {
    final Gson gson = new Gson();
    final Map<String, User> usersById = new ConcurrentHashMap<>();
    final Map<String, User> usersByName = new ConcurrentHashMap<>();
    final Map<String, User> usersByEmail = new ConcurrentHashMap<>();
    final Map<String, String> tokens = new ConcurrentHashMap<>(); // token -> userId

    final Map<String, List<Song>> byCategory = new ConcurrentHashMap<>();
    final Map<String, Song> songsById = new ConcurrentHashMap<>();
    final Map<String, List<Comment>> commentsBySong = new ConcurrentHashMap<>();

    final Set<PrintWriter> clients = ConcurrentHashMap.newKeySet();

    private String dataPath = "server-data.json";
    void setDataPath(String p){ this.dataPath = p; }
    void saveNow(){ try { saveToDisk(this.dataPath); } catch(Exception ignored){} }

    void addClient(PrintWriter out){ clients.add(out); }
    void removeClient(PrintWriter out){ clients.remove(out); }

    void broadcast(Map<String, Object> event) {
        String line = gson.toJson(event);
        for (PrintWriter out : clients) {
            try { out.println(line); out.flush(); } catch (Exception ignored) {}
        }
    }

    synchronized void addSong(Song s) {
        songsById.put(s.id, s);
        byCategory.computeIfAbsent(s.category, k->new CopyOnWriteArrayList<>()).add(0, s);
        commentsBySong.putIfAbsent(s.id, new CopyOnWriteArrayList<>());
    }

    List<String> categories() { return new ArrayList<>(byCategory.keySet()); }

    Song makeRandomSong() {
        String[] cats = byCategory.keySet().isEmpty() ? new String[]{"New Releases"} : byCategory.keySet().toArray(new String[0]);
        String cat = cats[new Random().nextInt(cats.length)];
        String id = UUID.randomUUID().toString();
        return new Song(
            id, "New Track " + (100 + new Random().nextInt(900)), "Server Artist", cat,
            new Random().nextBoolean()? 0.0 : 0.89,
            4.0 + new Random().nextDouble(), new Random().nextInt(3000),
            "https://picsum.photos/seed/" + id.substring(0,6) + "/600/600",
            "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-16.mp3"
        );
    }

    void seedData() {
        if (songsById.isEmpty()) {
            addSong(new Song(UUID.randomUUID().toString(), "As It Was", "Harry Styles", "Pop", 1.29, 4.8, 5000,
                "https://picsum.photos/seed/asitwas/600/600",
                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-11.mp3"));
            addSong(new Song(UUID.randomUUID().toString(), "Smells Like Teen Spirit", "Nirvana", "Rock", 0.0, 4.9, 10000,
                "https://picsum.photos/seed/teen-spirit/600/600",
                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-12.mp3"));
            addSong(new Song(UUID.randomUUID().toString(), "Billie Jean", "Michael Jackson", "Classic", 1.29, 5.0, 8000,
                "https://picsum.photos/seed/billiejean/600/600",
                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-13.mp3"));
            addSong(new Song(UUID.randomUUID().toString(), "Rolling in the Deep", "Adele", "Pop", 0.99, 4.7, 7500,
                "https://picsum.photos/seed/rolling/600/600",
                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3"));
            addSong(new Song(UUID.randomUUID().toString(), "Uptown Funk", "Mark Ronson ft. Bruno Mars", "New Releases", 0.0, 4.6, 9200,
                "https://picsum.photos/seed/uptown/600/600",
                "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-15.mp3"));

            signup("demo", "demo@example.com", "DemoPass123");
            System.out.println("Seeded songs + demo user (demo/DemoPass123).");
        }
    }

    synchronized Map<String,Object> signup(String u, String e, String p){
        if (usersByName.containsKey(u) || usersByEmail.containsKey(e)) {
            throw new RuntimeException("username or email exists");
        }
        String id = UUID.randomUUID().toString();
        User user = new User(id, u, e, p);
        usersById.put(id, user);
        usersByName.put(u, user);
        usersByEmail.put(e, user);
        String token = UUID.randomUUID().toString();
        tokens.put(token, id);
        Map<String,Object> res = new LinkedHashMap<>();
        res.put("token", token);
        res.put("user", user.toMap());
        saveNow();
        return res;
    }

    synchronized Map<String,Object> login(String idOrMail, String p){
        User u = usersByName.get(idOrMail);
        if (u == null) u = usersByEmail.get(idOrMail);
        if (u == null) throw new RuntimeException("user not found");
        if (!Objects.equals(u.password, p)) throw new RuntimeException("invalid password");
        String token = UUID.randomUUID().toString();
        tokens.put(token, u.id);
        Map<String,Object> res = new LinkedHashMap<>();
        res.put("token", token);
        res.put("user", u.toMap());
        return res;
    }

    User authed(String token){
        if (token == null) throw new RuntimeException("no token");
        String uid = tokens.get(token);
        if (uid == null) throw new RuntimeException("invalid token");
        User u = usersById.get(uid);
        if (u == null) throw new RuntimeException("invalid token");
        return u;
    }

    synchronized Map<String,Object> snapshot(){
        Map<String,Object> m = new LinkedHashMap<>();
        List<Map<String,Object>> users = new ArrayList<>();
        for (User u: usersById.values()) users.add(u.toJson());
        List<Map<String,Object>> songs = new ArrayList<>();
        for (Song s: songsById.values()) songs.add(s.toMap());
        List<Map<String,Object>> comments = new ArrayList<>();
        for (List<Comment> list: commentsBySong.values())
            for (Comment c: list) comments.add(c.toMap());
        m.put("users", users);
        m.put("songs", songs);
        m.put("comments", comments);
        return m;
    }

    synchronized void saveToDisk(String path){
        try (Writer w = new OutputStreamWriter(new FileOutputStream(path), StandardCharsets.UTF_8)) {
            gson.toJson(snapshot(), w);
        } catch(Exception e){ e.printStackTrace(); }
    }

    @SuppressWarnings("unchecked")
    synchronized boolean loadFromDisk(String path){
        File f = new File(path);
        if (!f.exists()) return false;
        try (Reader r = new InputStreamReader(new FileInputStream(f), StandardCharsets.UTF_8)) {
            Map<String,Object> m = gson.fromJson(r, Map.class);
            List<Map<String,Object>> users = (List<Map<String,Object>>) m.getOrDefault("users", List.of());
            List<Map<String,Object>> songs = (List<Map<String,Object>>) m.getOrDefault("songs", List.of());
            List<Map<String,Object>> comments = (List<Map<String,Object>>) m.getOrDefault("comments", List.of());

            usersById.clear(); usersByName.clear(); usersByEmail.clear();
            for (Map<String,Object> ju : users){
                User u = User.fromJson(ju);
                usersById.put(u.id, u);
                usersByName.put(u.username, u);
                usersByEmail.put(u.email, u);
            }
            songsById.clear(); byCategory.clear(); commentsBySong.clear();
            for (Map<String,Object> js : songs){
                Song s = Song.fromMap(js);
                addSong(s);
            }
            for (Map<String,Object> jc : comments){
                Comment c = Comment.fromMap(jc);
                commentsBySong.computeIfAbsent(c.songId, k->new CopyOnWriteArrayList<>()).add(c);
            }
            return true;
        } catch(Exception e){ e.printStackTrace(); return false; }
    }

    boolean hasAnyData(){ return !songsById.isEmpty() || !usersById.isEmpty(); }
}

// ====== هندلر کلاینت ======
class ClientHandler extends Thread {
    private final Socket sock;
    private final ServerState state;
    private final Gson gson = new Gson();
    private PrintWriter out;

    ClientHandler(Socket s, ServerState st){ this.sock=s; this.state=st; }

    public void run(){
        try (BufferedReader br = new BufferedReader(new InputStreamReader(sock.getInputStream(),"UTF-8"))) {
            out = new PrintWriter(new OutputStreamWriter(sock.getOutputStream(),"UTF-8"), true);
            state.addClient(out);
            String line;
            while ((line = br.readLine()) != null) {
                try {
                    handle(line);
                } catch (Exception ex) {
                    // ignore
                }
            }
        } catch (Exception ignored) {
        } finally {
            if (out != null) state.removeClient(out);
            try { sock.close(); } catch (Exception ignored) {}
        }
    }

    private void handle(String line) {
        Map<?,?> m = gson.fromJson(line, Map.class);
        String reqId = (String) m.get("reqId");
        String action = (String) m.get("action");
        String token = (String) m.get("token");
        Map<?,?> data = (Map<?,?>) m.get("data");

        Map<String,Object> result = new LinkedHashMap<>();
        try {
            Object res = switch (action) {
                case "signup" -> {
                    String u = (String) data.get("username");
                    String e = (String) data.get("email");
                    String p = (String) data.get("password");
                    yield state.signup(u, e, p);
                }
                case "login" -> {
                    String u = (String) data.get("userOrEmail");
                    String p = (String) data.get("password");
                    yield state.login(u, p);
                }
                case "me" -> {
                    User me = state.authed(token);
                    yield me.toMap();
                }
                case "updateProfile" -> {
                    User me = state.authed(token);
                    String newU = data != null ? (String) data.get("username") : null;
                    String newE = data != null ? (String) data.get("email") : null;
                    synchronized (state) {
                        if (newU != null && !newU.isBlank()) {
                            state.usersByName.remove(me.username);
                            me.username = newU;
                            state.usersByName.put(me.username, me);
                        }
                        if (newE != null && !newE.isBlank()) {
                            state.usersByEmail.remove(me.email);
                            me.email = newE;
                            state.usersByEmail.put(me.email, me);
                        }
                    }
                    state.saveNow();
                    yield me.toMap();
                }
                case "addCredit" -> {
                    User me = state.authed(token);
                    double amount = ((Number) data.get("amount")).doubleValue();
                    me.credit += amount;
                    state.saveNow();
                    yield Map.of("credit", me.credit);
                }
                case "subscription" -> {
                    User me = state.authed(token);
                    String plan = (String) data.get("plan");
                    me.premium = true;
                    state.saveNow();
                    yield Map.of("subscription", me.premium ? "premium" : "standard");
                }
                case "purchase" -> {
                    User me = state.authed(token);
                    String songId = (String) data.get("songId");
                    Song s = state.songsById.get(songId);
                    if (s == null) throw new RuntimeException("song not found");
                    if (s.price > 0 && !me.premium) {
                        if (me.credit < s.price) throw new RuntimeException("insufficient credit");
                        me.credit -= s.price;
                    }
                    me.purchased.add(songId);
                    s.downloads++;
                    state.saveNow();
                    yield Map.of("ok", true, "credit", me.credit);
                }
                case "categories" -> state.categories();
                case "songs" -> {
                    String cat = (String) data.get("category");
                    List<Song> list = state.byCategory.getOrDefault(cat, List.of());
                    List<Map<String,Object>> mapped = new ArrayList<>();
                    for (Song s : list) mapped.add(s.toMap());
                    yield mapped;
                }
                case "rate" -> {
                    String songId = (String) data.get("songId");
                    double value = ((Number) data.get("value")).doubleValue();
                    Song s = state.songsById.get(songId);
                    if (s == null) throw new RuntimeException("song not found");
                    synchronized (s) {
                        double total = s.ratingAverage * s.ratingCount + value;
                        s.ratingCount += 1;
                        s.ratingAverage = total / s.ratingCount;
                    }
                    state.saveNow();
                    yield Map.of("ratingAverage", s.ratingAverage, "ratingCount", s.ratingCount);
                }
                case "comments" -> {
                    String songId = (String) data.get("songId");
                    List<Comment> list = state.commentsBySong.getOrDefault(songId, List.of());
                    List<Map<String,Object>> mapped = new ArrayList<>();
                    for (Comment c : list) mapped.add(c.toMap());
                    yield mapped;
                }
                case "addComment" -> {
                    User me = state.authed(token);
                    String songId = (String) data.get("songId");
                    String text = (String) data.get("text");
                    Comment c = new Comment(UUID.randomUUID().toString(), songId, me.username, text);
                    state.commentsBySong.computeIfAbsent(songId, k->new CopyOnWriteArrayList<>()).add(c);
                    state.saveNow();
                    yield c.toMap();
                }
                case "likeComment" -> {
                    String cid = (String) data.get("commentId");
                    boolean up = Boolean.TRUE.equals(data.get("up"));
                    for (List<Comment> list : state.commentsBySong.values()) {
                        for (Comment c : list) {
                            if (c.id.equals(cid)) {
                                if (up) c.likes++; else c.dislikes++;
                                state.saveNow();
                                yield Map.of("likes", c.likes, "dislikes", c.dislikes);
                            }
                        }
                    }
                    throw new RuntimeException("comment not found");
                }
                default -> throw new RuntimeException("unknown action: " + action);
            };
            result.put("reqId", reqId);
            result.put("ok", true);
            result.put("result", res);
        } catch (Exception ex) {
            result.put("reqId", reqId);
            result.put("ok", false);
            result.put("error", ex.getMessage());
        }
        out.println(gson.toJson(result));
        out.flush();
    }
}
