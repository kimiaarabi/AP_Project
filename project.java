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
    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }
    public String getArtist() {
        return artist;
    }
    public void setArtist(String artist) {
        this.artist = artist;
    }
    public boolean isLocal() {
        return isLocal;
    }
    public void setLocal(boolean local) {
        isLocal = local;
    }
    public boolean isDownloaded() {
        return isDownloaded;
    }
    public void setDownloaded(boolean downloaded) {
        this.isDownloaded = downloaded;
    }
}

class Category{
    private String name;
    private List<Music> musics;
    public Category(String name, List<Music> musics){
        this.name = name;
        this.musics = musics;
    }
    public Category(String name){
        this.name = name;
        this.musics = new ArrayList<>();
    }
}