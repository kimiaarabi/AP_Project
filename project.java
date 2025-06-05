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
    public String getName() {
        return name;
    }
    public void setName(String name) {
        this.name = name;
    }
    public List<Music> getMusics() {
        return musics;
    }
    public void setMusics(List<Music> musics) {
        this.musics = musics;
    }

    public void addMusic(Music music){
        this.musics.add(music);
    }
    public void removeMusic(Music music){
        this.musics.remove(music);
    }
}
class MusicLibrary{
    List<Music> allmusics;
    public MusicLibrary(){
        this.allmusics = new ArrayList<>();
    }
    public void addMusic(Music music){
        allmusics.add(music);
    }
    public void removeMusic(Music music){
        allmusics.remove(music);
    }
    public List<Music> getDownloadedMusics(){
        List<Music> downloaded = new ArrayList<>();
        for(Music music : allmusics){
            if(music.isDownloaded()){
                downloaded.add(music);
            }
        }
        return downloaded;
    }
    public List<Music> getLocalMusics(){
        List<Music> local = new ArrayList<>();
        for(Music music : allmusics){
            if(music.isLocal()){
                local.add(music);
            }
        }
        return local;
    }
    public List<Music> searchByName(String keyword){
        List<Music> musics1 = new ArrayList<>(allmusics);
        List<Music> result = new ArrayList<>();
        String lowerCaseKeyword = keyword.toLowerCase();
        for (Music music : musics1){
            String title = music.getName().toLowerCase();
            String artist = music.getArtist().toLowerCase();
            if(title.contains(lowerCaseKeyword) || artist.contains(lowerCaseKeyword)){
                result.add(music);
            }
        }
        return result;
    }
    public List<Music> sortByName(){
        List<Music> result = new ArrayList<>(allmusics);
        result.sort(Comparator.comparing(Music::getName));
        return result;
    }
    public List<Music> sortByArtist(){
        List<Music> result = new ArrayList<>(allmusics);
        result.sort(Comparator.comparing(Music::getArtist));
        return result;
    }

}

class User{
    private String name;
    private String email;
    private String password;
    private String subscriptionType;
    private String profileImagePath;
    private double credit;
    public User(String name, String email, String password){
        this.name = name;
        this.email = email;
        this.password = password;
        this.credit = 0;
        this.profileImagePath = "";
        this.subscriptionType = "Normal";
    }
    public String getName() {
        return name;
    }
    public String getEmail() {
        return email;
    }
    public String getPassword() {
        return password;
    }
    public String getSubscriptionType() {
        return subscriptionType;
    }
    public void setSubscriptionType(String subscriptionType) {
        if(subscriptionType.equals("Normal") || subscriptionType.equals("Premium")){
            this.subscriptionType = subscriptionType;
        }
    }
    public String getProfileImagePath() {
        return profileImagePath;
    }
    public void setProfileImagePath(String profileImagePath) {
        this.profileImagePath = profileImagePath;
    }
    public double getCredit() {
        return credit;
    }
    public void increaseCredit(double credit) {
        if(credit > 0){
            this.credit += credit;
        }
    }
    public void decreaseCredit(double amount) {
        if(amount > 0 && credit > amount){
            this.credit -= amount;
        }
    }
    public void deleteAccount() {
        this.name = "";
        this.email = "";
        this.profileImagePath = "";
        this.credit = 0;
        this.subscriptionType = "";
    }
    public boolean PasswordValidation(String password){
        if(password.length() < 8){
            return false ;
        }
        if(password.equals(this.name) ){
            return false ;
        }
        boolean hasUppercase = false;
        boolean hasLowercase = false;
        boolean hasDigit = false;
        for(char c : password.toCharArray()){
            if(Character.isUpperCase(c)){
                hasUppercase = true;
            }
            if(Character.isLowerCase(c)){
                hasLowercase = true;
            }
            if(Character.isDigit(c)){
                hasDigit = true;
            }
        }
        return hasUppercase && hasLowercase && hasDigit;
    }
    public void EditProfile(String name, String password){
        this.name = name;
        if(PasswordValidation(password)){
            this.password = password;
        }
    }

}

class PremiumSubscription{
    private int durationInMonths;
    private double price;
    public PremiumSubscription(int durationInMonths) {
        this.durationInMonths = durationInMonths;
        if(durationInMonths == 1){
            this.price = 100;
        }
        else if(durationInMonths == 3){
            this.price = 250;
        }
        else if(durationInMonths == 12){
            this.price = 900;
        }

    }
    public int getDurationInMonths() { return durationInMonths; }
    public double getPrice() { return price; }
}

class Payment{
    public static boolean processPayment(User user, PremiumSubscription sub, String cardNumber, String cardPass) {
        if (cardNumber.length() == 16 && cardPass.length() == 4) {
            user.decreaseCredit(sub.getPrice());
            return true;
        }
        return false;
    }
}

class UserDataBase{
    private static List<User> users = new ArrayList<>();
    public static void AddUser(User user){
        users.add(user);
    }
    public static User FindByEmail(String email){
        for(User user : users){
            if(user.getEmail().equals(email)){
                return user;
            }
        }
        return null;
    }
}