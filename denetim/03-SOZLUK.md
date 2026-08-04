# 03 — SÖZLÜK / TERMİNOLOJİ KİLİDİ

Cookrange · 4 Ağustos 2026 · **Bağlayıcı referans**

Bundan sonra uygulama ekran metni, site metni ve pazarlama metni yazılırken kanonik ad ve kanonik rakam buradan alınır. Bir terimin karşısındaki "kullanılmayacak" listesi yasaktır — o ifade metne girerse denetim bulgusu üretmiş olur.

**Nasıl okunur**
- **Kanonik rakam** sütunundaki değer, kod kanıtıyla doğrulanmış tek doğru değerdir. `XX` = değer bilinmiyor, uydurulmayacak.
- **Durum** sütunu özelliğin bugünkü gerçeğidir. `YOK` işaretli terimler **hiçbir yüzeyde kullanılmaz** — özellik yapılana kadar.

---

## 1. PLAN VE ÜRETİM

### Haftalık plan · Weekly plan
**Tanım:** Haftanın 28 öğününü tek seferde üreten, vücut verine ve hedefine göre hesaplanan öğün listesi.
**Kanonik rakam:** 7 gün × 4 öğün = **28 öğün** · yemek havuzu **75 yemek** · hatırlatma bildirimi **pazartesi 07:00 UTC** (üst sınır 500 kullanıcı)
**Kanıt:** `lib/core/data/dish_data.dart` (75) · `functions/index.js:997` (bildirim) · `lib/core/services/weekly_meal_plan_service.dart:67`
**Durum:** TAM VAR (üretim istemcide, talep üzerine)
**Kullanılmayacak:** "pazar günü yazıldı" · "otomatik olarak üretilir" (kullanıcı tetikler) · "akıllı plan" · "kişiye özel diyet" · "diyet listesi"

### Kalori ve makro hedefi · Calorie and macro target
**Tanım:** Boy, kilo, yaş, cinsiyet ve aktivite düzeyinden Mifflin-St Jeor formülüyle hesaplanan günlük hedef.
**Kanonik rakam:** **5 aktivite çarpanı** · hedefe göre sabit **±500 kcal**
**Kanıt:** `lib/core/utils/calorie_calculator.dart:3-40`, `:48-55`
**Durum:** TAM VAR
**Kullanılmayacak:** "bilimsel olarak kanıtlanmış" · "klinik" · "diyetisyen hesabı"
**Uyarı:** Veri eksikse sistem sessizce 170 cm / 70 kg / 30 yaş / erkek varsayıyor (`weekly_meal_plan_service.dart:301-304`). "Kişiselleştirilmiş" iddiası bu durumda karşılanmıyor — TODO.

### Alerjen filtresi · Allergen filter
**Tanım:** Profilindeki alerjenleri taşıyan yemekleri, plan üretilmeden önce havuzdan çıkaran deterministik filtre.
**Kanonik rakam:** **12 alerjen anahtarı ≈ 8 ayrı alerjen grubu** (`dairy`/`lactose`, `nuts`/`peanut`/`tree_nuts`, `egg`/`eggs` örtüşüyor; kesin grup sayısı anahtarlar tekilleştirilmeden verilmez)
**Kanıt:** `lib/core/utils/allergen_safety.dart:3-16,21` · `weekly_meal_plan_service.dart:90-104` (havuz boşsa üretmeyi reddediyor)
**Durum:** TAM VAR — **kod iddiadan güçlü**
**Kullanılmayacak:** "12 alerjen" (şişirme) · "8 alerjen" (tekilleştirme doğrulanmadı) · "garanti" · "alerjensiz"
**Kullanılabilir yeni ifade (K3):** "Havuzda güvenli yemek kalmazsa plan üretilmez."

### Uyum motoru · Adaptation engine
**Tanım:** Gün içindeki gerçek aktiviteye göre kalan öğünleri yeniden hesaplayan mekanizma.
**Kanonik rakam:** —
**Kanıt (yokluk kanıtı):** `lib/screens/home/home.dart:1179-1198` (yakılan kalori yalnızca gösteriliyor) · `weekly_meal_plan_service.dart:316-321` (yeniden üretim hash'inde kilo, aktivite, tüketim yok)
**Durum:** **YOK**
**Kullanılmayacak — özellik yapılana kadar tamamı yasak:** "gün içinde kendini güncelleyen" · "plan bunu zaten biliyor" · "sıfırlamak yerine uyum sağlayan" · "adaptif beslenme planı" · "adapts instead of resetting" · "updates itself during the day"
**Not:** Bu, markanın çekirdek karşıtlığı. Terim yasağı geçicidir; özellik geldiğinde kanonik ad **"uyum motoru" / "adaptation engine"** olur ("adaptif" TR'de kullanılmaz — `docs/TONE-OF-VOICE.md:39`).

### Öğün değiştirme · Meal swap
**Tanım:** Plandaki bir öğünü havuzdaki başka bir yemekle değiştirme.
**Kanonik rakam:** XX (alternatif sayısı sabit değil)
**Kanıt:** `weekly_meal_plan_service.dart:222`, `:363`
**Durum:** KISMEN VAR — **hatalı:** değiştirme sonrası `total_calories` ve `macros` güncellenmiyor (`:259-277`)
**Kullanılmayacak:** "2 kayısı ve 10 badem de aynı işi görür" tipi **malzeme ikamesi** (yok) · "alternatif öneriler"

---

## 2. KAYIT

### Öğün kaydı · Meal logging
**Tanım:** Yediğin bir şeyi güne işleme eylemi.
**Kanonik rakam:** **5 kayıt yolu** — plandan · hızlı ekle · barkod · fotoğraf analizi · tarif üretimi. Bunlardan **tarif üretimi günlük yapay zekâ kotasından düşer**.
**Kanıt:** `lib/screens/home/home.dart:1505` → `lib/core/services/food_log_service.dart:30` · `explore_screen.dart:59-67` (kota)
**Durum:** TAM VAR
**Kullanılmayacak:** "sınırsız öğün kaydı" (yalnızca barkod ve hızlı ekle için doğru)
**DOĞRULANAMADI:** Fotoğraf analizinin kotaya bağlı olup olmadığı. Doğrulamak için: `analyzeFoodPhoto` çağrısının `functions/index.js:83-120` `recordUsage`/kota kontrolünden geçip geçmediği.

### Hızlı ekle · Quick add
**Tanım:** Son ve en sık kaydettiğin öğünlerden tek dokunuşla kayıt.
**Kanonik rakam:** son **10** · en sık **10**
**Kanıt:** `lib/core/services/recent_food_service.dart:70`, `:86`
**Durum:** TAM VAR

### Barkodla besin kaydı · Barcode food logging
**Tanım:** Ürünün barkodunu okutup kalori ve makro bilgisini **Open Food Facts** veritabanından çeken kayıt yolu.
**Kanonik rakam:** kaynak **Open Food Facts (küresel)** · zaman aşımı 10 sn · **tarama süresi XX** (ölçüm yok)
**Kanıt:** `lib/core/services/barcode_lookup_service.dart:45-46`, `:60` · `firestore.rules` içinde `products` koleksiyonu yok
**Durum:** KISMEN VAR (okuma çalışıyor, yerel veritabanı yok)
**Kullanılmayacak:** **"Türkiye barkod veritabanı"** · "Türkiye'ye özel veritabanı" · "a database specific to Turkey" · **"2,4 saniye"** / "~2,4 saniye" / "ortalama 2,4 saniye" / "3 saniyeden kısa" · "uluslararası veritabanlarından çok daha doğru tanınır"
**Not:** Bu, sitede 20+ dosyada geçen tek yanlış iddia kümesi. Rakip karşılaştırması MyFitnessPal'ı "küresel, kullanıcı katkılı" diye kötülerken Cookrange tam onu kullanıyor.

### Fotoğraftan öğün analizi · Photo meal analysis
**Tanım:** Yemeğin fotoğrafını çekip kalori, makro ve alerjen tahminini alma.
**Kanonik rakam:** **4 makro + 7 zenginleştirilmiş alan** (lif, şeker, sodyum, sağlık puanı, alerjen, güven skoru, gram)
**Kanıt:** `lib/core/services/ai_service.dart` `analyzeFoodPhoto`
**Durum:** TAM VAR — sitede yeterince anlatılmıyor (TİP B)
**Not:** Yurt dışı aktarım bilgilendirmesi mevcut ✅

### Tarif üretimi · Recipe generation
**Tanım:** Yazdığın malzemeden yapay zekânın yeni tarif üretmesi.
**Kanonik rakam:** her üretim **1 yapay zekâ kredisi** · hedef kalori sabit **500 kcal**
**Kanıt:** `lib/screens/explore/explore_screen.dart:59-67`, `:77`
**Durum:** TAM VAR
**Kanonik ad değişikliği:** ~~"tarif arama"~~ → **"tarif üretimi" / "recipe generation"**
**Kullanılmayacak:** "tarif arama" · "recipe search" · "recipe database"
**Gerekçe (K4):** Kullanıcı "arama" duyduğunda var olan bir tarif kataloğunda gezineceğini sanıyor. Ürün yeni tarif uyduruyor ve bunun için kota harcıyor. 75 yemeklik havuzda metin araması yok.

### Yapay zekâ sohbeti · AI chat
**Tanım:** Profil bağlamını bilen yapay zekâya beslenme ve antrenman sorusu sorma; yazıyla ya da sesle.
**Kanonik rakam:** ücretsiz **günde 2** · Premium **günde 20** · geçmiş kalıcı değil
**Kanıt:** `lib/core/services/ai_chat_service.dart:29-57` · `lib/core/widgets/voice_assistant_overlay.dart` · `functions/index.js:30-31` (sunucu) · `lib/core/models/ai_credit_model.dart:10-11` (kullanıcıya gösterilen)
**Durum:** TAM VAR — **sitede hiç anılmıyor** (TİP B, kaybedilen değer)

---

## 3. VERİ VE İLERLEME

### İlerleme geçmişi · Progress history
**Tanım:** Boşluklar silinmeden korunan günlük kayıt geçmişi.
**Kanonik rakam:** Sunucuda tutulan: **kalori + 4 makro + egzersiz kalorisi + seri**. Yalnızca cihazda tutulan: **günlük kilo ve su serisi**. *(İstisna: onboarding'de bir kez girilen kilo `private/nutrition` altına yazılıyor — `onboarding_provider.dart:241`.)*
**Kanıt:** `lib/core/services/food_log_service.dart:248-251` (boşluklar boş listeyle korunuyor) · `lib/core/services/storage_service.dart:20` (Hive `weight_box`)
**Durum:** KISMEN VAR
**Kullanılmayacak:** "sınırsız" (kayıt silinebilir: `firestore.rules:163-165`) · "hiçbir ay silinmiyor" · **"squat 60 kilodan 92,5 kiloya"** (ağırlık metriği yok) · "kaldırılan ağırlık takibi"
**Uyarı:** Kilo geçmişi sunucuda olmadığı için telefon değişince kayboluyor. Kalıcılık vaadi verilemez.

### Projeksiyon · Projection
**Tanım:** 30, 60 ve 90 gün için yapay zekânın yazdığı tahmin metni.
**Kanonik rakam:** **3 ufuk (30/60/90 gün)** · çıktı biçimi **metin**
**Kanıt:** `lib/core/services/ai_insight_service.dart:212-214`
**Durum:** KISMEN VAR — **grafik yok**
**Kullanılmayacak:** "kesikli çizgi" · "dashed line" · "grafik" · "+30 günde 76,9 kg" ve benzeri somut kilo değerleri
**Korunacak kanonik ifade (sitenin en doğru cümlesi, birebir kullanılır):** "Bu bir tahmin, bir garanti değil." / "a projection and not a promise" — türev formüller ("Tahmin bir söz değil" vb.) bu ifadeyi ikame etmez

### Seri · Streak
**Tanım:** Uygulamaya art arda girdiğin gün sayısı.
**Kanonik rakam:** **1 dondurma jetonu** (hediye) · kilometre taşları **7 / 14 / 30 / 60 / 100 / 365**
**Kanıt:** `lib/core/services/firestore_service.dart:180-191`
**Durum:** TAM VAR — ama **giriş tabanlı, kayıt tabanlı değil**
**Kullanılmayacak (düzeltilene kadar):** "art arda kayıt tutulan gün sayısı" · "logging streak" · "kayıt serisi"
**Karar gerekli:** Seri kayıt tabanına çevrilecek mi, yoksa tanım mı düzeltilecek? Ürün kararı — 04 numaralı dosyada SONRA kovasında.

---

## 4. TOPLULUK

### Squad · Squad
**Tanım:** Arkadaşlarının serilerini yan yana gördüğün grup.
**Kanonik rakam:** **üye sınırı yok** · davet kodu **6 karakter** · hedef **7 gün** · **ortak seri yok**
**Kanıt:** `lib/core/services/streak_squad_service.dart:24-30` (6 = kod uzunluğu), `:82-113` (üye kontrolü yok), `:105` (`arrayUnion` sınırsız), `:171-187` (her üyenin kendi serisi)
**Durum:** KISMEN VAR · **katılma yolu DOĞRULANAMADI:** `firestore.rules:642-652` `squads` bloğu okuma/güncelleme için üyelik istiyor, `joinSquad` henüz üye olmayan kullanıcıyla sorgu yapıyor → statik analizde permission-denied beklenir; `inviteCode` indeksi de yok. Çalışma zamanı testi yapılmadı (07 numaralı dosya D13)
**Kullanılmayacak:** **"altı kişi"** / "six-person" / "altı sütun" · **"tek bir seri"** / "one streak" / "aynı seriyi paylaşan"
**Not:** Yayınlanmış v0.9.6 sürüm notu (`src/content/changelog/tr/v0-9-6.md`) bu yanlış bilgiyi taşıyor. Satır silinmez, düzeltme notu eklenir.

### Salon savaşları · Gym wars
**Tanım:** İki salonun belirli bir süre boyunca check-in sayısıyla yarıştığı meydan okuma.
**Kanonik rakam:** varsayılan süre **7 gün** · metrik **check-in sayısı** · otomatik bitiş **yok**
**Kanıt:** `lib/core/services/gym_leaderboard_service.dart:98-104` · `lib/screens/gym/gym_leaderboard_screen.dart:120-132, 623-830`
**Durum:** TAM VAR — uygulamada yanlışlıkla **"YAKINDA GELECEK"** etiketli (`gym.feature_challenges`), sitede hiç anılmıyor, dokümanda "effectively unbuilt" yazıyor
**Kullanılmayacak:** "yakında" · "coming soon"

### Karşılıklı arkadaşlık · Mutual friendship
**Tanım:** İki tarafın da onayladığı, sunucu tarafında doğrulanan arkadaşlık.
**Kanonik rakam:** sorgu kırpması **30** (sessiz)
**Kanıt:** `lib/core/services/friend_service.dart:16-20` (Cloud Functions callable, istemci yazma kapalı)
**Durum:** TAM VAR ✅
**Uyarı:** `whereIn` 30 sınırı sessizce kırpıyor — 30'dan fazla arkadaşta liste eksik görünür. TODO.

### Topluluk akışı · Community feed
**Tanım:** Öğün, antrenman ve ilerleme gönderilerinin paylaşıldığı, yorum ve tepki alan akış.
**Kanonik rakam:** **4 gönderi tipi** · öğün gönderisinde **4 makro alanı** · `community.*` **67 localization anahtarı**
**Kanıt:** `lib/screens/community/widgets/create_post_card.dart:745-753` · `lib/core/services/community_service.dart:102-110`
**Durum:** TAM VAR — **sitede hiç anılmıyor** (TİP B)
**Kullanılmayacak:** "üç kapsam: salon, ilçe, şehir" (kapsam enum'u yok)

### Paylaş ve kaydet · Share and log
**Tanım:** Pişirme modunu bitirdiğinde tek onayla hem kaydın oluşur hem gönderi paylaşılır.
**Kanonik rakam:** **1 dokunuş** · ters yön (gönderiden kayda) **yok**
**Kanıt:** `lib/screens/recipe/cooking_mode_screen.dart:489-538` (`shouldShare` → `logRecipe` + `createPost`)
**Durum:** TAM VAR (tek yön)

---

## 5. SALON VE KOÇ

### Salon check-in · Gym check-in
**Tanım:** QR okutarak ya da salonun yakınında GPS ile salona giriş kaydı.
**Kanonik rakam:** GPS yarıçapı **100 m** · QR jetonu **32 karakter / 24 saat**
**Kanıt:** `lib/core/models/gym_model.dart:63`, `:93` · `lib/core/services/gym_service.dart:369-380`, `:403-418`
**Durum:** TAM VAR
**Kullanılmayacak:** "otomatik check-in" · "geofence" (yok — elle tetikleniyor)
**Uyarı:** Yarıçap yalnızca istemcide doğrulanıyor (`firestore.rules:471-472` yalnızca uid eşleşmesi arıyor) → salona satılan "doğrulama" sahtelenebilir. Bkz. 06 numaralı dosya R14.

### Salon paneli · Gym dashboard
**Tanım:** Salonun kendi üye listesini, check-in geçmişini ve yoğun saat desenini gördüğü ekran.
**Kanonik rakam:** yoğun saat penceresi **60 gün** · **4 zaman dilimi** (06-12 / 12-18 / 18-22 / 22-05) · ısı haritası **7×4 = 28 hücre** · üye listesi sayfası **20**
**Kanıt:** `lib/core/services/gym_analytics_service.dart:18-23`, `:77-86` · `gym_service.dart:174`
**Durum:** KISMEN VAR
**Kullanılmayacak:** **"doluluk"** / "occupancy" / "doluluk görünürlüğü" / "anlık doluluk" · "gelir paneli" · "kadro paneli"
**Gerekçe:** `occupancy|capacity|doluluk` → `lib/` genelinde 0 eşleşme; check-out kaydı yok, dolayısıyla "içeride kaç kişi var" hesaplanamaz.

### Yoğun saat deseni · Peak-hour pattern
**Tanım:** Son 60 günün check-in dağılımını gün × zaman dilimi ısı haritası olarak gösteren görünüm.
**Kanonik rakam:** 60 gün · 28 hücre
**Durum:** TAM VAR ✅ — kanonik adı bu; "doluluk" değil

### Liderlik tablosu · Leaderboard
**Tanım:** Check-in sayısına göre canlı sıralama.
**Kanonik rakam:** salon **200** üye tavanı · global **50** · arkadaş **30** · salon içi haftalık, pazartesi 00:00 yerel saat
**Kanıt:** `lib/core/services/gym_leaderboard_service.dart:32-38` · `leaderboard_service.dart:38-44`, `:63-64` · `gym_service.dart:337`
**Durum:** TAM VAR ✅
**Kullanılmayacak:** "tüm üyeler" (200 tavanı var)

### Danışan listesi · Client list
**Tanım:** Koçun kendi danışanlarını ve ilerlemelerini gördüğü liste.
**Kanonik rakam:** rapora giren alan **3** · izin adımı **0**
**Kanıt:** `lib/screens/coach/coach_client_detail_screen.dart:100-152`
**Durum:** SADECE ARAYÜZ VAR (rıza kontrolü yok — ACİL, bkz. 06 numaralı dosya R3)
**Kanonik ad değişikliği:** ~~"kadro" / "roster"~~ → **"danışan listesi" / "client list"**
**Gerekçe (K4):** "Kadro"/"roster" salon personeli panelini çağırıyor; o panel yok (`staff|kadro|personel` → 0 eşleşme).

### Program pazarı · Program marketplace
**Tanım:** Koçların hazırladığı antrenman ve beslenme programlarının listelendiği alan.
**Kanonik rakam:** ücretli program **0** (arayüzde "yakında" banner'ı) · gerçek içerik **3 demo program**
**Kanıt:** `lib/screens/programs/program_detail_screen.dart:513-514` · `lib/core/services/app_initialization_service.dart:335`
**Durum:** KISMEN VAR
**Kullanılmayacak:** "pazaryeri" tek başına (satın alma yok) · "koçlar plan hazırlar" (`createProgram` için 0 çağrı yeri)
**Uyarı:** Pazaryerindeki tek içerik her istemcinin açılışta yazdığı 3 demo program. Bu, gerçek olmayan içeriktir.

### Salon kodu · Gym code
**Tanım:** Bir üyenin hangi salon üzerinden kaydolduğunu belirleyen atıf kodu.
**Kanonik rakam:** — (özellik yok)
**Durum:** **YOK** — `gym_model.dart:22-43` 22 alan, kod alanı yok; `gym_code` → 0 eşleşme
**Kullanılmayacak:** "salona özel kod" · "kodla kayıt" · "salona gelir" (gelir modeli yok: `TODO.md:2496` GYM-07, "Files: none")
**Var olan ilgili şey:** referans kazancı **kişi/koç başına ₺5** (`functions/economy.js:21`) — bu salon geliri değil, kullanıcı referansı

---

## 6. İŞ MODELİ

### Ücretsiz katman · Free tier
**Tanım:** Kaydın, planın, topluluğun ve salon katmanının kilitsiz çalıştığı varsayılan katman.
**Kanonik rakam:** **günde 2 yapay zekâ üretimi** · **12 istek/dakika** · fiyat **₺0**
**Kanıt:** `functions/index.js:30-31` (sunucu otoritesi, fail-closed `:21-27`) · `lib/core/models/ai_credit_model.dart:10-11` (kullanıcıya gösterilen değer — sunucuyla birebir uyumlu ✅)
**Durum:** KISMEN VAR — `Entitlements`'ın 8 kapısı hiç çağrılmıyor (`FeatureGateService().check()` → 0 çağrı yeri; aynı servisin `showPaywall()` yarısı 3 yerden çağrılıyor)
**Kullanılmayacak:** "sınırsız öğün kaydı (… tarif arama)" · "doluluk görünürlüğü" · "her zaman ücretsiz kalacak" (süresiz taahhüt — hukuki bağ)
**Not — ölü yapılandırma:** `app_config_model.dart:71-72` (5/50) ve `subscription_model.dart:47-51` (10/50) hiçbir yerden okunmuyor. Kullanıcıya gösterilecek değer 2/20'dir; uzaktan yapılandırma bu ölü alanlar üzerinden değiştirilirse hiçbir etki görülmez.

### Premium
**Tanım:** Yapay zekâ üretim hakkını artıran ücretli katman.
**Kanonik ad (EN):** Premium
**Kanonik rakam:** **günde 20 yapay zekâ üretimi** · fiyat **belirlenmedi (XX)**
**Kanıt:** `functions/index.js:30-31` · `lib/core/models/ai_credit_model.dart:11`
**Durum:** KISMEN VAR (uygulanan tek fark kota)
**Kullanılmayacak — beşi de yanlış:** "Sınırsız Plan" · "Reklamsız deneyim" (uygulamada reklam SDK'sı yok) · "Öncelikli AI işleme" (rate limit aynı) · "Gelişmiş öğün özelleştirme" (yok) · "Detaylı beslenme analitiği" (ücretsizde var)
**Kullanılabilir (sitenin dili, K2):** "daha sık yeniden planlama" · "daha detaylı gerekçelendirme"

### Sponsorlu ürün · Sponsored product
**Tanım:** Marka ortağının ürününün öneri olarak gösterilmesi.
**Kanonik rakam:** — (özellik yok)
**Durum:** **YOK** — `sponsor`, `sponsored`, `sponsorlu`, `brand_partner`, `promoted`, `ad_slot` → `lib/`, `functions/`, `assets/`, `test/`, `firestore.rules` genelinde 0 eşleşme (~115k satır). Tek iz: `docs/roadmap/FUTURE_FEATURES.md:126,150-151` — gelecek işi olarak sınıflanmış
**Kullanılmayacak — kavramın tamamı:** "sponsorlu ürün" · "±%10 kalori, en az %90 protein" · "dokunulmamış planda sıfır sponsorlu öğe" · "marka susturma" · "indirim kodu" · "₺18 lor / ₺32 protein barı" · **"en az 1.000 hesaplık kohort"** · "ücretsiz katman şununla finanse edilir"
**Not:** Bu, ücretsiz katmanın beyan edilen finansman mekanizmasıydı. Kaldırıldığında iş modeli beyanı boşta kalıyor — ürün kararı gerekli.

---

## 7. MAHREMİYET

### Rıza Merkezi · Consent Center
**Tanım:** Her işleme amacını ayrı ayrı açıp kapattığın ekran.
**Kanonik rakam:** **7 amaç bazlı rıza** (`health_data`, `location`, `ai_processing`, `cross_border_transfer`, `analytics`, `notifications`, `marketing` — ilk 4 hassas) **+ 4 OS izni = 11 nokta** · politika sürümü `2026-06-29`
**Kanıt:** `lib/core/models/consent_model.dart:11-19` · `lib/screens/profile/consent_center_screen.dart:53`
**Durum:** KISMEN VAR — **geri çekme yalnızca `analytics` için gerçekten çalışıyor** (`consent_service.dart:73-92`)
**Kullanılmayacak (düzeltilene kadar):** "istediğin an kapatabilirsin" · "kapattığında durur" · "verildiği kadar kolay geri çekilir" · "İzni reddedersen aynen çalışmaya devam eder"

### Konum · Location
**Tanım:** Yakınındaki salonu ve koçu sıralamak için cihazda hesaplanan, sunucuya gönderilmeyen konum.
**Kanonik rakam:** koordinat sunucuda **saklanmıyor** ✅
**Kanıt:** `lib/core/models/checkin_model.dart:52-58` (lat/lon alanı yok) · `gym_service.dart:405-416` (mesafe istemcide) · `gym_analytics_service.dart:37-47` (yalnızca zaman damgası)
**Durum:** TAM VAR ✅ — **denetimde site ile kodun en net örtüştüğü yer**
**Kanonik ifade:** "Yakınındaki salon ve koç sıralaması cihazında hesaplanır; koordinat sunucuya gönderilmez ya da kaydedilmez."
**Kullanılmayacak:** "yakınımdaki arkadaş sıralaması" (`nearbyFriends` → 0 eşleşme; böyle bir özellik yok)

### Salon veri sınırı · Gym data boundary
**Tanım:** Salon işletmesinin üye verisine erişim kapsamı.
**Kanonik rakam:** CSV alanı **6** (`uid,name,joined_at,total_checkins,last_checkin,tier`) · salon üye modeli **5 alan**
**Durum:** KISMEN VAR — vücut verisi korunuyor ✅, bireysel devam verisi görünüyor
**Kanonik ifade:** "Salon işletmesi üye listesini ve check-in kayıtlarını **görünen ad düzeyinde** görür, devam istatistiklerini dosya olarak indirebilir. Beslenme geçmişine, kilo verine ve ölçümlerine erişemez."
**Kanıt:** `firestore.rules:426-429`, `:467-470` (salon okuması) · `:207-211` (vücut verisi owner-only) · `gym_analytics_service.dart:137-170` (CSV: `uid,name,joined_at,total_checkins,last_checkin,tier`)
**Kullanılmayacak:** "yalnızca toplam veri görür" · "bireysel kullanıcı verisine erişimleri yoktur" · "Erişemez." (tek başına)

### Yapay zekâ işleme ve yurt dışı aktarım · AI processing and cross-border transfer
**Tanım:** İstem metninin ve profil bağlamının yurt dışındaki yapay zekâ sağlayıcısında işlenmesi.
**Kanonik rakam:** sağlayıcı **1** (OpenRouter) · sitenin alt işleyici listesinde geçiş sayısı **0**
**Durum:** TAM VAR (işleme) · KISMEN VAR (aydınlatma)
**Kanonik ifade:** "Yapay zekâ çıkarımı için OpenRouter kullanıyoruz; istem metnin ve profil bağlamın bu sağlayıcıya gider ve yurt dışında işlenir."
**Kanıt:** `assets/legal/kvkk_aydinlatma_tr.md:46` · `privacy_policy_tr.md:74`, `:98` · `docs/COMPLIANCE.md:186`
**Uyarı:** Sitenin alt işleyici listesinde OpenRouter **yok** (`src/pages/legal/alt-islemciler.astro:59-88` → yalnızca Vercel, Firebase, GA/GTM, Clarity; `grep OpenRouter src/` → 0). Apple/Google Play ve OpenStreetMap da yok.

---

## 8. ÜRÜN VE MARKA

### Cookrange AI
**Tanım:** Plan üretimi, besin analizi, tarif üretimi, sohbet ve içgörüden sorumlu yapay zekâ katmanı.
**Kanonik ad:** **Cookrange AI** (TR ve EN aynı)
**Kanonik rakam:** günlük kota ücretsiz **2** / Premium **20**
**Durum:** TAM VAR
**Kullanılmayacak:** "yapay zeka beslenme koçu" (yalnızca URL'de kalır: `/ozellikler/yapay-zeka-koc`) · "adapt katmanı" · "AI koç" · "sanal diyetisyen"

### v0.9.6 dahili alfa · v0.9.6 internal alpha
**Tanım:** Ürünün bugünkü olgunluk aşaması: mağazada değil, bekleme listesinden erişim veriliyor.
**Kanonik rakam:** sürüm **v0.9.6** · mağaza kaydı **0**
**Durum:** TAM VAR (aşama beyanı) — `pubspec.yaml:4` hâlâ `1.0.0+1` taşıyor
**Kanonik ad:** **"v0.9.6 dahili alfa" / "v0.9.6 internal alpha"** — tek geçerli aşama adı
**Kanıt:** `README.md:17` · `PROJECT_STATE.md:15`
**Kullanılmayacak — beşi de yasak:** "beta öncesi" / "pre-beta" · **"özel beta" / "private beta"** (şu an 16 yerde geçiyor, en sık kullanılan yanlış ad) · "kapalı beta" / "closed beta" · "bekleme listesi aşaması" · "özel erken erişim" / "private early-access"
**Uyarı:** `pubspec.yaml:4` = `1.0.0+1` — güncellenmemiş şablon değeri, düzeltilmeli.

### Bekleme listesi · Waitlist
**Tanım:** Lansman öncesi erişim sırası.
**Kanonik rakam:** kayıtlı kişi sayısı **XX** (yayınlanmıyor; `docs/LAUNCH-CHECKLIST.md:66-68` formun canlıda çalıştığının doğrulanmadığını not ediyor)
**Durum:** DOĞRULANAMADI
**Kullanılmayacak:** "wishlist" (`docs/TONE-OF-VOICE.md:35` yasaklıyor, ama `hakkimizda.astro:47` route anahtarı olarak kullanıyor — 18 yerde)

### Gün sütunu · Data column
**Tanım:** Bir kullanıcının bir gününü oluşturan öğün, antrenman, check-in ve seri verisinin bütünü. Markanın çekirdek metaforu.
**Kanonik rakam:** — (metafor; sayısal değer taşımaz)
**Durum:** TAM VAR (kavram)
**Kullanılmayacak:** **"12.400 sütun" / "12,400 columns"** — kaynağı yok, tanımı yok, sıfır kullanıcılı üründe kullanıcı sayısı gibi okunuyor (`hero-data.ts:699`)

### Salon ekosistemi · Gym ecosystem
**Tanım:** Salon, üye ve koçun aynı veri zemininde buluştuğu katman.
**Kanonik rakam:** salon ekranı **13** · koç ekranı **8** · program ekranı **3**
**Durum:** KISMEN VAR (bkz. madde 19-32)
**Kanonik ad (TR):** **"Salon ekosistemi"**
**Kullanılmayacak (TR metinde):** "Gym ekosistemi" (5 yerde karışık kullanılıyor: `personas/tr/performans-sporculari.md:32`, `kocular.md:26`, `spor-salonlari.md:25`, `site-haritasi.astro:28`, `guvenlik.astro:33`)

### Platform
**Kanonik ad:** Platform desteği · Platform support
**Tanım:** Uygulamanın çalıştığı işletim sistemi sürümleri.
**Durum:** KISMEN VAR
**Kanonik rakam:** **iOS 14+** ✅ doğrulandı · **Android: XX** — `android/app/build.gradle:79` `minSdkVersion flutter.minSdkVersion`, repoda sabit yok
**Kullanılmayacak:** "Android 8 ve üzeri" — doğrulanamıyor, gerçek zemin büyük olasılıkla daha düşük. `minSdkVersion 26` yazılana kadar bu rakam verilmez.
**Kullanılmayacak:** mağaza linki ya da "indir" çağrısı — `constants.ts:9-10` `APP_STORE_URL = null`, `GOOGLE_PLAY_URL = null` ✅ (site şu an bunu doğru yapıyor)

---

## 9. YENİ ÖNERİLER (K6)
> İkisi de zayıf olduğu için yeni yazıldı. **Sessizce yerleştirilmedi — bunlar öneridir, onay bekler.**

| # | Bağlam | YENİ ÖNERİ (TR) | YENİ ÖNERİ (EN) |
|---|---|---|---|
| Y1 | Barkod, rakam olmadan | "Barkodu okut, ürün gelir. Kalori ve makro kaydına düşer." | "Scan the barcode. Calories and macros land in your log." |
| Y2 | Market listesi | "Haftanın 28 öğünündeki malzemeler tek listede toplanır. Aldıkça işaretlersin." | "The ingredients from the week's 28 meals collect into one list. You check them off as you shop." |
| Y3 | Squad | "Squad, arkadaşlarının serilerini yan yana gördüğün grup. Birinin sütunu düzleşirse diğerleri fark eder." | "A squad is where you see your friends' streaks side by side. If one column flattens, the others notice." |
| Y4 | Salon paneli (ikinci çoğul) | "Salonunuz kendi check-in sayısını ve son 60 günün yoğun saat desenini görür." | "Your gym sees its own check-in count and the peak-hour pattern of the last 60 days." |
| Y5 | Alerjen | "Profiline alerjen girersen o yemekler havuzdan çıkar. Havuzda güvenli yemek kalmazsa plan üretilmez." | "Allergens in your profile remove those dishes from the pool. If nothing safe is left, no plan is generated." |
| Y6 | Yerel yemek (75) | "Havuzda 75 Türk yemeği var. Menemen, etli pilav, köfte-bulgur — pişirdiğin şeyler." | "The pool holds 75 Turkish dishes. Menemen, rice with meat, köfte with bulgur — things you actually cook." |
| Y7 | Yapay zekâ sohbeti | "Aklına takılanı sorarsın. Yapay zekâ senin verini bilerek cevap verir; yazıyla ya da sesle." | "You ask what's on your mind. The AI answers knowing your data — by text or by voice." |
| Y8 | Uyum motoru yerine (geçici) | "Gün sonunda ne yediğin, ne kadar yürüdüğün ve seri durumun aynı ekranda durur." | "At the end of the day, what you ate, how far you walked and where your streak stands sit on one screen." |
| Y9 | Aşama | "Cookrange v0.9.6 dahili alfa aşamasında. Mağazada değil; bekleme listesinden erişim veriyoruz." | "Cookrange is at v0.9.6 internal alpha. Not in the stores; access goes out through the waitlist." |
| Y10 | Sponsorlu katman yerine | "Ücretsiz katmanı nasıl finanse edeceğimizi açıklarken kuralları da yayımlayacağız." | "When we explain how the free tier is funded, we will publish the rules with it." |

---

## 10. MARKA SESİ KURALLARI (bağlayıcı)
Kaynak: `docs/TONE-OF-VOICE.md` + bu denetimin eklediği iki kural.

1. İlk cümlede ana iddiayı söyle, arkasından bağlamı ver.
2. Somut sayı kullan; "hızlı", "kolay", "kapsamlı" gibi muğlak sıfat kullanma.
3. Ürünü üçüncü şahıs betimleyici dille anlat. **Pazarlama amaçlı birinci çoğul şahıs yasak**: "Biz size X sunuyoruz", "Nereden nereye gidiyoruz" (şu an 5 yerde ihlal ediliyor). *Kapsam istisnası: veri sorumlusu olarak taahhüt veren hukuki ve bilgilendirici metinlerde birinci çoğul kullanılır — "OpenRouter kullanıyoruz", "kuralları yayımlayacağız". Yasak, ürünü övmek için kullanılan birinci çoğulu kapsar.*
4. Tüketiciye **ikinci tekil** (sen). **Salon ve koça ikinci çoğul** (siz).
5. Ünlem ve emoji yok.
6. Kanıtlanamaz üstünlük iddiası yok: "devrim niteliğinde", "en iyi", "piyasadaki tek".
7. Sahte aciliyet yok, uydurma sosyal kanıt yok: kullanıcı sayısı, yıldız puanı, "binlerce kişi".
8. Tıbbi iddia yok: "kilo verdirir", "hastalığı önler", "hızlandırır", "garanti".
9. **YENİ — kanıt kuralı:** Metne giren her sayı kod, ölçüm ya da yayınlanmış kaynak ile gösterilebilir olmalı. Tasarım mock'undan gelen sayı metne girmez. *(Bu kuralın yokluğu "2,4 saniye", "34 ürün", "7 reyon", "12.400 sütun" ve "1.000 hesap" rakamlarının üretilme sebebi.)*
10. **YENİ — iddia değil mekanizma:** Bir özelliği anlatırken sonucu değil işleyişi yaz. "Daha iyi beslenirsin" değil, "alerjenler havuzdan çıkar, sonra plan üretilir".
