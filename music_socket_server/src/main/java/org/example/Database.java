package org.example;

import java.sql.*;
import java.util.*;

public class Database implements AutoCloseable {
    private final String url; // jdbc:sqlite:music.db
    private Connection conn;

    public Database(String url) {
        this.url = url;
    }

    public void connect() throws SQLException {
        if (conn == null || conn.isClosed()) {
            conn = DriverManager.getConnection(url);
            conn.createStatement().execute("PRAGMA foreign_keys = ON");
        }
    }

    public void initSchemaIfNeeded() throws SQLException {
        connect();
        // جداول
        try (Statement st = conn.createStatement()) {
            st.execute("""
                CREATE TABLE IF NOT EXISTS users (
                  id TEXT PRIMARY KEY,
                  username TEXT UNIQUE NOT NULL,
                  email TEXT UNIQUE NOT NULL,
                  password TEXT NOT NULL,
                  credit REAL NOT NULL DEFAULT 200.0,
                  premium INTEGER NOT NULL DEFAULT 0
                )
            """);
            st.execute("""
                CREATE TABLE IF NOT EXISTS tokens (
                  token TEXT PRIMARY KEY,
                  userId TEXT NOT NULL,
                  createdAt TEXT NOT NULL,
                  FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
                )
            """);
            st.execute("""
                CREATE TABLE IF NOT EXISTS songs (
                  id TEXT PRIMARY KEY,
                  title TEXT NOT NULL,
                  artist TEXT NOT NULL,
                  category TEXT NOT NULL,
                  price REAL NOT NULL,
                  ratingAverage REAL NOT NULL,
                  ratingCount INTEGER NOT NULL,
                  downloads INTEGER NOT NULL,
                  albumArtUrl TEXT NOT NULL,
                  sourceUrl TEXT NOT NULL,
                  addedAt TEXT NOT NULL
                )
            """);
            st.execute("""
                CREATE TABLE IF NOT EXISTS comments (
                  id TEXT PRIMARY KEY,
                  songId TEXT NOT NULL,
                  user TEXT NOT NULL,
                  text TEXT NOT NULL,
                  likes INTEGER NOT NULL DEFAULT 0,
                  dislikes INTEGER NOT NULL DEFAULT 0,
                  createdAt TEXT NOT NULL,
                  FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
                )
            """);
            st.execute("CREATE INDEX IF NOT EXISTS idx_songs_category ON songs(category)");
            st.execute("CREATE INDEX IF NOT EXISTS idx_comments_song ON comments(songId)");
        }
    }

    // ---------- USERS ----------
    public void insertUser(User u) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            INSERT INTO users(id, username, email, password, credit, premium) VALUES(?,?,?,?,?,?)
        """)) {
            ps.setString(1, u.id);
            ps.setString(2, u.username);
            ps.setString(3, u.email);
            ps.setString(4, u.password);
            ps.setDouble(5, u.credit);
            ps.setInt(6, u.premium ? 1 : 0);
            ps.executeUpdate();
        }
    }

    public User findUserByUsername(String username) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT id, username, email, password, credit, premium FROM users WHERE username=?
        """)) {
            ps.setString(1, username);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                User u = new User(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("email"),
                        rs.getString("password")
                );
                u.credit = rs.getDouble("credit");
                u.premium = rs.getInt("premium") == 1;
                return u;
            }
            return null;
        }
    }

    public User findUserByEmail(String email) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT id, username, email, password, credit, premium FROM users WHERE email=?
        """)) {
            ps.setString(1, email);
            ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                User u = new User(
                        rs.getString("id"),
                        rs.getString("username"),
                        rs.getString("email"),
                        rs.getString("password")
                );
                u.credit = rs.getDouble("credit");
                u.premium = rs.getInt("premium") == 1;
                return u;
            }
            return null;
        }
    }

    public void updateUserBasic(User u) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            UPDATE users SET username=?, email=?, credit=?, premium=? WHERE id=?
        """)) {
            ps.setString(1, u.username);
            ps.setString(2, u.email);
            ps.setDouble(3, u.credit);
            ps.setInt(4, u.premium ? 1 : 0);
            ps.setString(5, u.id);
            ps.executeUpdate();
        }
    }

    // ---------- TOKENS ----------
    public void upsertToken(String token, String userId) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            INSERT INTO tokens(token, userId, createdAt) VALUES(?,?,datetime('now'))
            ON CONFLICT(token) DO UPDATE SET userId=excluded.userId, createdAt=datetime('now')
        """)) {
            ps.setString(1, token);
            ps.setString(2, userId);
            ps.executeUpdate();
        }
    }

    public String getUserIdByToken(String token) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT userId FROM tokens WHERE token=?
        """)) {
            ps.setString(1, token);
            ResultSet rs = ps.executeQuery();
            return rs.next() ? rs.getString(1) : null;
        }
    }

    // ---------- SONGS ----------
    public void insertSong(Song s) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            INSERT INTO songs(id, title, artist, category, price, ratingAverage, ratingCount, downloads, albumArtUrl, sourceUrl, addedAt)
            VALUES(?,?,?,?,?,?,?,?,?,?,?)
        """)) {
            ps.setString(1, s.id);
            ps.setString(2, s.title);
            ps.setString(3, s.artist);
            ps.setString(4, s.category);
            ps.setDouble(5, s.price);
            ps.setDouble(6, s.ratingAverage);
            ps.setInt(7, s.ratingCount);
            ps.setInt(8, s.downloads);
            ps.setString(9, s.albumArtUrl);
            ps.setString(10, s.sourceUrl);
            ps.setString(11, Song.iso(s.addedAt));
            ps.executeUpdate();
        }
    }

    public List<String> listCategories() throws SQLException {
        connect();
        List<String> cats = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT DISTINCT category FROM songs ORDER BY category
        """)) {
            ResultSet rs = ps.executeQuery();
            while (rs.next()) cats.add(rs.getString(1));
        }
        return cats;
    }

    public List<Map<String, Object>> listSongsByCategory(String category) throws SQLException {
        connect();
        List<Map<String,Object>> list = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT * FROM songs WHERE category=? ORDER BY datetime(addedAt) DESC
        """)) {
            ps.setString(1, category);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                Map<String,Object> m = new LinkedHashMap<>();
                m.put("id", rs.getString("id"));
                m.put("title", rs.getString("title"));
                m.put("artist", rs.getString("artist"));
                m.put("category", rs.getString("category"));
                m.put("price", rs.getDouble("price"));
                m.put("ratingAverage", rs.getDouble("ratingAverage"));
                m.put("ratingCount", rs.getInt("ratingCount"));
                m.put("downloads", rs.getInt("downloads"));
                m.put("albumArtUrl", rs.getString("albumArtUrl"));
                m.put("sourceUrl", rs.getString("sourceUrl"));
                m.put("addedAt", rs.getString("addedAt"));
                list.add(m);
            }
        }
        return list;
    }

    public void updateSongRating(String songId, double ratingAverage, int ratingCount) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            UPDATE songs SET ratingAverage=?, ratingCount=? WHERE id=?
        """)) {
            ps.setDouble(1, ratingAverage);
            ps.setInt(2, ratingCount);
            ps.setString(3, songId);
            ps.executeUpdate();
        }
    }

    public void incrementDownloads(String songId) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            UPDATE songs SET downloads = downloads + 1 WHERE id=?
        """)) {
            ps.setString(1, songId);
            ps.executeUpdate();
        }
    }

    // ---------- COMMENTS ----------
    public void insertComment(Comment c) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement("""
            INSERT INTO comments(id, songId, user, text, likes, dislikes, createdAt)
            VALUES(?,?,?,?,?,?,?)
        """)) {
            ps.setString(1, c.id);
            ps.setString(2, c.songId);
            ps.setString(3, c.user);
            ps.setString(4, c.text);
            ps.setInt(5, c.likes);
            ps.setInt(6, c.dislikes);
            ps.setString(7, Song.iso(c.createdAt));
            ps.executeUpdate();
        }
    }

    public List<Map<String, Object>> listCommentsBySong(String songId) throws SQLException {
        connect();
        List<Map<String,Object>> list = new ArrayList<>();
        try (PreparedStatement ps = conn.prepareStatement("""
            SELECT * FROM comments WHERE songId=? ORDER BY datetime(createdAt) DESC
        """)) {
            ps.setString(1, songId);
            ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                Map<String,Object> m = new LinkedHashMap<>();
                m.put("id", rs.getString("id"));
                m.put("songId", rs.getString("songId"));
                m.put("user", rs.getString("user"));
                m.put("text", rs.getString("text"));
                m.put("likes", rs.getInt("likes"));
                m.put("dislikes", rs.getInt("dislikes"));
                m.put("createdAt", rs.getString("createdAt"));
                list.add(m);
            }
        }
        return list;
    }

    public void updateCommentVotes(String commentId, boolean up) throws SQLException {
        connect();
        try (PreparedStatement ps = conn.prepareStatement(
                up ? "UPDATE comments SET likes=likes+1 WHERE id=?"
                        : "UPDATE comments SET dislikes=dislikes+1 WHERE id=?"
        )) {
            ps.setString(1, commentId);
            ps.executeUpdate();
        }
    }

    // ---------- UTILS ----------
    public boolean hasAnySongs() throws SQLException {
        connect();
        try (Statement st = conn.createStatement()) {
            ResultSet rs = st.executeQuery("SELECT COUNT(*) FROM songs");
            return rs.next() && rs.getInt(1) > 0;
        }
    }

    @Override
    public void close() {
        try { if (conn != null) conn.close(); } catch (Exception ignored) {}
    }
}
