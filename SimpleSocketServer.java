import java.io.BufferedReader;
import java.io.File;
import java.io.FilenameFilter;
import java.io.InputStreamReader;
import java.io.PrintWriter;
import java.net.ServerSocket;
import java.net.Socket;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.Collections;

public class SimpleSocketServer {
 private static final int PORT = 12345;
 // مسیر پوشه آهنگ های پیش فرض سرور، نسبت به محل اجرای سرور
 private static final String MUSIC_LIBRARY_PATH = "server_music_library";

 // لیست های در حافظه برای ذخیره سازی موقت داده ها
 private static final List<SongInfo> serverMusicLibrary = Collections.synchronizedList(new ArrayList<>());
 private static final Map<String, PlaylistInfo> createdPlaylists = Collections.synchronizedMap(new HashMap<>());
 private static final List<SongInfo> userUploadedSongs = Collections.synchronizedList(new ArrayList<>()); // برای متادیتای آهنگ های آپلود شده توسط کاربر

 // مقادیر ثابت برای شبیه سازی لاگین (بسیار ناامن)
 private static final String HARDCODED_EMAIL = "test@example.com";
 private static final String HARDCODED_PASSWORD = "password123";

 // کلاس ساده برای نگهداری اطلاعات آهنگ
 private static class SongInfo {
  String title;        // عنوان آهنگ (می تواند نام فایل یا عنوان واقعی باشد)
  String filenameOrId; // شناسه یکتای آهنگ (نام فایل برای آهنگ های سرور، می تواند ID تولیدی برای آهنگ های آپلودی باشد)
  String artist;       // نام هنرمند (اختیاری)

  SongInfo(String title, String filenameOrId, String artist) {
   this.title = title;
   this.filenameOrId = filenameOrId;
   this.artist = (artist == null || artist.isEmpty()) ? "Unknown Artist" : artist;
  }
 }

 // کلاس ساده برای نگهداری اطلاعات پلی لیست
 private static class PlaylistInfo {
  String name;
  List<String> songIdentifiers; // لیستی از filenameOrId آهنگ های موجود در این پلی لیست

  PlaylistInfo(String name) {
   this.name = name;
   this.songIdentifiers = new ArrayList<>();
  }
 }

 // متد برای بارگذاری آهنگ ها از پوشه محلی در زمان شروع به کار سرور
 private static void loadMusicLibrary() {
  File musicDir = new File(MUSIC_LIBRARY_PATH);
  System.out.println("Attempting to load music library from: " + musicDir.getAbsolutePath());

  if (!musicDir.exists() ) {
   System.out.println("Music library directory does not exist. Attempting to create: " + MUSIC_LIBRARY_PATH);
   if (musicDir.mkdirs()) {
    System.out.println("Successfully created music library directory. Please add music files and restart server.");
   } else {
    System.err.println("ERROR: Could not create music library directory: " + MUSIC_LIBRARY_PATH + ". Please create it manually.");
    return; // Exit if directory cannot be created
   }
  } else if (!musicDir.isDirectory()) {
   System.err.println("ERROR: Music library path exists but is not a directory: " + MUSIC_LIBRARY_PATH);
   return;
  }


  File[] musicFiles = musicDir.listFiles(new FilenameFilter() {
   public boolean accept(File dir, String name) {
    String lowerName = name.toLowerCase();
    return lowerName.endsWith(".mp3") ||
            lowerName.endsWith(".wav") ||
            lowerName.endsWith(".m4a") || // Apple Lossless Audio Codec
            lowerName.endsWith(".ogg") || // Ogg Vorbis
            lowerName.endsWith(".flac"); // Free Lossless Audio Codec
   }
  });

  serverMusicLibrary.clear(); // پاک کردن لیست قبلی در صورت وجود
  if (musicFiles != null) {
   for (File file : musicFiles) {
    if (file.isFile()) { // اطمینان از اینکه فقط فایل ها را می خوانیم
     // استفاده از نام فایل به عنوان عنوان و شناسه، و "Server Library" به عنوان هنرمند پیش فرض
     serverMusicLibrary.add(new SongInfo(file.getName(), file.getName(), "Server Library"));
    }
   }
   System.out.println("Loaded " + serverMusicLibrary.size() + " songs from the library: " + MUSIC_LIBRARY_PATH);
  } else {
   System.out.println("No music files found in the library or error reading directory.");
  }
 }

 // متد اصلی سرور
 public static void main(String[] args) {
  loadMusicLibrary(); // بارگذاری آهنگ های پیش فرض در زمان استارت

  try (ServerSocket serverSocket = new ServerSocket(PORT)) {
   System.out.println("Simple Music App Server (Java Edition) is listening on port " + PORT);
   System.out.println("--------------------------------------------------------------------");
   System.out.println("WARNING: This server uses IN-MEMORY storage for user-specific data.");
   System.out.println("         All uploaded song metadata and created playlists will be LOST on server restart.");
   System.out.println("WARNING: Email/password login is SIMULATED with hardcoded credentials and is NOT SECURE.");
   System.out.println("--------------------------------------------------------------------");

   while (true) { // حلقه اصلی برای پذیرش اتصالات کلاینت
    Socket clientSocket = serverSocket.accept();
    // لاگ کردن اتصال جدید کلاینت
    System.out.println("Client connected from " + clientSocket.getInetAddress().getHostAddress() + ":" + clientSocket.getPort());
    // ایجاد و راه اندازی یک رشته جدید برای هر کلاینت
    new ClientHandler(clientSocket).start();
   }
  } catch (IOException e) {
   System.err.println("Server Main Exception: Could not listen on port " + PORT + " or other IO error.");
   e.printStackTrace();
  }
 }

 // کلاس داخلی برای مدیریت هر کلاینت در یک رشته جداگانه
 private static class ClientHandler extends Thread {
  private final Socket clientSocket;

  public ClientHandler(Socket socket) {
   this.clientSocket = socket;
  }

  // متد کمکی برای پردازش بسیار ساده و شکننده JSON (بدون کتابخانه خارجی)
  private String getJsonValue(String jsonString, String key) {
   if (jsonString == null || key == null || jsonString.isEmpty() || key.isEmpty()) return "";
   String keyPattern = "\"" + key + "\":";
   int keyIndex = jsonString.indexOf(keyPattern);
   if (keyIndex == -1) return "";
   int valueStartIndex = keyIndex + keyPattern.length();
   while (valueStartIndex < jsonString.length() && Character.isWhitespace(jsonString.charAt(valueStartIndex))) {
    valueStartIndex++;
   }
   if (valueStartIndex >= jsonString.length()) return "";
   char firstCharOfValue = jsonString.charAt(valueStartIndex);
   int valueEndIndex;
   if (firstCharOfValue == '"') {
    valueStartIndex++;
    valueEndIndex = jsonString.indexOf("\"", valueStartIndex);
    if (valueEndIndex == -1) return "";
   } else {
    int commaIndex = jsonString.indexOf(",", valueStartIndex);
    int braceIndex = jsonString.indexOf("}", valueStartIndex);
    if (commaIndex != -1 && braceIndex != -1) valueEndIndex = Math.min(commaIndex, braceIndex);
    else if (commaIndex != -1) valueEndIndex = commaIndex;
    else if (braceIndex != -1) valueEndIndex = braceIndex;
    else return "";
   }
   if (valueStartIndex >= valueEndIndex) return "";
   return jsonString.substring(valueStartIndex, valueEndIndex).trim();
  }

  // متد کمکی برای escape کردن کاراکترهای خاص در رشته برای قرار گرفتن در JSON
  private String escapeJsonString(String value) {
   if (value == null) return "";
   return value.replace("\\", "\\\\")
           .replace("\"", "\\\"")
           .replace("\b", "\\b")
           .replace("\f", "\\f")
           .replace("\n", "\\n")
           .replace("\r", "\\r")
           .replace("\t", "\\t");
  }

  @Override
  public void run() {
   // استفاده از try-with-resources برای بستن خودکار reader و writer
   try (
           BufferedReader reader = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
           PrintWriter writer = new PrintWriter(clientSocket.getOutputStream(), true) // true for autoFlush
   ) {
    String clientMessage;
    // حلقه برای خواندن پیام ها از کلاینت تا زمانی که کلاینت متصل است
    while ((clientMessage = reader.readLine()) != null) {
     String currentThreadName = Thread.currentThread().getName();
     System.out.println(currentThreadName + " | Received from client ("+ clientSocket.getInetAddress().getHostAddress() +"): " + clientMessage);

     String action = getJsonValue(clientMessage, "action");
     String jsonResponse; // پاسخ JSON که به کلاینت ارسال خواهد شد

     if (action == null || action.isEmpty()) {
      jsonResponse = "{\"status\":\"error\",\"message\":\"Action not provided or malformed JSON request.\"}";
     } else if ("echo".equalsIgnoreCase(action)) {
      String data = getJsonValue(clientMessage, "data");
      jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Server received: %s\"}", escapeJsonString(data));
     } else if ("ping".equalsIgnoreCase(action)) {
      jsonResponse = "{\"status\":\"success\",\"message\":\"pong\"}";
     } else if ("login_email".equalsIgnoreCase(action)) {
      String email = getJsonValue(clientMessage, "email");
      String password = getJsonValue(clientMessage, "password");
      System.out.println(currentThreadName + " | Login attempt: Email=" + email); // از لاگ کردن پسورد در محیط واقعی خودداری کنید
      if (HARDCODED_EMAIL.equals(email) && HARDCODED_PASSWORD.equals(password)) {
       jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Login successful (simulated)\",\"user\":\"%s\"}", escapeJsonString(email));
       System.out.println(currentThreadName + " | Simulated login successful for: " + email);
      } else {
       jsonResponse = "{\"status\":\"error\",\"message\":\"Invalid email or password (simulated)\"}";
       System.out.println(currentThreadName + " | Simulated login failed for: " + email);
      }
     } else if ("upload_song_metadata".equalsIgnoreCase(action)) {
      String title = getJsonValue(clientMessage, "title");
      String artist = getJsonValue(clientMessage, "artist");
      if (!title.isEmpty()) {
       // برای آهنگ های آپلود شده، شناسه می تواند همان عنوان یا یک ID منحصر به فرد تولیدی باشد
       userUploadedSongs.add(new SongInfo(title, title, artist));
       System.out.println(currentThreadName + " | User 'Uploaded' Song Metadata Added: Title=" + title + ", Artist=" + artist + " (Total user songs: " + userUploadedSongs.size() + ")");
       jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Song metadata for '%s' received by server.\"}", escapeJsonString(title));
      } else {
       jsonResponse = "{\"status\":\"error\",\"message\":\"Song title is missing for metadata upload.\"}";
      }
     } else if ("create_playlist".equalsIgnoreCase(action)) {
      String playlistName = getJsonValue(clientMessage, "playlist_name");
      if (!playlistName.isEmpty()) {
       synchronized (createdPlaylists) { // همگام سازی برای دسترسی به createdPlaylists
        if (createdPlaylists.containsKey(playlistName)) {
         jsonResponse = String.format("{\"status\":\"error\",\"message\":\"Playlist '%s' already exists.\"}", escapeJsonString(playlistName));
        } else {
         createdPlaylists.put(playlistName, new PlaylistInfo(playlistName));
         System.out.println(currentThreadName + " | Playlist Created: " + playlistName + " (Total playlists: " + createdPlaylists.size() + ")");
         jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Playlist '%s' successfully created.\"}", escapeJsonString(playlistName));
        }
       }
      } else {
       jsonResponse = "{\"status\":\"error\",\"message\":\"Playlist name is missing.\"}";
      }
     } else if ("get_server_songs".equalsIgnoreCase(action)) {
      StringBuilder songsJsonArray = new StringBuilder("[");
      boolean firstSong = true;
      synchronized (serverMusicLibrary) {
       for (SongInfo song : serverMusicLibrary) {
        if (!firstSong) songsJsonArray.append(",");
        songsJsonArray.append(String.format("{\"title\":\"%s\",\"filename\":\"%s\",\"artist\":\"%s\"}",
                escapeJsonString(song.title),
                escapeJsonString(song.filenameOrId),
                escapeJsonString(song.artist)));
        firstSong = false;
       }
      }
      songsJsonArray.append("]");
      jsonResponse = String.format("{\"status\":\"success\",\"songs\":%s}", songsJsonArray.toString());
      System.out.println(currentThreadName + " | Sent " + serverMusicLibrary.size() + " server songs to client.");
     } else if ("get_my_playlists".equalsIgnoreCase(action)) {
      StringBuilder playlistsJsonArray = new StringBuilder("[");
      boolean firstPlaylist = true;
      synchronized (createdPlaylists) {
       for (PlaylistInfo pInfo : createdPlaylists.values()) {
        if (!firstPlaylist) playlistsJsonArray.append(",");
        StringBuilder songsInPlaylist = new StringBuilder("[");
        boolean firstSongInPlaylist = true;
        for (String songId : pInfo.songIdentifiers) {
         if (!firstSongInPlaylist) songsInPlaylist.append(",");
         songsInPlaylist.append(String.format("\"%s\"", escapeJsonString(songId)));
         firstSongInPlaylist = false;
        }
        songsInPlaylist.append("]");
        playlistsJsonArray.append(String.format("{\"name\":\"%s\",\"song_count\":%d,\"songs\":%s}",
                escapeJsonString(pInfo.name),
                pInfo.songIdentifiers.size(),
                songsInPlaylist.toString()));
        firstPlaylist = false;
       }
      }
      playlistsJsonArray.append("]");
      jsonResponse = String.format("{\"status\":\"success\",\"playlists\":%s}", playlistsJsonArray.toString());
      System.out.println(currentThreadName + " | Sent " + createdPlaylists.size() + " playlists to client.");
     } else if ("add_song_to_playlist".equalsIgnoreCase(action)) {
      String playlistName = getJsonValue(clientMessage, "playlist_name");
      String songIdentifier = getJsonValue(clientMessage, "song_identifier"); // باید عنوان/نام فایل آهنگ باشد
      if (!playlistName.isEmpty() && !songIdentifier.isEmpty()) {
       synchronized (createdPlaylists) {
        PlaylistInfo playlist = createdPlaylists.get(playlistName);
        if (playlist == null) {
         jsonResponse = String.format("{\"status\":\"error\",\"message\":\"Playlist '%s' not found.\"}", escapeJsonString(playlistName));
        } else {
         // بررسی وجود آهنگ (در آهنگ های سرور یا آهنگ های آپلود شده توسط کاربر)
         boolean songExists = serverMusicLibrary.stream().anyMatch(s -> s.filenameOrId.equals(songIdentifier)) ||
                 userUploadedSongs.stream().anyMatch(s -> s.filenameOrId.equals(songIdentifier));
         if (!songExists) {
          jsonResponse = String.format("{\"status\":\"error\",\"message\":\"Song '%s' not found in server or user uploads.\"}", escapeJsonString(songIdentifier));
         } else if (playlist.songIdentifiers.contains(songIdentifier)) {
          jsonResponse = String.format("{\"status\":\"info\",\"message\":\"Song '%s' is already in playlist '%s'.\"}", escapeJsonString(songIdentifier), escapeJsonString(playlistName));
         } else {
          playlist.songIdentifiers.add(songIdentifier);
          System.out.println(currentThreadName + " | Added song '" + songIdentifier + "' to playlist '" + playlistName + "'. Songs in playlist: " + playlist.songIdentifiers.size());
          jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Song '%s' successfully added to playlist '%s'.\"}", escapeJsonString(songIdentifier), escapeJsonString(playlistName));
         }
        }
       }
      } else {
       jsonResponse = "{\"status\":\"error\",\"message\":\"Playlist name or song identifier is missing.\"}";
      }
     } else if ("play_song".equalsIgnoreCase(action)) {
      String songIdentifier = getJsonValue(clientMessage, "song_identifier");
      // در برنامه واقعی، اینجا فایل آهنگ پیدا شده و برای ارسال آماده می شود.
      System.out.println(currentThreadName + " | Simulating play for song: " + songIdentifier);
      jsonResponse = String.format("{\"status\":\"success\",\"message\":\"Now playing '%s' (simulated).\"}", escapeJsonString(songIdentifier));
     }
     else { // اگر action شناخته شده نبود
      jsonResponse = String.format("{\"status\":\"error\",\"message\":\"Unknown action received: %s\"}", escapeJsonString(action));
     }

     writer.println(jsonResponse); // ارسال پاسخ به کلاینت
     System.out.println(currentThreadName + " | Sent to client ("+ clientSocket.getInetAddress().getHostAddress() +"): " + jsonResponse);
    }
   } catch (IOException e) {
    // اگر کلاینت به طور ناگهانی قطع شود یا مشکلی در شبکه پیش آید
    System.err.println(Thread.currentThread().getName() + " | IOException in ClientHandler for " + clientSocket.getInetAddress().getHostAddress() + ": " + e.getMessage());
   } catch (Exception e) { // برای گرفتن خطاهای پیش بینی نشده دیگر (مثلاً در پردازش JSON دستی)
    System.err.println(Thread.currentThread().getName() + " | Unexpected error in ClientHandler for " + clientSocket.getInetAddress().getHostAddress() + ": " + e.getMessage());
    e.printStackTrace();
    // تلاش برای ارسال یک پیام خطای عمومی به کلاینت در صورت امکان
    try {
     if (!clientSocket.isOutputShutdown()) { // فقط اگر بتوان به سوکت نوشت
      PrintWriter errorWriter = new PrintWriter(clientSocket.getOutputStream(), true);
      errorWriter.println("{\"status\":\"error\",\"message\":\"An internal server error occurred while processing your request.\"}");
     }
    } catch (IOException ex) {
     System.err.println(Thread.currentThread().getName() + " | Could not send final error message to client: " + ex.getMessage());
    }
   }
   finally {
    try {
     clientSocket.close(); // اطمینان از بسته شدن سوکت کلاینت
    } catch (IOException e) {
     System.err.println(Thread.currentThread().getName() + " | Exception while closing client socket: " + e.getMessage());
    }
    System.out.println(Thread.currentThread().getName() + " | Client disconnected: " + clientSocket.getInetAddress().getHostAddress() + ":" + clientSocket.getPort());
   }
  }
 }
}