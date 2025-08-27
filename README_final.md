# 🎵 Flutter Music Player + Java Socket Server

یک اپلیکیشن **پخش‌کننده موسیقی** با فروشگاه آنلاین و پروفایل کاربری، ساخته شده با **Flutter (کلاینت)** و **Java (سرور سوکت)**.  
این README شامل توضیحات کامل، راه‌اندازی، و اسکرین‌شات‌های باکیفیت است تا برای ارائه و گرفتن «نمره زیبایی» آماده باشد ✨

---

## ✨ ویژگی‌ها

- 🎶 پخش موسیقی (Play/Pause/Next/Prev، Loop/Shuffle)
- 🛒 فروشگاه موسیقی: دسته‌بندی‌ها، لیست آهنگ‌ها، خرید/دانلود شبیه‌سازی‌شده
- ⭐ امتیازدهی و 💬 نظرات (به همراه لایک/دیس‌لایک)
- 👤 حساب کاربری: ورود/ثبت‌نام، تغییر پروفایل، کیف‌پول، اشتراک ویژه
- 📂 کتابخانه محلی (آهنگ‌های روی دستگاه) + علاقه‌مندی‌ها + دانلودها
- 📜 نمایش/ویرایش متن ترانه (Lyrics)
- 🌙 پشتیبانی از **تم تاریک و روشن**
- 🌐 تبلیغات درون‌برنامه‌ای (WebView)
- 🖧 ارتباط کلاینت و سرور از طریق **Socket + JSON**

---

## 🧱 معماری

```
Flutter Client
 ├─ UI (Home, Shop, Player, Profile, Lyrics, Auth)
 ├─ State: Provider (AppState, PlayerQueue, LibraryProvider)
 ├─ Data: 
 │   ├─ MockServer (برای تست آفلاین)
 │   └─ SocketClient + SocketServerProvider (ارتباط آنلاین)
 └─ Storage: SharedPreferences

Java Socket Server
 ├─ مدیریت کاربران، آهنگ‌ها، کامنت‌ها، امتیازدهی
 ├─ ذخیره‌سازی در فایل JSON (server-data.json)
 ├─ ارسال رویدادهای new_release برای کلاینت‌ها
 └─ پروتکل ساده: JSON تک‌خطی با reqId / action / event
```

---

## 🚀 راه‌اندازی

### سرور (Java)
1. مطمئن شوید **Java 11+** نصب است.  
2. کتابخانه **Gson** را دانلود کنید (`gson-2.10.1.jar`).  
3. کامپایل و اجرا:

```bash
javac -cp gson-2.10.1.jar SocketMusicServer.java
java -cp .:gson-2.10.1.jar SocketMusicServer
```

خروجی:  
```
Socket server listening on port 29168 ...
```

### کلاینت (Flutter)
1. Flutter 3.x نصب داشته باشید.  
2. دستورها:
```bash
flutter pub get
flutter run
```

### اتصال
- Emulator اندروید: `host = 10.0.2.2`, `port = 29168`  
- iOS Simulator: `host = 127.0.0.1`, `port = 29168`  
- دستگاه واقعی: IP سیستم خود در LAN را بگذارید.

---

## 🔌 پروتکل سوکت

- درخواست نمونه:
```json
{"reqId":"123","action":"login","data":{"userOrEmail":"demo","password":"123"}}
```
- پاسخ نمونه:
```json
{"reqId":"123","ok":true,"result":{"token":"...","user":{"id":"1","username":"demo"}}}
```
- رویداد (Broadcast):
```json
{"event":"new_release","song":{"title":"New Track"}}
```

### اکشن‌های پشتیبانی‌شده
- Auth: `signup`, `login`, `me`, `updateProfile`  
- Wallet/Subscription: `addCredit`, `subscription`  
- Songs: `categories`, `songs`, `purchase`, `rate`, `comments`, `addComment`, `likeComment`

---

## 📸 اسکرین‌شات‌ها

### کتابخانه و خانه
![Home](screenshots/home.png)

### فروشگاه و دسته‌بندی‌ها
![Shop](screenshots/shop.png)
![Categories](screenshots/categories.png)

### لیست آهنگ‌ها
![Songs List](screenshots/songs_list.png)

### جزئیات آهنگ + امتیازدهی + نظرات
![Song Detail](screenshots/song_detail.png)
![Rating & Comments](screenshots/rating_comments.png)

### پخش‌کننده موسیقی
![Player](screenshots/player.png)

### پروفایل (تم تاریک و روشن)
![Profile Dark](screenshots/profile_dark.png)
![Profile Light](screenshots/profile_light.png)

---

## 🧪 تست سریع (Demo Scenario)

1. اجرای سرور جاوا (پورت 29168).  
2. در اپ Flutter:
   - ثبت‌نام/ورود  
   - رفتن به فروشگاه → انتخاب دسته‌بندی → مشاهده آهنگ‌ها  
   - امتیازدهی، افزودن نظر، لایک/دیس‌لایک  
   - خرید/دانلود شبیه‌سازی‌شده  
3. تغییر تم (روشن/تاریک) در پروفایل.  
4. دریافت رویداد **new_release** به‌صورت اعلان/اسنک‌بار.

---

## 🧯 خطاهای رایج

- ❌ **اتصال برقرار نمی‌شود** → آدرس IP و پورت را بررسی کنید (`10.0.2.2` برای Emulator).  
- ❌ **مجوز دسترسی فایل/اینترنت** → `AndroidManifest.xml` و `Info.plist` را بررسی کنید.  
- ❌ **Token نامعتبر** → پس از login مقدار `token` را در کلاینت ذخیره کنید.

---

## ✅ چک‌لیست «نمره زیبایی»

- [x] توضیحات کامل پروژه  
- [x] دستورالعمل نصب و راه‌اندازی  
- [x] اسکرین‌شات‌های واضح از بخش‌های کلیدی  
- [x] توضیح پروتکل و اکشن‌های سوکت  
- [x] سناریوی تست End-to-End  
- [x] نکات رفع خطا  

---

## 📜 لایسنس
این پروژه برای اهداف آموزشی ساخته شده است. در صورت انتشار عمومی، یک مجوز متن‌باز (MIT/Apache-2.0/...) اضافه کنید.
