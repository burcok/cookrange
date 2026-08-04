# 02 — ÇAKIŞMA RAPORU

Cookrange üç kaynaklı doğruluk denetimi · 4 Ağustos 2026
Kaynaklar: `cookrange/` (uygulama, v0.9.6 dahili alfa) · `cookrange-landing/` (site) · `cookrange-landing/docs/` + basın kiti + personalar + blog (pazarlama)

**Karar kuralları:** K1 ürün gerçeği kazanır · K2 kapsam uygulamadan ifade siteden · K3 somut soyutu yener · K4 kullanıcı dili jargonu yener · K5 marka sesine uyan kazanır · K6 ikisi de zayıfsa YENİ ÖNERİ · K7 uygulanmayan iddia kaldırılır, yol haritasına girer

**Denetlenen: 60 özellik maddesi** (kontrol listesindeki 61 maddeden 60, madde 28 ile birleştirildi) **+ 16 çapraz bulgu + 14 ek bulgu = 91 satır**

| Kesim | Çakışma | Temiz | Dağılım |
|---|---|---|---|
| Çekirdek 60 madde | **37** | 23 | TİP A 17 · A-TERS 1 · B 8 · C 3 · D 3 · E 5 |
| Çapraz bulgular | **15** | 2 | TİP A 8 · A-TERS 1 · C 1 · D 3 · E 2 |
| Ek bulgular (uygulamada var, listede yok) | **12** | 2 | TİP B 9 · A-TERS 1 · D 2 |
| **Toplam** | **64** | **27** | TİP A 25 · A-TERS 3 · B 17 · C 4 · D 8 · E 7 |

*(91 hüküm satırı + 1 birleştirme kaydı = 92 tablo satırı. X-17 doğrulama turunda eklendi.)*

Öncelik dağılımı: **ACİL 26 · YÜKSEK 19 · ORTA 32 · DÜŞÜK 12**

---

# TİP A — SİTE İDDİA EDİYOR, UYGULAMA YAPMIYOR

> Bu bölümün tamamı yanıltıcı beyan riskidir. K7 uyarınca tek karar: iddiayı kaldır, özelliği yol haritasına al. "Yakında" yazarak çözülmez.

---

## A-11 · Uyum motoru: gün içi aktiviteye göre plan güncellemesi
**EN KRİTİK BULGU. Ürünün tüm konumlandırması bu özelliğin üzerine kurulu ve özellik yok.**

**Uygulama: YOK.** Yakılan kalori yalnızca ekranda gösteriliyor (`lib/screens/home/home.dart:1179-1198`); kalori hedefini değiştirmiyor, plan yeniden hesaplanmıyor. Planın tek yeniden-üretim tetikleyicisi profil hash'i ve **kilo, aktivite ve tüketim bu hash'te yok** (`lib/core/services/weekly_meal_plan_service.dart:316-321`).

**Site: İDDİA EDİYOR — 6 ayrı yerde, çekirdek mesaj olarak.**
- `src/pages/ozellikler/yapay-zeka-koc.astro:15` — "3,2 km yürüdün. Plan bunu zaten biliyor."
- `src/pages/hakkimizda.astro:15` (H1) — "Sıfırlamak yerine uyum sağlayan bir sistem"
- `src/content/glossary/tr/adaptif-beslenme-plani.md:5` — "sabit kalmak yerine gerçek aktivite ve kayıt verisine göre **gün içinde yeniden hesaplanan** bir beslenme programıdır"
- `src/content/comparisons/tr/adaptif-plan-vs-sabit-diyet-listesi.md` — sayfanın tamamı bu ayrım üzerine
- `docs/KEYWORD-MAP.md:14` — birincil anahtar kelime "adaptif beslenme planı"
- `src/components/hero/hero-data.ts` — anlatının tamamı

**Pazarlama: GEÇİYOR, çekirdek konumlandırma.** `docs/TONE-OF-VOICE.md:39` marka karşıtlığını "Sıfırlamak yerine / Instead of resetting" olarak "her iki dilde korunmalı" diye kilitliyor. Persona: `src/content/personas/tr/kilo-yonetimi.md:26` — "telefonunun hareket verisini okuyarak günlük hedefi güncelliyor".

**Uygulanan kural: K7 + K1.**

**Karar:** İki yol var, üçüncüsü yok.
1. **Özelliği yap** (yol haritası ŞİMDİ/SONRA kararı — bkz. 04 numaralı dosya). Bu ürünün tek gerçek farkı, ve şu an yok.
2. **Konumlandırmayı gerçeğe indir.** O zaman Cookrange "gün içinde uyum sağlayan plan" değil, "haftalık plan + beş yollu kayıt + salon/topluluk katmanı" olur. Bu, sitenin yarısının yeniden yazılması demek.

Denetimin önerisi: **2'yi hemen uygula (metin), 1'i v1.1'e al.** Yanıltıcı beyan riski bugün var; özellik en iyi hâlde haftalar sonra gelir.

**Düzeltme metni (site, `ozellikler/yapay-zeka-koc.astro:15`):**
> Şu an: "3,2 km yürüdün. Plan bunu zaten biliyor."
> Olması gereken: "3,2 km yürüdün. Yakılan kalori günün üstünde görünür. Planı yeniden üretmek istediğinde bu veriyi hesaba katar."

---

## A-17 · Barkod: "Türkiye ürün veritabanı" ve "2,4 saniye"
**Sitede en çok tekrarlanan yanlış iddia (20+ dosya).**

**Uygulama: KISMEN VAR.** Barkod okuma çalışıyor. Barkodla eşleşen Türkiye paketli ürün kaynağı **yok**: `lib/core/services/barcode_lookup_service.dart:45-46` → `world.openfoodfacts.org/api/v0` — küresel endpoint, TR filtresi yok, eski v0 API'si, zaman aşımı 10 saniye (`:60`). `firestore.rules` ve `firestore.indexes.json` içinde `products` koleksiyonu **hiç yok**; kalıcı önbellek de yok (`:49` yalnızca bellek içi `Map`).
**Kapsam notu (doğrulama turu):** Uygulamada Türkiye'ye özgü veri *vardır* — `lib/core/data/dish_data.dart` (75 Türk yemeği) ve `lib/core/data/turkish_locations.dart` (il/ilçe). Eksik olan spesifik olarak **barkodla eşleşen TR paketli ürün veritabanıdır**. İddia bu kapsamla sınırlı tutulmalı.

**Site: İDDİA EDİYOR.** `src/pages/ozellikler/beslenme-ve-planlama.astro:33` — "Türkiye barkod veritabanı ... yaklaşık **2,4 saniye** sonra sonucu gösterir". `src/content/changelog/tr/v0-9-6.md` — "**Türkiye barkod veritabanı** ... sonucu **ortalama** 2,4 saniyede döndürüyor". `src/content/faq/en/barcode-database.md:11` — "**far more accurately recognized** than with generic international databases".

**Pazarlama: GEÇİYOR, en yoğun iddia.** `docs/HERO-CURRENT-STATE.md:127` — "Türkiye barkod veritabanı · 2.4 saniye". `docs/TONE-OF-VOICE.md:14` "2,4 saniye"yi **iyi somut sayı örneği** olarak kural metnine gömmüş.

**Uygulanan kural: K7 (veritabanı iddiası) + K1/K3 (rakam).**

**Karar:**
1. "Türkiye barkod veritabanı" / "Türkiye'ye özel veritabanı" ifadesi **tüm yüzeylerden kaldırılır**. Gerçek kaynak Open Food Facts, küresel, kullanıcı katkılı.
2. "2,4 saniye" **kaldırılır**. Kodda, dokümanda, testte bu ölçümün kaynağı yok — mock ekran değeri. Ölçüm yapılana kadar rakam verilmez.
3. **Karşılaştırma tersine dönmüş:** `src/content/comparisons/tr/cookrange-myfitnesspal-karsilastirmasi.md:23` MyFitnessPal'ı "büyük, küresel, ağırlıkla kullanıcı katkılı" diye nitelendirirken Cookrange **tam olarak o veritabanını** kullanıyor. Bu satır rakip aleyhine kanıtsız iddiadır ve aynı zamanda kendi ürünü hakkında yanlıştır.

**Düzeltme metni:**
> Şu an: "Türkiye barkod veritabanı ürünü tanır ve yaklaşık 2,4 saniye sonra sonucu gösterir."
> Olması gereken: "Barkodu okutursun. Ürün Open Food Facts veritabanından çekilir; kalori ve makro bilgisi kaydına eklenir. Türkiye market ürünlerinde kapsama oranını ölçüyoruz, sonucu burada yayımlayacağız."

---

## A-44 / A-45 / A-46 / A-47 · Sponsorlu ürün katmanının tamamı
**Denetimdeki en geniş kurgu. Bir sayfa, bir hero sahnesi ve iş modelinin gerekçesi var olmayan bir özelliğe dayanıyor.**

**Uygulama: YOK.** `sponsor` kelimesi `lib/`, `functions/`, `assets/localization/tr.json`, `en.json`, `firestore.rules` genelinde **0 eşleşme** (~115k satır). Marka susturma yok (`mute_brand|muteBrand|brand_mute` → 0). Ödüller tamamen içsel (bonus AI kredisi, başarım, seri dondurma) — indirim kodu yok. Tek iz: `TODO.md:2465` icebox'ta *challenge* sponsorluğu, notu "previously built then removed".

**Site: İDDİA EDİYOR — ayrıntılı mekanizma ve rakamla.**
- `src/pages/ozellikler/sponsorlu-urunler.astro:28` — sıralama kuralı "±%10 kalori, en az %90 protein"
- `:43` — "Dokunulmamış bir planda **sıfır sponsorlu ürün** vardır"
- `:45` — "tek dokunuşla ... **kalıcı olarak susturabilirsin**"
- `:68` — "tek kullanımlık bir **indirim kodu**"
- `:37-38,51` — ₺18 lor / ₺32 protein barı örneği, gram protein başına ₺0,82 vs ₺1,60
- `src/components/hero/hero-data.ts:705` — "**How the free tier is funded**" → ücretsiz katmanın finansman gerekçesi bu katman
- `src/content/faq/tr/sponsorlu-urunler-premium.md` — "kapatma anahtarı Premium'a bağlı değildir"
- `src/pages/legal/kvkk-aydinlatma-metni.astro:143-147` — "marka ortaklarına yalnızca **en az 1.000 hesaplık** gruplar ... iletilir"

**Pazarlama: GEÇİYOR.** `docs/HERO-CURRENT-STATE.md:290,298`.

**Uygulanan kural: K7.**

**Karar:** `ozellikler/sponsorlu-urunler.astro` ve `en/features/sponsored-products.astro` **yayından kaldırılır** (silinmez, `draft`/`noindex` ile geri çekilir), hero'nun `partners` sahnesi çıkarılır, 2 SSS geri çekilir, KVKK metnindeki kohort maddesi çıkarılır. Yerine tek cümle:
> "Ücretsiz katmanı nasıl finanse edeceğimizi açıklarken, kuralları da yayımlayacağız. Şu an uygulamada sponsorlu ürün önerisi bulunmuyor."

**Not — bu kaldırma iş modeli beyanını da boşa çıkarır.** Site "ücretsiz katman şununla finanse edilir" diyordu. O cümle gidince "temel özellikler her zaman ücretsiz" taahhüdünün arkasında hiçbir gelir mekanizması kalmıyor. Bu ürün kararıdır, metin kararı değil (bkz. 04 numaralı dosya, DEĞERLENDİR kovası).

---

## A-08 · Market listesi: "34 ürün, 7 market reyonu"
**Uygulama: SADECE ARAYÜZ VAR.** Reyon sayısı **0**. Yalnızca iki grup var: `shopping.to_buy` / `shopping.in_cart` (`lib/screens/shopping/shopping_list_screen.dart:298-301`). `Ingredient` modelinde kategori/reyon alanı **yok** (`lib/core/models/ingredient_model.dart:1-22` — name, amount, unit, calories, sourceMeals, sourceDates).

**Site: İDDİA EDİYOR — 8 sayfada aynı üçlü.** `src/pages/ozellikler/beslenme-ve-planlama.astro:59` — "28 öğün ... **34 ürüne indirgenir ve 7 market reyonuna göre gruplanır**". Ayrıca `nasil-calisir.astro`, `yemek-plani-uygulamasi.astro:57,113`, `ai-yemek-plani-olusturma.astro`, EN karşılıkları.

**Pazarlama: GEÇİYOR.** `docs/DESIGN-INVENTORY.md:94,109` — "28 öğünü 34 ürüne indi, 7 reyona ayrıldı".

**Uygulanan kural: K7 (reyon) + K1 (34).**

**Karar:** "7 market reyonuna göre gruplanır" ve "34 ürün" kaldırılır. **28 öğün savunulabilir** (7 gün × 4 öğün; `dish_data.dart` kahvaltı/öğle/akşam/ara öğün dağılımıyla tutarlı). Reyon gruplaması yol haritasına girer — `Ingredient` modeline bir kategori alanı eklemek küçük iştir (Efor S), sitenin bu iddiayı geri kazanması muhtemelen en ucuz TİP A kapanışı.

**Düzeltme metni:**
> Şu an: "Haftanın 28 öğünü 34 ürüne indirgenir ve 7 market reyonuna göre gruplanır."
> Olması gereken: "Haftanın 28 öğünündeki malzemeler tek listede toplanır. Aldıkça işaretlersin; işaretlediğin ürünler sepete geçer."

---

## A-15 · "Tarif arama" — arama değil, kotalı yapay zekâ üretimi
**Uygulama: KISMEN VAR ama anlatıldığı şey değil.** `lib/screens/explore/explore_screen.dart:77` sorguyu `ingredients: [query]` olarak AI'ya geçiriyor — yani elindeki 75 yemeği aramıyor, yeni tarif **uydurtuyor**. Her arama **1 AI kredisi harcıyor** (`:59-67`) → ücretsiz kullanıcı günde **2 arama** yapabiliyor. `targetCalories: 500` sabit; kişiselleştirme yok. Katalogda metin araması yok.

**Site: İDDİA EDİYOR ve ücretsiz+sınırsız sayıyor.** `src/pages/fiyatlandirma.astro:9` — "**Sınırsız öğün kaydı** (barkod, hızlı ekle, **tarif arama**, fotoğraf)". `src/content/faq/tr/ucretsiz-mi.md` aynı taahhüdü tekrarlıyor.

**Pazarlama: GEÇİYOR.** `src/content/blog/en/the-first-30-days-a-beginners-guide.md:49`.

**Uygulanan kural: K1 + K4** (kullanıcının anladığı "arama", ürünün yaptığı "üretim" değil).

**Karar:** İki düzeltme.
1. Adı değişir: "tarif arama" → **"tarif üretimi"** (bkz. 03 numaralı sözlük).
2. Ücretsiz katman listesinden çıkarılır ya da kota açıkça yazılır. "Sınırsız" ifadesi barkod ve hızlı ekle için **doğru**, tarif üretimi için **yanlış**. Fotoğraf analizinin kotaya bağlı olup olmadığı **DOĞRULANAMADI** (07 numaralı dosya D1) — bu yüzden düzeltme metni yalnızca tarif üretimini adlandırıyor.

**Düzeltme metni (`fiyatlandirma.astro:9`):**
> Şu an: "Sınırsız öğün kaydı (barkod, hızlı ekle, tarif arama, fotoğraf)"
> Olması gereken: "Sınırsız öğün kaydı — barkod, hızlı ekle ve fotoğraf. Tarif üretimi günlük yapay zekâ kotasından düşer."

---

## A-40 · İlerleme takibi: "squat 60 kilodan 92,5 kiloya"
**Uygulama: KISMEN VAR — kaldırılan ağırlık metriği hiç yok.** Firestore'da tutulan: kalori + 4 makro + egzersiz kalorisi + seri. Takip edilen tek egzersiz metriği `exercise_log_model.dart:35 caloriesBurned`; **ağırlık/set/tekrar metriği: 0**. Ayrıca **günlük kilo ve su serisi yalnızca cihazda** (Hive `weight_box` / `hydration_box`, `lib/core/services/storage_service.dart:19-20`, `:143-145`), Firestore'a gitmiyor → telefon değişince kilo geçmişi kaybolur. *İstisna: onboarding'de bir kez girilen kilo `users/{uid}/private/nutrition` altına yazılıyor (`onboarding_provider.dart:241`) — kalıcı olan tek kilo değeri bu.*

**Site: İDDİA EDİYOR, somut rakamla.** `src/pages/ozellikler/ilerleme-analizi.astro:20` — "squat'ının **60 kilodan 92,5 kiloya** çıktığı bir Aralık". Aynı rakam personada: `src/content/personas/tr/performans-sporculari.md` — "tek bir sütunda saklıyor — **hiçbir ay silinmiyor**". `fiyatlandirma.astro:13` — "**Sınırsız uzun vadeli ilerleme geçmişi**".

**Uygulanan kural: K7.**

**Karar:** Güç/ağırlık takibi iddiası kaldırılır. "Sınırsız ilerleme geçmişi" iddiası da düzeltilir: kilo verisi sunucuda değil, cihazda — bu bir kalıcılık vaadi olarak verilemez. Kilo verisini Firestore'a taşımak yol haritasına girer (Efor S, veri kaybı riski nedeniyle yüksek etkili).

**Düzeltme metni:**
> Şu an: "squat'ının 60 kilodan 92,5 kiloya çıktığı bir Aralık"
> Olması gereken: "Aralık ayında kaç gün kayıt tuttuğun, ne kadar kalori ve protein aldığın ve serinin nerede durduğu görünür. Antrenman ağırlıkları henüz takip edilmiyor."

---

## A-41 · Projeksiyon: "kesikli çizgi"
**Uygulama: KISMEN VAR — grafik yok.** 30/60/90 gün projeksiyonu var ama **yapay zekâdan gelen serbest cümle** (`lib/core/services/ai_insight_service.dart:212-214`). Fitness Twin ekranında hiç grafik yok. Kesikli çizgi başka yerde: `lib/screens/nutrition_hub/nutrition_analytics_screen.dart:475-495` — 7 günlük geçmiş grafiğinin **hedef** çizgisi.

**Site: İDDİA EDİYOR.** `ozellikler/ilerleme-analizi.astro:32` — "**kesikli çizgiyle**, çünkü bu bir tahmin, bir garanti değil". `:46-49` üç somut kilo değeri: "+30 günde 76,9 kg, +60 günde 75,8 kg, +90 günde 75,1 kg".

**Uygulanan kural: K7 (grafik) + K1 (rakamlar).**

**Karar:** "Kesikli çizgi" ve üç kilo değeri kaldırılır. Feragat dili (*"bir tahmin, bir garanti değil"*) **korunur ve öne alınır** — sitenin en doğru yazılmış kısmı bu. `hero-data.ts:851` statik yedeğinde aynı üç kilo değeri **feragat metni olmadan** çıplak veri çipi olarak duruyor; o mutlaka kaldırılır.

**Düzeltme metni:**
> Şu an: "30, 60 ve 90 günlük projeksiyonu kesikli çizgiyle gösterir ... +30 günde 76,9 kg"
> Olması gereken: "30, 60 ve 90 gün için bir tahmin yazar. Tahmin, bir söz değil: kayıt alışkanlığın değiştiğinde tahmin de değişir."

---

## A-22 · Salon doluluk paneli
**Uygulama: YOK.** `occupancy|capacity|doluluk|crowd|live_count|currentlyIn` → `lib/` genelinde **0 eşleşme**; `tr.json` ve `en.json` içinde de 0 (anahtar bile yok). Check-out kaydı bile yok, dolayısıyla "içeride kaç kişi var" hesaplanamaz. Var olan üç şey: 60 günlük yoğun saat ısı haritası (madde 23, `lib/core/services/gym_analytics_service.dart:18-23`, 4 zaman dilimi, 7×4=28 hücre), **son 7 günün gün bazlı devam grafiği** (`gym_service.dart:453` `getWeeklyAttendanceStream`, yalnızca salon sahibine görünür) ve üye listesi. Bunların hiçbiri anlık doluluk değil.

**Site: İDDİA EDİYOR — hem tüketiciye hem salona.** `ozellikler/salon-ekosistemi.astro:39` — "kendi **doluluğunu** ve yoğun saatlerini görür". `guvenlik.astro:31` — "toplam doluluk ve yoğun saat verilerini görür". `fiyatlandirma.astro:10` — "Salon check-in, **doluluk görünürlüğü** ve arkadaş bildirimleri" (her zaman ücretsiz listesinde).

**Pazarlama: GEÇİYOR — B2B satış vaadi.** `src/content/personas/tr/spor-salonlari.md:25-26` — "tek bir QR turnike sistemi hem check-in hem **doluluk görünürlüğü** sağlıyor".

**Uygulanan kural: K7.**

**Karar:** "Doluluk" ifadesi salon yüzeyinden tamamen çıkar. Yerine gerçek olan konur: check-in sayısı ve yoğun saat deseni. Bu, salon pilotuna satılan şeyi değiştirir — satış konuşmasının da düzeltilmesi gerekir.

**Düzeltme metni (salon ve koça hitap: ikinci çoğul):**
> Şu an: "Salon kendi doluluğunu ve yoğun saatlerini görür."
> Olması gereken: "Salonunuz kendi check-in sayısını ve son 60 günün yoğun saat desenini görür. Anlık doluluk sayacı henüz yok."

---

## A-36 · Squad: "altı kişi, tek seri"
**Uygulama: KISMEN VAR — iddianın iki parçası da yanlış.**
- **"Altı" bir üye sınırı değil.** `lib/core/services/streak_squad_service.dart:24-30` → 6, **davet kodunun karakter uzunluğu** (`List.generate(6, ...)`, yorum: "6-char invite code"). Ne serviste, ne modelde, ne güvenlik kurallarında üye tavanı var; `joinSquad` (`:82-113`) üye sayısını kontrol etmiyor, `arrayUnion` sınırsız (`:105`).
- **"Tek seri" yok.** `getMemberStreaks` (`:171-187`) her üyenin **bireysel** serisini listeliyor. Ortak/paylaşılan seri hesabı yok.
- **Katılma yolu DOĞRULANAMADI.** `firestore.rules:642-652` `squads` bloğu `read` ve `update` için `uid in resource.data.memberUids` istiyor; `joinSquad` (`:87-90`) henüz üye olmayan kullanıcıyla `inviteCode` sorgusu yapıyor → statik analizde permission-denied beklenir. `inviteCode` için indeks de yok. **Çalışma zamanı testi yapılmadı** (bkz. 07 numaralı dosya D13) — bu yüzden "çalışmıyor" değil "DOĞRULANAMADI" olarak işaretlendi.

**Site: İDDİA EDİYOR — sözlükte kanonik tanım olarak.** `ozellikler/topluluk-ve-squad.astro:15` — "**Altı sütun, tek bir seri**". `src/content/glossary/tr/squad.md:5` — "**aynı seriyi paylaşan altı kişilik** bir hesap verebilirlik grubudur". `src/content/changelog/tr/v0-9-6.md` — "**Altı kişilik gruplar artık tek bir seriyi paylaşabiliyor**" (yayınlanmış sürüm notu).

**Pazarlama: GEÇİYOR, güçlü.** `docs/HERO-CURRENT-STATE.md:237` — "Six columns, one streak."

**Uygulanan kural: K7 + K1.**

**Karar:** "Altı kişi" ve "tek seri" kaldırılır. Bu üç yerde de düzeltilir: özellik sayfası, sözlük girdisi, **yayınlanmış changelog** (v0.9.6 sürüm notu yanlış bilgi içeriyor — düzeltme notu eklenir, satır silinmez). Squad'ın çalışıp çalışmadığı acilen test edilir; kural/indeks düzeltmesi yol haritasına girer.

**Düzeltme metni:**
> Şu an: "Altı sütun, tek bir seri."
> Olması gereken: "Squad, arkadaşlarının serilerini yan yana gördüğün grup. Birinin sütunu düzleşirse diğerleri fark eder."

---

## A-05 · Bütçeye göre plan üretimi
**Uygulama: YOK.** `budget|bütçe|cost|price` → `lib/`, `dish_data.dart`, `tr.json`, `en.json` genelinde **0 sonuç**. Yemek verisinde fiyat alanı yok, dolayısıyla bütçe kısıtı hesaplanamaz.

**Site: İDDİA EDİYOR.** `ai-yemek-plani-olusturma.astro:16` — "mutfakta ayırabileceğin süre ve **haftalık bütçen**".

**Pazarlama: GEÇİYOR — ve tek kaynağı basın kiti.** `src/pages/basin-kiti.astro:64` (uzun boilerplate) — "vücut verilerine, hedeflerine, **alerjenlerine ve bütçesine** göre üretilir". Aynı sayfa :38 "düzenlenmeden kullanılmaları tercih edilir" diyor → bu cümle basına olduğu gibi gider.

**Uygulanan kural: K7.**

**Karar:** "Bütçe" hem siteden hem **basın kiti boilerplate'inin dört sürümünden** çıkarılır. Basın kiti en yüksek risk yüzeyi: gazeteci düzeltmeden basar. Ayrıca "mutfakta ayırabileceğin süre" iddiası **DOĞRULANAMADI** — hazırlık süresi girdi olarak kullanılıyor mu kanıtlanamadı; kanıt bulunana kadar o da çıkar.

---

## A-07 · Alternatif öneriler / malzeme ikamesi
**Uygulama: YOK.** Malzeme eşdeğerlik ikamesi ("2 kayısı ve 10 badem de aynı işi görür") hiç yok. Var olan: bütün-yemek değiştirme `swapMeal` (`weekly_meal_plan_service.dart:222`) ve 2 makro alternatifi (`:363`). **Ayrıca `swapMeal` sessiz veri bozulması üretiyor:** `:267-277` yalnızca `days` alanını güncelliyor, `total_calories` ve `macros` eski değerde kalıyor (`:259-261`) — 800 kcal'lik yemeği 300 kcal ile değiştirsen ekranda hâlâ 800 görünür.

**Site: İDDİA EDİYOR** — `ozellikler/sponsorlu-urunler.astro:43` (yani zaten kaldırılacak sayfada).
**Pazarlama: KISMİ** — yalnızca mock buton (`docs/DESIGN-INVENTORY.md:91` "Değiştir").

**Uygulanan kural: K7.**
**Karar:** İkame iddiası kaldırılır. `swapMeal` toplam güncelleme hatası TODO'ya girer — bu bir metin sorunu değil, veri doğruluğu hatası.

---

## A-09 · Tek adımda özelleştirme — metinle
**Uygulama: KISMEN VAR.** Serbest metinle **besin analizi** ve **tarif üretimi** var. **Planı serbest metinle özelleştirme yok**: `lib/core/services/prompt_service.dart` içinde 3 prompt var, hiçbiri kullanıcı metni parametresi almıyor.

**Site: İDDİA EDİYOR** — `ozellikler/yapay-zeka-koc.astro:38` — "\"muza çikolata sosu döktüm\"" (planı düzelten serbest metin senaryosu).
**Pazarlama: GEÇİYOR, tek kaynak basın kiti** — `basin-kiti.astro:66` — "tek tek **atıştırmalıklar da serbest metinle düzenlenebilir**".

**Uygulanan kural: K7 + K2** (var olan kısım için sitenin dili kullanılır).

**Karar:** "Planı serbest metinle düzenle" iddiası kaldırılır; var olan gerçek öne çıkarılır — yediğini yazarsın, besin değeri çıkarılır ve kaydedilir. Basın kiti cümlesi çıkar.

**Düzeltme metni:**
> Şu an: "\"muza çikolata sosu döktüm\" yazarsın, plan güncellenir."
> Olması gereken: "\"muza çikolata sosu döktüm\" yazarsın; yapay zekâ besin değerini çıkarır ve kaydına ekler."

---

## A-12 · Değişmezlik ilkesi: kayıtlı öğünler yerinden oynamaz
**Uygulama: YOK — ve ekip deseni biliyor.** `firestore.rules:163-165` → `food_logs` için `allow read, write: if isOwner(uid)`; update ve delete serbest. Aynı dosyada `gyms/*/checkins` için `allow update, delete: if false` **var** — desen biliniyor, öğün kayıtlarına uygulanmamış. Seri, liderlik tablosu ve başarımlar öğün kayıtlarından beslendiği için oyunlaştırma manipüle edilebilir.

**Site: İDDİA EDİYOR** — `ozellikler/yapay-zeka-koc.astro:24` — "**Kaydedilmiş hiçbir öğün geriye dönük değiştirilmez.**" `basin-kiti.astro:65` — "plan sıfırdan yeniden üretilmez, yalnızca henüz yenmemiş öğünler ayarlanır".

**Uygulanan kural: K1.**

**Karar:** İki katman ayrıştırılır. (a) *Plan geçmiş kaydı yeniden yazmaz* — uyum motoru olmadığı için vakıa doğru ama boş bir vaat; (b) *kayıt değiştirilemez* — kural düzeyinde yanlış. Site (b) izlenimini veriyor. Kural düzeltmesi yol haritasına girer (Efor S). Metin, düzeltilene kadar (a) ile sınırlanır.

---

## A-31 · Ücretli koçluk / gelir kalemleri
**Uygulama: YOK.** Tek ödeme paketi `pubspec.yaml:85` `in_app_purchase` (yalnızca Premium). Payout sağlayıcı 0. `TODO.md:2517` `COA-05` — "ready but never called". Ücretli programlar arayüzde açıkça "yakında" banner'ı gösteriyor (`lib/screens/programs/program_detail_screen.dart:513-514`).

**Site: KISMEN İDDİA** — `fiyatlandirma.astro:74` — gelir kalemleri arasında "salonlar, koçlar ve white-label iş birlikleri".

**Uygulanan kural: K7 (kip düzeltmesi).**
**Karar:** Gelecek zamana çevrilir. Mevcut zaman kipi, çalışan bir B2B gelir hattı olduğu izlenimini veriyor; yok.

---

# TİP A-TERS — UYGULAMA İDDİA EDİYOR, ÜRÜN YAPMIYOR
> Bu tipi kontrol listesi öngörmüyordu ama denetim buldu: **uygulamanın kendi ekran metni siteden daha çok abartıyor.** Site burada dürüst olan taraf.

## AT-43 · Premium ekranındaki beş yanlış vaat
**Uygulama içi metin (`assets/localization/tr.json`) beş şey satıyor, uygulama beşini de yapmıyor:**

| Anahtar | Metin | Gerçek |
|---|---|---|
| `premium.perk_meal_plans` | "**Sınırsız Plan**" | Günde 20 (`functions/index.js:31-32`) |
| `premium.description` | "**Reklamsız deneyim**" | Uygulamada reklam SDK'sı **hiç yok** — ücretsizde de reklam yok |
| `ai.paywall_feature2` | "Öncelikli AI işleme" | Rate limit her iki kademede aynı: 12 istek/dk |
| `ai.paywall_feature3` | "Gelişmiş öğün özelleştirme" | Böyle bir özellik yok |
| `ai.paywall_feature4` | "Detaylı beslenme analitiği" | `nutritionAnalytics => true` — ücretsiz |

*Doğrulanan tek doğru satır:* `ai.paywall_feature1` = "Günde 20 AI kullanımı" — sunucu değeriyle uyumlu. "Reklamsız deneyim" için ek kanıt: `pubspec.yaml` içinde `ads|admob|applovin|unity|ironsource` → **0 paket**; kaldırılacak reklam yok. "Öncelikli AI işleme" için: repoda `priority` tek eşleşmesi `functions/index.js:618` `android: { priority: 'high' }` — FCM bildirim önceliği, yapay zekâ kuyruğu değil.

**Site: DAHA DÜRÜST.** `fiyatlandirma.astro:16-20` yalnızca üç şey söylüyor ve hiçbiri yanlış değil: "daha sık yeniden planlama", "daha detaylı gerekçelendirme", "gelecekte eklenecek ileri düzey analiz araçları".

**Uygulanan kural: K2 tersine — kapsam uygulamadan, ifade siteden.** Burada kapsamı da ifadeyi de site doğru veriyor.

**Kota rakamı — doğrulama turu düzeltmesi.** İlk incelemede "üç çelişen kota" bulgusu vardı; doğrulama bunu daralttı. Kullanıcıya gösterilen değer `lib/core/models/ai_credit_model.dart:10-11` (`freeDailyLimit = 2`, `premiumDailyLimit = 20`) üzerinden geliyor ve `functions/index.js:30-31` sunucu değeriyle **birebir uyumlu** ✅ — yani kullanıcıya görünen bir tutarsızlık yok. `app_config_model.dart:71-72` içindeki 5/50 varsayılanı ve `subscription_model.dart:47-51` içindeki 10/50 değeri **hiçbir yerden okunmuyor**: ölü yapılandırma. Gerçek risk şu: bir yönetici uzaktan yapılandırmayı bu ölü alanlar üzerinden değiştirdiğinde hiçbir etki görmez.

**Karar:** Beş uygulama içi dize sitenin diline çekilir. Bu, ödeme alan bir ekranda yanlış vaat olduğu için **mağaza incelemesi ve tüketici hukuku riski** — bkz. 06 numaralı dosya.

**Düzeltme metni (uygulama ekran metni, kod değil):**
> `premium.perk_meal_plans`: "Sınırsız Plan" → "Günde 20 yapay zekâ üretimi"
> `premium.description`: "Reklamsız deneyim" → "Yapay zekâ üretim hakkın artar"
> `ai.paywall_feature2`: "Öncelikli AI işleme" → kaldır
> `ai.paywall_feature3`: "Gelişmiş öğün özelleştirme" → kaldır
> `ai.paywall_feature4`: "Detaylı beslenme analitiği" → kaldır (ücretsizde var)

---

# TİP B — UYGULAMA YAPIYOR, SİTE ANMIYOR
> Kaybedilen değer. Burada risk yok, para kaybı var.

## B-18 · Yapay zekâya serbest soru sorma (sohbet + sesli)
**Uygulama: TAM VAR.** `lib/core/services/ai_chat_service.dart:29-57` — profil bağlamlı sistem prompt'u, prompt injection koruması (`prompt_service.dart` `injectionGuard`/`fence`), **sesli asistan** (`lib/core/widgets/voice_assistant_overlay.dart` + `speech_to_text`). Geçmiş kalıcı değil.
**Site: ANILMIYOR.** Yalnızca "Neden?" gerekçe butonu geçiyor; sohbet yüzeyi hiç yok.
**Kural: K3.** **Karar:** Özellik sayfasına eklenir. Çalışan, farklılaştırıcı ve rakiplerde nadir bir yüzey sitede görünmüyor. Sesli mod ayrıca anlatılır.

## B-34 / B-35 · Topluluk akışı, öğün fotoğrafı paylaşımı, "paylaş = kaydet"
**Uygulama: TAM VAR ve büyük.** `community.*` **67 localization anahtarı**; gönderi/yorum/tepki/kaydetme/bildirme; 4 gönderi tipi; `lib/screens/community/widgets/create_post_card.dart:745-753` öğün alanları (ad + 4 makro). "Paylaş ve kaydet aynı hareket" gerçekten tek dokunuş: `lib/screens/recipe/cooking_mode_screen.dart:489-538` → `logRecipe` + `createPost`. Ayrıca 3 rollü konum tabanlı topluluk grupları, birebir + grup sohbeti (`chat.*` 23), "Signal" dürtme (`signal.*` 10), haftalık öne çıkanlar, başarım rozetleri (`achievements.*` 15 anahtar).
**Site: ANILMIYOR** — hatta gizlilik çerçevesi ters yönde konuşuyor ("beslenme geçmişini asla görmez").
**Kural: K3 + K5.** **Karar:** Topluluk yüzeyi siteye eklenir. Şu an sitede topluluk = squad + salon sıralaması; gerçekte tam bir sosyal katman var. Bu, "topluluk hendeği" anlatısının en güçlü kanıtı ve sitede yok.

## B-54 · Salon savaşları (salonlar arası haftalık meydan okuma)
**Uygulama: TAM VAR.** `gym_leaderboard_service.dart:98-104` `durationDays = 7`; arayüz: sekme + oluşturma sayfası + canlı skor kartı (`gym_leaderboard_screen.dart:120-132, 623-830`).
**Site: ANILMIYOR** (kontrol listesi bunu "muhtemelen yok" diye işaretlemişti — var).
**Ayrıca uygulama kendi çalışan özelliğini saklıyor:** `gym.feature_challenges` "YAKINDA GELECEK" etiketli. Aynı durum salon kurulumu, QR giriş ve analitikte de var (`gym.setup_coming_soon`). Dokümanı da yanlış: `docs/GYM_ECOSYSTEM.md:107,151` "effectively unbuilt" diyor.
**Kural: K1.** **Karar:** "YAKINDA" etiketleri kaldırılır, özellik siteye eklenir. Salon pilotunun en satılabilir parçası bu ve üç kaynakta da görünmez durumda.

## B-16 · Fotoğraftan öğün analizinin zengin çıktısı
**Uygulama: TAM VAR.** `analyzeFoodPhoto` yalnızca kalori vermiyor: **4 makro + 7 zenginleştirilmiş alan** (lif, şeker, sodyum, sağlık puanı, alerjen tahmini, güven skoru, gram). Yurt dışı aktarım bilgilendirmesi de mevcut ✅.
**Site: KISMEN ANIYOR.** `nasil-calisir.astro:16` — yalnızca "veya fotoğrafla kaydet". Mekanizma yok, rakam yok.
**Pazarlama: KISMİ.** `blog/en/how-to-track-macros-and-who-actually-needs-to.md:70` — analiz adıyla anlatılmıyor.
**Kural: K3.** **Karar:** Sitede somutlaştırılır: 4 makro + lif, şeker, sodyum ve alerjen tahmini. **DOĞRULANAMADI:** Fotoğraf analizinin yapay zekâ kotasına bağlı olup olmadığı — 07 numaralı dosya D1.

## B-06 · 75 yerel yemek
**Uygulama: TAM VAR, sayılabilir.** `lib/core/data/dish_data.dart` → **75 yemek** (kahvaltı 18 / öğle 25 / akşam 29 / ara öğün 3), TR+EN çift adlı, makro ve malzeme tam.
**Site: sayı VERMİYOR** — yalnızca mock örnekler ("Menemen ve yulaf").
**Kural: K3.** **Karar:** "75 Türk yemeği" kullanılır. Sitenin kullanmadığı, **doğrulanabilir** tek somut rakam bu. Uyarı: ara öğün yalnızca 3 — "atıştırmalık çeşitliliği" iddiası verilmez.

## B-33 · Konum tabanlı topluluk grupları
**Uygulama: KISMEN VAR ama sitenin anlattığından zengin.** `scope` enum'u yok; "Gym" filtresi 6 etiketli `arrayContainsAny` (`community_service.dart:102-110`), üyelik değil. Ancak **3 rollü konum tabanlı topluluk grupları** var (salon tarafından daha olgun bir rol modeli) + TR il/ilçe veri seti (`turkish_locations.dart`).
**Site: ANILMIYOR.** **Karar:** "Üç kapsam: salon / ilçe / şehir" iddiası verilmez (yok), ama var olan grup yapısı anlatılır.

## B-61 · Kayıt boşluğu telafisi
**Uygulama: KISMEN VAR — 3 parça, birleşik akış yok.** Risk seviyeleri (`ai_insight_service.dart:35-43`, 4 seviye, eşik 10:00 / 14:00 / kayıt=0), 17:00 UTC push (`functions/index.js:941`, **500 kullanıcı tavanı**), seri dondurma.
**Site: ANILMIYOR** — hatta hero ters tonda: "Atladığın kayıt bir daha geri gelmeyen veridir" (`hero-data.ts:739`).
**Pazarlama: GEÇİYOR** — `blog/tr/yeni-baslayanlar-icin-ilk-30-gun-rehberi.md:70` "geçmişe dönük bir ceza ya da sıfırlama yoktur".
**Kural: K5** (marka sesi: suçlayıcı olmayan). **Karar:** Hero'nun suçlayıcı cümlesi blogun tonuna çekilir; 500 kullanıcı tavanı kaldırılana kadar bu bildirim "her kullanıcıya gider" diye anlatılmaz.

---

# TİP C — AYNI ÖZELLİK, FARKLI İSİM
> Marka tutarsızlığı. Bir dil modeline "Cookrange hangi aşamada?" diye sorulduğunda en sık geçen ifade cevap olur — bu yüzden C-53 en pahalısı.

## C-53 · Aşama adı: altı farklı ad, biri "private beta"
| İfade | Kaç yerde |
|---|---|
| dahili alfa / internal alpha | **14** |
| özel beta / **private beta** | **16** (8 TR + 8 EN blog) |
| beta öncesi / pre-beta | **2** — *ikisi de basın kiti orta boilerplate'i* |
| kapalı beta / closed beta | 2 |
| bekleme listesi aşaması / waitlist stage | 2 |
| özel erken erişim / private early-access | 2 |

Ek olarak sürüm numarası çelişkisi: `pubspec.yaml:4` = **`1.0.0+1`** ↔ `README.md:17` ve `PROJECT_STATE.md:15` = **v0.9.6 dahili alfa**.

**Kural: K1 + K4.** **Karar:** Kanonik ad **"v0.9.6 dahili alfa" / "v0.9.6 internal alpha"**. Diğer beş ifade yasaklanır (bkz. 03 numaralı sözlük). En sık geçen "private beta" olduğu için **aşama enflasyonu** var: alfa ürünü kendini beta gibi anlatıyor. `pubspec.yaml` güncellenmemiş şablon değeri taşıyor — düzeltilecek olan o.

## C-32 · "Kadro" / "roster" ↔ danışan listesi
**Uygulama:** Salon kadro paneli **YOK** (`staff|kadro|personel` → 0; `TODO.md:2497` `GYM-08` Icebox). Koçun danışan listesi **VAR**.
**Site:** `hero-data.ts:784` — "Bir koç kendi **kadrosunu** okur." / "A coach reads their **roster**."
**Kural: K4.** **Karar:** Kanonik ad **"danışan listesi" / "client list"**. "Kadro"/"roster" kullanılmaz — salon personeli paneliyle karışıyor ve o panel yok.

## C-48 · "Yakınımdaki arkadaş sıralaması" ↔ salon ve koç keşfi
**Uygulama:** `nearbyFriends` → **0 sonuç**. Konumu kullanan gerçek özellikler: salon keşfi ve koç keşfi.
**Site:** `guvenlik.astro:26` ve `faq/tr/veri-nerede-saklaniyor.md` konum vaadini "yakınımdaki **arkadaş** sıralaması"na bağlıyor.
**Kural: K1.** **Karar:** Vaat korunur (doğru), özellik adı düzeltilir: "Yakınındaki salon ve koç sıralaması cihazında hesaplanır; koordinat sunucuya gönderilmez."

**Ek terminoloji tutarsızlıkları (sözlükte kilitlendi):**
- `T1` "Adaptif" — `TONE-OF-VOICE.md:39` yasaklıyor, `KEYWORD-MAP.md:14` birincil kelime yapıp URL'e gömmüş
- `T2` "Wishlist" — `TONE-OF-VOICE.md:35` yasaklıyor, `hakkimizda.astro:47` route anahtarı olarak kullanıyor (18 yerde)
- `T3` Yapay zekâ katmanının üç adı: "Cookrange AI" / "yapay zeka beslenme koçu" (URL) / "adapt katmanı" (blog)
- `T4` TR metinde "Gym ekosistemi" ↔ "Salon ekosistemi" (5 yerde karışık)
- `T5` Aşama adı — altı farklı ad (bkz. C-53, yukarıda)
- `T6` EN'de "a local barcode database" ↔ "a database specific to Turkey"

---

# TİP D — AYNI ÖZELLİK, FARKLI RAKAM
> Güvenilirlik riski. Her satırda hangi rakamın doğru olduğu kanıtlanmıştır.

## D-01 · Haftalık plan: "pazar günü" ↔ pazartesi 07:00 UTC
**Uygulama:** Plan üretimi tamamen istemcide, **talep üzerine** (`weekly_meal_plan_service.dart:67`). Sunucuda plan üreten cron **yok**. Var olan `functions/index.js:997` `weeklyPlanReadyNotifier` yalnızca **pazartesi 07:00 UTC** push atıyor, üst sınır `.limit(500)`.
**Site:** "Hafta, **pazar günü** yazıldı." (`hero-data.ts:731`, `ozellikler/beslenme-ve-planlama.astro:15`)
**Kanonik:** Planı **kullanıcı üretir**; hatırlatma **pazartesi 07:00 UTC**. "Pazar" hiçbir kaynakta karşılığı olmayan bir gün.
**Kural: K1.** **Karar:** "Pazar günü yazıldı" kaldırılır. 500 kullanıcı tavanı da bir sınırdır — bildirim "herkese gider" diye anlatılmaz.

## D-51 · Platform: "Android 8 ve üzeri"
**Uygulama:** iOS min **14.0** doğrulandı (`ios/Runner.xcodeproj/project.pbxproj:473,607,659`). Android: `android/app/build.gradle:79` → `minSdkVersion flutter.minSdkVersion` — repoda sabit yok, Flutter pini yok; bu değer 21 veya 24'e çözülür, **26'ya (Android 8) değil**. Ayrıca bundle id çelişkisi: `pubspec.yaml:16` `com.cookrange_ios.app` ↔ `project.pbxproj:496` `com.cookrange-ios.app`.
**Site:** "iOS 14 ve üzeri, Android 8 ve üzeri" (`indir.astro:27`, kesin kip).
**Kanonik:** iOS 14 ✅ · **Android 8 DOĞRULANAMAZ** — gerçek zemin büyük olasılıkla daha düşük.
**Kural: K1.** **Karar:** `build.gradle`'a `minSdkVersion 26` yazılır (iddia doğrulanır) ya da site rakamı düzeltilir. İkisinden biri yapılmadan mağaza kaydı açılmamalı.

## D-52 · TR/EN eşitlik ve basın kiti karakter sayıları
**Uygulama:** `tr.json` **2725** / `en.json` **2725** anahtar, eksik 0, boş 0, 77 grup — **anahtar paritesi kusursuz.** Ama **6–15 TR dizesi hâlâ İngilizce** (`profile.last_seen`, `profile.friends_modal.search_hint`, `.no_friends`, `profile.friend_actions.received_text`, `explore.suggestion.smoothie`, `program.paid_locked_title`; ön incelemede `profile.friend_actions.*` ve `friends_modal.*` grupları da sayılmıştı). `test/i18n_parity_test.dart` yalnızca anahtar kümesini karşılaştırıyor, **değerleri karşılaştırmıyor** → CI bunu göremiyor. Ayrıca localization dışı sabit İngilizce: `nutrition_analytics_screen.dart:515` `['Mo','Tu',...]`, `gym_analytics_screen.dart:548`, `gym_leaderboard_screen.dart:220`.
**Site:** 48/48 sayfa çifti, 57/57 içerik çifti, 0 yetim — **site düzeyinde parite gerçek** ✅ (2 TR-only yasal sayfa bilinçli tasarım: `src/lib/routes.ts` `localeInvariantRoutes`).
**Pazarlama:** `basin-kiti.astro:44` "Kısa (**160 karakter**)" → gerçek **175 karakter**. EN karşılığı 143. TR/EN boilerplate arası 32 karakter fark, "tam eşitlik" iddiasıyla çelişiyor.
**Kanonik:** 2725 = 2725 ✅ · çevrilmemiş TR dizesi **6 doğrulanmış** (üst sınır 15) · boilerplate TR 175 / EN 143.
**Kural: K1 + K3.** **Karar:** Etiket düzeltilir ("175 karakter") ya da metin 160'a indirilir. Parity testi değer karşılaştırması yapacak şekilde genişletilir.

---

# TİP E — KAPSAM UYUŞMAZLIĞI
> En sinsi tip. Beşinin dördü mahremiyet ya da fiyatlandırma iddiasında — kontrol listesinin öngördüğü yerde.

## E-49 · "Salon vücut verisini göremez" — doğru; "yalnızca toplam veri görür" — yanlış
**Uygulama:** Vücut verisi gerçekten korunuyor ✅ (`firestore.rules:207-211` `private/{docId}` owner-only; `gym_member_model.dart:12-17` 5 alan, hiçbiri sağlık verisi değil). **Ama salon bireysel veri görüyor:** `firestore.rules:467-470` salon sahibi tüm `checkins`'i, `:426-429` tüm `members`'ı okuyor. `checkin_model.dart:52-58` → `uid`, `display_name`, `photo_url`, `timestamp`, `method`. `gym_analytics_service.dart:99-104` **14 gündür gelmeyenlerin isim listesini** üretiyor, `:106-116` aylık top 5, `:137-170` **CSV ihracı: `uid,name,joined_at,total_checkins,last_checkin,tier`**.
**Site:** `faq/tr/salon-veri-erisimi.md` — "**Erişemez.** Bir salon yalnızca kendi **toplam** doluluğunu, yoğun saatlerini ve check-in sayısını görür." `guvenlik.astro:31-32` — "bireysel kullanıcı verisine erişimleri yoktur."
**Kural: K1.** **Karar:** Salonun gördüğü şey açıkça yazılır. Bu bir metin düzeltmesiyle kapanır; kapanmazsa KVKK aydınlatma yükümlülüğü ihlalidir (bkz. 06 numaralı dosya, R2).
> Olması gereken: "Salon işletmesi üye listesini ve check-in kayıtlarını görünen ad düzeyinde görür, devam istatistiklerini dosya olarak indirebilir. Beslenme geçmişine, kilo verine ve ölçümlerine erişemez."

## E-26 · Koç içgörüsü: "üye izniyle" — izin adımı yok
**Uygulama: SADECE ARAYÜZ + onay yok.** `lib/screens/coach/coach_client_detail_screen.dart:100-152` danışanın davranışsal sağlık verisini yapay zekâ sağlayıcısına (OpenRouter, yurt dışı) gönderiyor. Dosyada `consent`, `permission`, `isPremium` kelimelerinin hiçbiri geçmiyor; tek kapı `AIService().isConfigured` (`:102`). `ConsentPurpose` kümesinde koç erişimi diye bir amaç **yok** (`consent_model.dart:11-19`). Kontrol listesi bunu "Premium" sanıyordu — Premium da gerekmiyor.
**Site:** `ozellikler/ilerleme-analizi.astro:62` — "Bir koç kendi sporcusunun ilerlemesini okur." `faq/tr/koc-ve-arkadas-erisimi.md` — "yalnızca senin ilerlemeni okur" (aktarımı hiç anmıyor).
**Kural: K1.** **Karar:** ACİL. Ya rıza adımı eklenir ya koç AI raporu kapatılır. Metin de aktarımı açıklar. Bu denetimin en ciddi KVKK bulgusu.

## E-50 · İzin modeli: 7 amaç var, geri çekme çalışmıyor
**Uygulama:** Nominal olarak güçlü — 7 amaç bazlı rıza (`health_data, location, ai_processing, cross_border_transfer, analytics, notifications, marketing`; ilk 4 `isSensitive`) + 4 OS izni = 11 nokta; sürümlü, zaman damgalı, varsayılan kapalı. **Ama:** `consent_service.dart:73-85` `hasConsent` tüm `lib/` ağacında yalnızca `:92` tarafından çağrılıyor → `healthData`, `location`, `aiProcessing`, `crossBorderTransfer`, `notifications` rızası geri çekildikten sonra plan üretimi, OpenRouter'a giden profil bağlamı ve GPS check-in **aynen çalışıyor**. Rıza kaydından uygulanan tek amaç `analytics`.
**Doğrulama turu notu:** İki gerçek kullanım anı kapısı var, ama ikisi de rıza kaydını okumuyor: (a) `food_scan_screen.dart:233-241` — yapay zekâ fotoğrafı için yurt dışı aktarım açıklaması, yerel `SharedPreferences` bayrağına bağlı, kabul sonrası `setConsent(crossBorderTransfer/aiProcessing, true)` **yazıyor**; (b) `gym_discovery_screen.dart:134-151` ve `coach_discovery_screen.dart:103-140` — `PermissionPrimer` + OS konum izni. Yani "hiç kontrol yok" değil; **geri çekme etkisiz**, çünkü kapılar yerel bayrak ve OS iznine bakıyor. Ayrıca `location` ve `notifications` rıza kaydı **hiç yazılmıyor** (`:100` yorumu: "Location + notifications stay unset"). Kayıtta üç hassas amaç **tek zorunlu kutuda** paketli (`:120-122`, `register_screen.dart:103-110`) — oysa `assets/legal/explicit_consent_tr.md:8-10` "rıza verip vermemekte **tamamen özgürsünüz**" diyor.
**Site:** `ozellikler/salon-ekosistemi.astro:34` — "İzni reddedersen ... aynen çalışmaya devam eder." `legal/acik-riza-metni.astro:91-93` — kutunun "işaretlenmemiş" ve "ayrı bir adımda" olduğunu iddia ediyor.
**Kural: K1.** **Karar:** ACİL. Rıza geri çekme yolları koda bağlanır; bağlanana kadar metin gerçeği söyler.

## E-42 · Ücretsiz katman kapsamı
**Uygulama:** Gerçek tek kısıt: günde **2** AI üretimi + 12 istek/dakika. `Entitlements`'ın 8 kapısından hiçbiri çağrılmıyor — `FeatureGateService().check()` için **0 çağrı yeri**, yalnızca 3 `showPaywall`.
**Site:** 5 madde sayıyor; ikisi yanlış: "Sınırsız öğün kaydı (… tarif arama, fotoğraf)" (AI kotalı — bkz. A-15) ve "**doluluk görünürlüğü**" (özellik yok — bkz. A-22). "Squad'lar" da kırık olabilir (bkz. A-36).
**Kural: K1.** **Karar:** Ücretsiz katman listesi gerçeğe göre yeniden yazılır (bkz. 05 numaralı dosya).

## E-37 · Seri: kayıt serisi mi, giriş serisi mi?
**Uygulama: TAM VAR ama tabanı farklı.** `firestore_service.dart:180-191` → `difference > 1` ise dondurma jetonu ya da sıfırlama. Seri **uygulamaya giriş** tabanlı, kayıt tabanlı değil. Dondurma 1 hediye; kilometre taşları 7/14/30/60/100/365.
**Site:** `src/content/glossary/tr/seri-streak.md:5` — "kesintisiz olarak art arda tamamlanan gün sayısıdır — örneğin art arda **kayıt tutulan** veya antrenman yapılan gün sayısı."
**Kural: K1.** **Karar:** Ya seri kayıt tabanına çevrilir (ürün kararı; oyunlaştırmanın anlamı buna bağlı) ya sözlük tanımı düzeltilir. Şu an kullanıcı hiç kayıt tutmadan seri büyütebiliyor — bu, "seri" vaadinin içini boşaltıyor.

---

# ÇAPRAZ BULGULAR
> Tek bir özelliğe bağlanmayan, üç kaynağı birlikte etkileyen bulgular.

## X-01 · "12.400 sütun" — sıfır kullanıcılı üründe ölçek iddiası · **ACİL**
`src/components/hero/hero-data.ts:699` → `eyebrow: "12,400 columns · One substrate"` (TR: "12.400 sütun"). Sitenin kendi sözlüğünde "sütun" = **bir kullanıcının veri sütunu**. Hemen altında "Üyeler, koçlar ve salonlar aynı zeminde" yazıyor. Render edilen gerçek `.cr-column` sayısı **12**. Ürünün mağazada olmayan, sıfır kullanıcılı bir dahili alfa olduğu düşünülürse bu satır **kullanıcı sayısı gibi okunuyor**. `docs/TONE-OF-VOICE.md:19` kendi kuralı: "Uydurma sosyal kanıt: kullanıcı sayısı ... gerçek veri yoksa **hiç kullanılmaz**".
**Karar:** Kaldırılır. Kaynağı yok, tanımı yok, savunması yok.

## X-02 · Yapılandırılmış veride uydurma puan YOK ✅
Denetimin en önemli olumlu bulgusu: `aggregateRating`, `ratingValue`, `reviewCount`, `ratingCount`, `interactionStatistic`, kullanıcı sayısı → `src/` ve `public/` genelinde **0 eşleşme**. `src/lib/schema.ts:6-9` bunu bilinçli karar olarak belgeliyor: *"AggregateRating/Review generators are intentionally NOT provided."* **Acil risk hipotezi çürütüldü.**

## X-03 · `applicationCategory: "HealthApplication"` ↔ "sağlık uygulaması değildir" · **YÜKSEK**
`src/lib/schema.ts:68` her sayfaya `HealthApplication` gömüyor. `ai-yemek-plani-olusturma.astro:132` — "Cookrange bir tıbbi cihaz ya da **sağlık uygulaması değildir**". Makine beyanı ile hukuki feragat birbirinin tersi; KVKK açısından "sağlık uygulaması" beyanı özel nitelikli veri imasıdır.
**Karar:** `"LifestyleApplication"` olarak düzeltilir.

## X-04 · 30 blog yazısı gelecek tarihli, hepsi yayında · **YÜKSEK**
15 EN + 15 TR yazı bugünden sonraki `publishDate` ile, `draft: false`. Örnek: `blog/en/whats-new-in-v0-9-6-...md:7` → `publishDate: 2026-11-02` (~90 gün sonra). `src/pages/blog/[slug].astro:9` tarihe göre filtrelemiyor, `:49` bu tarihi `datePublished` olarak yayınlıyor.
**Karar:** `draft: true` ya da `publishDate <= new Date()` filtresi.

## X-05 · `inLanguage: "tr-TR"` tüm İngilizce yazılarda · **ORTA**
`schema.ts:191` sabit; `src/pages/en/blog/[slug].astro:40` aynı fabrikayı çağırıyor → ~15 İngilizce yazı kendini Türkçe beyan ediyor.

## X-06 · Offer: TR ₺0 / EN $0 / schema "0 USD" / `PreOrder` · **ORTA**
`schema.ts:74-77` → `price: "0", priceCurrency: "USD", availability: PreOrder`. `constants.ts:9-10` `APP_STORE_URL = null`, `GOOGLE_PLAY_URL = null` → ön sipariş mekanizması yok, `PreOrder` yanlış. EN yüzeyin geri kalanı ₺ kullanıyor (`hero-data.ts` EN "₺0", "₺18", "₺32"); `$` yalnızca 1 yerde.
**Karar:** `offers` lansmana kadar kaldırılır ya da locale'e göre TRY/USD + `ComingSoon`.

## X-07 · Canonical host uyuşmazlığı · **ORTA**
`constants.ts:1` ve `astro.config.mjs:7` → `https://www.cookrangeapp.com`; canlı site **www'suz** yanıt veriyor, `vercel.json` yönlendirme içermiyor → iki host aynı `@id`'lerle indekslenebilir.

## X-08 · `llms-full.txt` yanlış iddiaları LLM'lere servis ediyor · **YÜKSEK**
`src/pages/llms.txt.ts:23` aşamayı **doğru** beyan ediyor ✅, ama `llms-full.txt.ts:30-36` blog ve sözlük **gövdelerini** inline ediyor — "Türkiye'ye özel veritabanı", "2,4 saniye", "altı kişilik ortak seri" dahil. `robots.txt.ts:28-79` **18 AI tarayıcısına** `Allow: /` veriyor. Her uydurma rakam LLM alıntısı için optimize edilmiş durumda.

## X-09 · Canlı site kaynakla birebir aynı ✅
`cookrangeapp.com` yayında. `/`, `/fiyatlandirma`, `/ozellikler`, `/basin-kiti`, `/indir` kontrol edildi: **sapma 0**. Yani bu rapordaki her site bulgusu şu an canlıda geçerli.

## X-10 · Rakip hakkında kanıtsız iddialar · **YÜKSEK**
`comparisons/{tr,en}/cookrange-myfitnesspal-karsilastirmasi.md` — "Salon entegrasyonu | **Yok**" (mutlak, kaynaksız, tarihsiz), "MyFitnessPal ... **milyonlarca kullanıcısı**" (kaynaksız), "Food database | **Large, global, largely user-submitted**" (Cookrange'in kendi kaynağı bu — A-17). Rakip özelliği eklediği an tablo yanlış beyana dönüşür.
**Karar:** Tabloya tarih ve kaynak eklenir, mutlak olumsuzlar yumuşatılır, veritabanı satırı düzeltilir.

## X-11 · B2B etkinlik vaadi: "salona gitme sıklığını artırıyor" · **YÜKSEK**
`personas/tr/spor-salonlari.md:27-28` / `personas/en/gyms.md:27` — "Üyelerin birbirini salonda bulması ve squad'lar, **salona gitme sıklığını da artırıyor**." Kaynaksız, koşulsuz, mevcut zaman. Ürünün hiç kullanıcı verisi yok. Blogdaki aynı iddia kaynaklı (Wing & Jeffery 1999, Carron 1996), personada kaynaksız.
**Karar:** Kaynak eklenir ya da koşullu kipe çevrilir. Salona satılan bir sonuç vaadi olduğu için ayrıca sözleşme riski.

## X-12 · `yol-haritasi.astro:11` — "tamamlandı" · **ACİL**
"Beslenme planlama, barkod kaydı, salon check-in, squad'lar ve ilerleme analizi **tamamlandı**." / EN "**are complete**." Bu denetim beşinin **üçünde** temel eksik buldu (barkod → TR veritabanı yok; squad → altı sınırı ve ortak seri yok, büyük olasılıkla hiç çalışmıyor; ilerleme analizi → ağırlık metriği yok, kilo cihazda). Uygulamanın kendi `PROJECT_STATE.md`'si yüzeyin büyük kısmını "yazılmış ama doğrulanmamış" işaretliyor, 9 açık 🔥 blocker sayıyor.

## X-13 · Şirket künyesi boş, iki kaynak farklı duruş alıyor · **ACİL / lansman engelleyici**
`src/data/company.ts:38-52` → `legalName`, `address`, `mersisNumber`, `taxOffice`, `taxNumber`, `kvkkDataController`, `kvkkApplicationEmail`, `kepAddress` **hepsi null**, `isComplete: false`. Site eksikliği kabul edip `CompanyIncompleteNotice` bandı basıyor ✅; **uygulama aynı olguyu eksiksizmiş gibi sunuyor** (`assets/legal/kvkk_aydinlatma_tr.md:11-12` — "Burak Dereli tarafından işletilen Cookrange", uyarı bandı yok). Başvuru kanalı da ikili: site `contact@`, uygulama `privacy@`.

## X-14 · Saklama süreleri hiçbir kaynakta yok · **YÜKSEK**
`assets/legal/kvkk_aydinlatma_tr.md` — saklama süresi **bölümü bile yok**. Site `kvkk-aydinlatma-metni.astro:155-163` ve `gizlilik-politikasi.astro:162-167` — "eklenecektir". `faq/en/account-deletion.md` — "**will be published** ... once finalized". Tek rakam `privacy_policy_tr.md:68-70` "30 gün" ve o da hesap silme bulgusuyla çelişiyor.

## X-15 · Marka sesi ihlalleri (birinci çoğul şahıs) · **DÜŞÜK**
`docs/TONE-OF-VOICE.md:17-18` "Biz size X sunuyoruz" kalıbını yasaklıyor. İhlaller: `ekip.astro:33` "tercih ediyoruz", `:57` "planlıyoruz … paylaşacağız"; `yol-haritasi.astro:32` "Nereden nereye gidiyoruz", `:50` "Yönümüzü neyle ölçüyoruz"; `blog/tr/arkadas-grubuyla-seri-tutmak-neden-ise-yarar.md:5` "anlatıyoruz". Ayrıca hitap tutarsızlığı: `personas/tr/spor-salonlari.md:32` "ulaşabilirsiniz" ↔ `kocular.md:31` "ulaşabilirsin".

## X-16 · Test Modu son kullanıcıya açık ve sahte veri gösteriyor · **YÜKSEK**
`lib/screens/profile/settings_screen.dart:1191-1213` — "Developer / Test Modu" anahtarı `kDebugMode` **ve** `isAdmin` korumasından yoksun. Açıldığında salon keşfi, koç keşfi, salon liderlik tablosu, öğün planı, alışveriş listesi, yemek günlüğü ve yemek veritabanı `TestDataLibrary` sahte verisi döndürüyor. Salon pilotunda bir üye bunu açarsa gerçek gibi görünen uydurma veri görür.
**Ek olarak:** program pazaryerindeki tek içerik, **her istemcinin açılışta yazdığı 3 demo program** (`app_initialization_service.dart:335`) — pazaryerinde gerçek olmayan içerik.


---

# EK BULGULAR — UYGULAMADA VAR, KONTROL LİSTESİNDE YOK
> Kontrol listesi bir taban, tavan değildi. Aşağıdaki 14 yüzey uygulamada bulundu; 12'si çakışma üretiyor (9 TİP B, 1 TİP A-TERS, 2 TİP D). Her satırın kanıtı ve aksiyonu `01-OZELLIK-ENVANTERI.xlsx` içinde `EK-01`…`EK-14` satırlarında. Çapraz bulgular aynı dosyada `X-01`…`X-17`.

| ID | Yüzey | Uygulama kanıtı | Site | Tip | Aksiyon |
|---|---|---|---|---|---|
| EK-01 | Haftalık yapay zekâ özeti | `weekly_recap_screen.dart` + `ai.weekly_recap_*` 18 anahtar | ANILMIYOR | TİP B | Özellik sayfasına eklenmesi değerlendirilir |
| EK-02 | Sesli asistan | `lib/core/widgets/voice_assistant_overlay.dart` + `speech_to_text` | ANILMIYOR | TİP B | Madde 18 ile birlikte siteye eklenir |
| EK-03 | Pişirme modu | `lib/screens/recipe/cooking_mode_screen.dart` + wakelock | ANILMIYOR | TİP B | Marka anlatısına uygun; siteye eklenir |
| EK-04 | Plan geçmişi ve geri yükleme | `meal_plan_history_screen.dart`; `meal_compare.*` 11 anahtar | ANILMIYOR | TİP B | "Hiçbir ay silinmiyor" anlatısını destekler |
| EK-05 | Hidrasyon takibi ve su hatırlatıcı | `water_reminder.*` 8 anahtar, birim testi var; veri Hive `hydration_box` | Hero'da veri olarak var, özellik olarak yok | TİP B | Siteye eklenir; kalıcılık sorunu S3 kapsamına alınır |
| EK-06 | Birebir ve grup sohbeti | `chat.*` 23 anahtar | ANILMIYOR | TİP B | Madde 34 "Akış" bölümüne eklenir |
| EK-07 | "Signal" dürtme | `signal.*` 10 anahtar | ANILMIYOR | TİP B | Madde 34 ile birlikte anlatılır |
| EK-08 | Başarım rozetleri | `achievements.*` 15 anahtar; seri taşları 7/14/30/60/100/365 | Seri anlatılıyor, rozetler anlatılmıyor | TİP B | Değerlendirilir |
| EK-09 | Onboarding v2 — 14 sayfa | 14 sayfa, BMI + kalori + makro + hedef tarihi raporuyla bitiyor | `nasil-calisir.astro` "yedi adım" / "beş adım" diyor | **TİP D** | Site adım sayısı gerçek akışa göre düzeltilir ya da sayı verilmez |
| EK-10 | Rıza merkezi + DSAR + veri ihracı | `data_export_service.dart:18-36`, `:42-68` (24 kaynak); `functions/account.js:48` | `faq/tr/veri-disa-aktarma.md` "düğme yok" diyor — **YANLIŞ** | **TİP A-TERS** | SSS düzeltilir: "Ayarlar → Verilerini Dışa Aktar" (ACİL) |
| EK-11 | Salon başvuru hattı | `gym.docs_count`, `gym.phone_otp_hint`, `gym.app_pending_step2` — 2 belge, 6 haneli OTP, 2-5 iş günü | ANILMIYOR | TİP B | Salon sayfasına eklenir — B2B dönüşüm için değerli |
| EK-12 | Referans ve komisyon kazancı | `functions/economy.js:21` — kişi/koç referansı ₺5 | `faq/tr/referans-linki.md` sıra hızlandırmadan bahsediyor | **TİP D** | İki farklı mekanizma; SSS'de netleştirilir ya da iddia kaldırılır |
| EK-13 | Admin paneli | 11 ekran, `admin.*` 324 anahtar | ANILMIYOR | TEMİZ | İç araç; aksiyon gerekmiyor |
| EK-14 | Bakım modu / zorunlu güncelleme / hesap askıya alma | `route_guard.dart:125` — çalışan tek kill-switch; `account_suspended.*` 14 anahtar | ANILMIYOR | TEMİZ | N2 için referans desen |

---

# X-17 · KULLANICI KÖK DOKÜMANI HERKESE AÇIK VE PII TAŞIYOR · **ACİL**
> Doğrulama turunda ana tabloda satırı olmadığı görülüp eklendi. Ayrıntı: 06 numaralı dosya C1, yol haritası N1.

**Uygulama: RİSK.** `firestore.rules:113-115` → `match /users/{uid} { ... allow read: if isAuthenticated();` (kural yorumu: "Users can read any profile"). Kök dokümana yazılanlar: `email` (`firestore_service.dart:134`, `:277`, `:309`), `login_ips` (`:142`, `:628` — `FieldValue.arrayUnion([ip])`), `fcm_token` (`push_notification_service.dart:408`), ayrıca `login_devices`, `login_device_os`, `timezone`, `device_locale`. `target_weight` ve `main_goal` da burada: `onboarding_provider.dart:210` kod yorumu bunları açıkça *"Non-PII fields — stored on the public users/{uid}.onboarding_data map"* diye niteliyor (`:221`). Karşılaştırma: `_toPrivateMap()` (`:232-251`) yalnızca `personal_info`, `disliked_foods`, `allergies`, `dietary_restrictions` alanlarını `private/nutrition` altına gönderiyor — ayrım kurulmuş ama hedef kilo ve hedef public tarafta bırakılmış.

**Site: ÇELİŞKİLİ.** `guvenlik.astro:17-19` — "veri erişiminin gerçek hayattaki ilişkilere göre sınırlanması" ve "kimse bir başkasının vücut verisine erişemez".
**Yasal metin: EKSİK.** `assets/legal/kvkk_aydinlatma_tr.md:21-22` işlenen veriler listesinde IP adresini hiç saymıyor.
**Ekip kararına aykırı:** `CLAUDE.md` §5.5 (ADR-009) hedef kilonun kök dokümanda tutulmasını yasaklıyor.

**Uygulanan kural: K1.** **Karar:** Alanlar owner-only alt dokümana taşınır, `firestore.rules:115` daraltılır. Efor **S**. **Yol haritası ŞİMDİ kovası N1 — ilk salon pilotunun engelleyicisi.**

**Düzeltme metni:**
> Hesap dokümanında yalnızca görünen ad ve profil fotoğrafı tutulur. E-posta adresin, giriş IP kayıtların, cihaz bilgin ve bildirim token'ın yalnızca senin okuyabildiğin ayrı bir alanda saklanır. Hedef kilo ve hedef bilgin de aynı korumalı alana taşınmıştır.
