import java.util.*;
class Music{
    private String name;
    private String artist;
    private boolean isLocal;
    private boolean isDownloaded;
    Music(String name, String artist, boolean isLocal,boolean isDownloaded) {
        this.name = name;
        this.artist = artist;
        this.isLocal = isLocal;
        this.isDownloaded = isDownloaded;
    }
}