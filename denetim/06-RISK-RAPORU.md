# 06 — RİSK RAPORU

Cookrange · 4 Ağustos 2026
Üç başlık: **yanıltıcı beyan** · **sağlık iddiası** · **veri ve mahremiyet**
Her risk: bulunduğu yer · neden risk · önerilen düzeltme metni

**Bu bir hukuki görüş değil.** Mevzuat yorumu gerektiren yerler açıkça **DOĞRULANAMADI** işaretlendi ve hukuk müşaviri teyidi gerektiriyor. Olgusal tespitler (kodun ne yaptığı, metnin ne dediği) kesindir ve kanıtlıdır.

---

# A. YANILTICI BEYAN RİSKİ
> Uygulamanın yapmadığı her site iddiası. Türkiye'de 6502 sayılı Tüketicinin Korunması Hakkında Kanun ve Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği kapsamında Reklam Kurulu denetimine tabidir. Ürün henüz satışta olmadığı için bugünkü maruziyet sınırlı — **ama bekleme listesi topluyor ve basın kiti dağıtıyor.**

## A1 · "Türkiye barkod veritabanı" — 20+ dosyada, yayınlanmış sürüm notu dahil · **ACİL**
**Yer:** `src/pages/ozellikler/beslenme-ve-planlama.astro:33` · `src/content/changelog/tr/v0-9-6.md` · `src/content/faq/{tr,en}/barkod-veritabani | barcode-database` · `src/content/comparisons/{tr,en}/cookrange-myfitnesspal-*` · `src/pages/llms-full.txt.ts` (gövdeyi inline ediyor) · toplam 20+ dosya
**Gerçek:** `lib/core/services/barcode_lookup_service.dart:45-46` → `world.openfoodfacts.org/api/v0`, küresel endpoint, TR filtresi yok. `firestore.rules` ve `firestore.indexes.json` içinde `products` koleksiyonu **hiç yok**; önbellek yalnızca bellek içi (`:49`). *Kapsam: eksik olan barkodla eşleşen TR paketli ürün kaynağıdır; TR yemek ve il/ilçe verisi uygulamada mevcuttur.*
**Neden risk:** Ürünün ana farklılaştırıcısı olarak sunulan bir veri varlığı mevcut değil. İki katmanlı risk: (a) tüketiciye yanlış beyan, (b) `comparisons` sayfasında MyFitnessPal'ı "küresel, kullanıcı katkılı" diye nitelendirirken **Cookrange tam olarak o veritabanını kullanıyor** — yani rakip aleyhine kanıtsız karşılaştırma aynı anda kendi ürünü hakkında da yanlış. Ayrıca `robots.txt.ts:28-79` 18 yapay zekâ tarayıcısına açık: iddia dil modellerine servis ediliyor ve alıntılanıyor.
**Önerilen düzeltme metni:**
> Barkodu okutursun. Ürün Open Food Facts veritabanından çekilir; kalori ve makro bilgisi kaydına eklenir. Türkiye market ürünlerinde kapsama oranını ölçüyoruz, sonucu burada yayımlayacağız.

## A2 · Sponsorlu ürün katmanının tamamı — bir sayfa, bir hero sahnesi, iki SSS, bir KVKK maddesi · **ACİL**
**Yer:** `src/pages/ozellikler/sponsorlu-urunler.astro` (sayfanın tamamı) · `src/components/hero/hero-data.ts:705-706, 854` · `src/content/faq/tr/sponsorlu-urunler-{reklam-mi,premium}.md` + EN · `src/pages/legal/kvkk-aydinlatma-metni.astro:143-147`
**Gerçek:** `sponsor` kelimesi `lib/`, `functions/`, `tr.json`, `en.json`, `firestore.rules` genelinde **0 eşleşme** (~115k satır).
**Neden risk:** Site yalnızca özelliğin varlığını değil, **kurallarını da** ilan ediyor: sıralama ölçütü ("±%10 kalori, en az %90 protein"), susturma anahtarı, indirim kodu, dokunulmamış planda sıfır sponsorlu öğe. Somut mekanizma beyanı, muğlak iddiadan daha yüksek risk taşır — çünkü doğrulanabilir ve doğrulandığında yanlış çıkıyor. Ayrıca bu katman `hero-data.ts:705`'te **ücretsiz katmanın finansman gerekçesi** olarak sunuluyor; yani iş modeli beyanı da uygulanmamış bir özelliğe dayanıyor.
**Önerilen düzeltme metni:**
> Cookrange'in temel özellikleri ücretsiz. Bunu sürdürülebilir kılacak modeli henüz açıklamadık. Açıkladığımızda kuralları da yayımlayacağız. Şu an uygulamada sponsorlu ürün önerisi bulunmuyor.

## A3 · "12.400 sütun" — sıfır kullanıcılı üründe ölçek iddiası · **ACİL**
**Yer:** `src/components/hero/hero-data.ts:699`, `:782`, `:853` — ana sayfa eyebrow, TR ve EN
**Gerçek:** Kaynağı yok. Sitenin kendi sözlüğünde "sütun" = bir kullanıcının veri sütunu. Render edilen gerçek `.cr-column` sayısı **12**. Ürün mağazada değil, gerçek kullanıcısı yok.
**Neden risk:** Hemen altında "Üyeler, koçlar ve salonlar aynı zeminde" yazıyor — satır **kullanıcı sayısı gibi okunuyor**. `docs/TONE-OF-VOICE.md:19` bu tür sosyal kanıtı kendi kuralıyla yasaklıyor: *"Uydurma sosyal kanıt: kullanıcı sayısı, yıldız puanı, 'binlerce kişi' gibi ifadeler — gerçek veri yoksa hiç kullanılmaz."*
**Önerilen düzeltme metni:**
> Rakam kaldırılır. Eyebrow yalnızca "Tek bir altyapı" (TR, `:782`) / "One substrate" (EN, `:699`) olarak kalır; statik çip (`:853`) tamamen çıkar.

## A4 · `yol-haritasi.astro:11` — "tamamlandı" · **ACİL**
**Yer:** `src/pages/yol-haritasi.astro:11` + `src/pages/en/roadmap.astro:11`
**Şu anki metin:** "Beslenme planlama, barkod kaydı, salon check-in, squad'lar ve ilerleme analizi **tamamlandı**." / "are complete."
**Gerçek:** Beşin üçünde temel eksik — barkod → TR paketli ürün kaynağı yok · squad → altı sınırı yok, ortak seri yok, katılma yolu DOĞRULANAMADI · ilerleme analizi → ağırlık metriği yok, günlük kilo serisi yalnızca cihazda. Uygulamanın kendi `PROJECT_STATE.md`'si **9 açık blocker** sayıyor ve yüzeyin büyük kısmını "yazılmış ama doğrulanmamış" işaretliyor.
**Neden risk:** Yol haritası sayfası yatırımcı, basın ve salon işletmesinin ilerlemeyi ölçtüğü yer. "Tamamlandı" beyanı en yüksek güven yükü taşıyan ifade. Aynı sayfa `:52` hâlâ "barkod veritabanı doğruluğu, salon check-in gecikmesi ve Cookrange AI önerilerinin isabet oranı"nı **ölçülecek** diye sayıyor — sayfa kendisiyle çelişiyor.
**Önerilen düzeltme metni:**
> Beslenme planlama, barkod kaydı ve salon check-in çalışıyor. Squad'lar ve ilerleme analizi üzerinde çalışmaya devam ediyoruz. v0.9.6 dahili alfa; ölçmediğimiz hiçbir şeye "tamamlandı" demiyoruz.

## A5 · Basın kiti boilerplate'i — "düzenlenmeden kullanılması tercih edilir" · **ACİL**
**Yer:** `src/pages/basin-kiti.astro:52-58` (orta), `:61-72` (uzun) + `src/pages/en/press.astro:52-54`, `:60-67`
**Üç ayrı hata:**
1. `:64` "alerjenlerine **ve bütçesine** göre üretilir" — bütçe özelliği yok (`budget|bütçe|cost|price` → 0 eşleşme). **Bu iddianın tek kaynağı basın kiti.**
2. `:66` "tek tek atıştırmalıklar da **serbest metinle düzenlenebilir**" — plan/öğün serbest metinle düzenlenemiyor (`prompt_service.dart`'ta 3 prompt, kullanıcı metni parametresi yok). Yine tek kaynak basın kiti.
3. `:52-58` "şu anda **beta öncesi** aşamadadır" — aynı sayfa `:23` ve `:69` "v0.9.6 dahili alfa" diyor. Boilerplate kendi sayfasıyla çelişiyor. EN'de aynı hata: "pre-beta" ↔ "internal alpha".
**Neden risk:** Sayfa `:38` "Aşağıdakiler doğrudan kopyalanıp kullanılabilir; **düzenlenmeden kullanılmaları tercih edilir**" diyor. Gazeteci olduğu gibi basar; yanlış beyan üçüncü taraf yayında görünür ve geri alınamaz.
**Önerilen düzeltme metni (orta boilerplate, TR):**
> Cookrange, gününü öğün, antrenman, salon giriş-çıkışı ve serilerden oluşan bir veri sütunu gibi okuyan bir yapay zekâ beslenme ve fitness sistemidir. 2025 yılında Antalya'da kurulmuştur ve şu anda v0.9.6 dahili alfa aşamasındadır.

## A6 · Aşama enflasyonu — 6 farklı ad, en sık kullanılanı "private beta" · **YÜKSEK**
**Yer:** "dahili alfa / internal alpha" 14 yerde · **"özel beta / private beta" 16 yerde** (8 TR + 8 EN blog) · "beta öncesi / pre-beta" 2 (basın kiti) · "kapalı beta / closed beta" 2 · "bekleme listesi aşaması" 2 · "özel erken erişim" 2. Ayrıca `pubspec.yaml:4` = `1.0.0+1` ↔ `README.md:17` = v0.9.6.
**Neden risk:** Alfa ürünü kendini beta gibi anlatıyor — olgunluk beyanının şişirilmesi. Sayısal üstünlük "private beta"da olduğu için bir dil modeline "Cookrange hangi aşamada?" diye sorulduğunda cevap "private beta" olur. `robots.txt` 18 AI tarayıcısına açık; bu yanlış cevap ölçeklenerek yayılıyor.
**Önerilen düzeltme metni:**
> Tek kanonik ad: "v0.9.6 dahili alfa" / "v0.9.6 internal alpha". Diğer beş ifade tüm yüzeylerden kaldırılır. `pubspec.yaml` sürümü 0.9.6'ya çekilir.

## A7 · Rakip hakkında kanıtsız iddia · **YÜKSEK**
**Yer:** `src/content/comparisons/{tr,en}/cookrange-myfitnesspal-karsilastirmasi.md:14`, `:23-25`
**Üç satır:** "Salon entegrasyonu | **Yok**" (mutlak, tarihsiz, kaynaksız) · "MyFitnessPal ... **milyonlarca kullanıcısı**" (kaynaksız) · "Günlük hedef | **Genellikle sabit veya manuel güncellenir**"
**Neden risk:** Karşılaştırmalı reklam, Ticari Reklam Yönetmeliği'nde ayrı düzenlenmiş bir alandır; rakip hakkında olumsuz mutlak iddia ispat yükü doğurur. Rakip özelliği eklediği an satır yanlış beyana dönüşür. Tarih ve kaynak yokluğu bu riski kalıcı kılıyor. *(Karşılaştırmalı reklamın somut koşulları hukuk müşaviri teyidi gerektirir → **DOĞRULANAMADI**.)*
**Önerilen düzeltme metni:**
> Salon entegrasyonu | Bu karşılaştırmanın yapıldığı tarihte (Ağustos 2026) belgelenmiş bir salon check-in özelliği bulunamadı | QR check-in, arkadaş bildirimleri

## A8 · Premium ekranındaki beş yanlış vaat — **ödeme alan ekranda** · **ACİL**
**Yer:** `assets/localization/tr.json` → `premium.perk_meal_plans` "Sınırsız Plan" · `premium.description` "Reklamsız deneyim" · `ai.paywall_feature2/3/4`
**Gerçek:** 20/gün (`functions/index.js:30-31`) · `pubspec.yaml` içinde `ads|admob|applovin|unity|ironsource` → **0 paket**, yani kaldırılacak reklam yok · rate limit iki kademede aynı; repoda `priority` tek eşleşmesi `functions/index.js:618` FCM bildirim önceliği · "gelişmiş öğün özelleştirme" özelliği yok · `nutritionAnalytics => true` (ücretsiz). *Doğru olan tek satır:* `ai.paywall_feature1` = "Günde 20 AI kullanımı"
**Neden risk:** Bu, sitedeki bir pazarlama cümlesi değil, **satın alma ekranındaki ürün tanımı**. İki ayrı maruziyet: (a) tüketici hukuku — ödenen şeyin yanlış tanımlanması, (b) App Store ve Google Play inceleme reddi (her iki mağaza da abonelik faydalarının doğru listelenmesini şart koşuyor). Site burada uygulamadan **daha dürüst** (`fiyatlandirma.astro:16-20` üç doğru madde sayıyor) — K2 uyarınca sitenin dili uygulamaya taşınır.
**Önerilen düzeltme metni:**
> "Sınırsız Plan" → "Günde 20 yapay zekâ üretimi"
> "Reklamsız deneyim" → "Yapay zekâ üretim hakkın artar"
> "Öncelikli AI işleme", "Gelişmiş öğün özelleştirme", "Detaylı beslenme analitiği" → kaldırılır

## A9 · Salona satılan "doluluk" özelliği yok · **ACİL**
**Yer:** `src/pages/ozellikler/salon-ekosistemi.astro:39` · `guvenlik.astro:31` · `fiyatlandirma.astro:10` · `src/content/personas/{tr,en}/spor-salonlari | gyms.md:25-26`
**Gerçek:** `occupancy|capacity|doluluk|crowd|live_count|currentlyIn` → `lib/` genelinde **0 eşleşme**; localization dosyalarında da 0. Check-out kaydı bile yok, dolayısıyla "içeride kaç kişi var" hesaplanamaz. Var olan iki şey: 60 günlük yoğun saat ısı haritası ve son 7 günün gün bazlı devam grafiği (`gym_service.dart:453` `getWeeklyAttendanceStream`, yalnızca salon sahibine görünür). İkisi de geçmişe dönük; anlık doluluk değil.
**Neden risk:** Bu bir B2B vaadi. Salon pilotu bu özellik beklentisiyle sözleşme yaparsa ifa edilemeyen taahhüt doğar. Tüketici tarafında da "her zaman ücretsiz" listesinde yer alıyor.
**Önerilen düzeltme metni (ikinci çoğul):**
> Salonunuz kendi check-in sayısını ve son 60 günün yoğun saat desenini görür. Anlık doluluk sayacı henüz yok.

## A10 · Ölçüm yapılmamış performans rakamları · **YÜKSEK**
**Yer:** "~2,4 saniye" 20+ yerde · "34 ürün" ve "7 reyon" 8 sayfada · "1.000 hesaplık kohort" KVKK metninde ve 1 SSS'de
**Gerçek:** Dördünün de kaynağı yok. `docs/TONE-OF-VOICE.md:14` "2,4 saniye"yi **iyi somut sayı örneği** olarak kural metnine gömmüş — yani uydurma rakam marka kuralının içine yerleşmiş.
**Neden risk:** Somut rakam, muğlak sıfattan daha ikna edici olduğu için daha yüksek ispat yükü taşır. Dördü de mock ekran değerinden metne geçmiş.
**Önerilen düzeltme:** Marka sesi kurallarına yeni bir madde eklenir (03 numaralı dosya, kural 9): *"Metne giren her sayı kod, ölçüm ya da yayınlanmış kaynak ile gösterilebilir olmalı. Tasarım mock'undan gelen sayı metne girmez."*

---

# B. SAĞLIK İDDİASI RİSKİ
> Türkiye'de Reklam Kurulu, ayrıca Sağlık Bakanlığı'nın sağlık beyanı düzenlemeleri kapsamında. **Genel hüküm: sitenin bu konudaki hijyeni iyi.** Yasaklı türde sonuç vaadi bulunamadı; feragatnameler beş ayrı yerde güçlü ifadeyle mevcut. Aşağıdaki maddeler kalan açıklar.

## B0 · Önce olumlu tespit
"kilo verirsin", "garanti", "yakar", "hızlandırır", "detoks", "klinik olarak kanıtlanmış", "dönüştürür" → **pazarlama sayfalarında 0 eşleşme.** "Garanti" ürün sayfalarında yalnızca **reddetmek için** kullanılıyor. Feragatnameler: `yemek-plani-uygulamasi.astro:147`, `ai-yemek-plani-olusturma.astro:130-134`, `faq/{tr,en}/diyetisyen-yerine-gecer-mi | medical-disclaimer`, `legal/kullanim-kosullari.astro:140`, `blog/tr/alerjen-filtreleme...md:68`. Blogdaki tüm yüzdeler PubMed / JAMA / ScienceDirect linkleriyle verilmiş. **Bu, denetimin en güçlü olumlu bulgusudur ve korunmalıdır.**

## B1 · `applicationCategory: "HealthApplication"` ↔ "sağlık uygulaması değildir" · **YÜKSEK**
**Yer:** `src/lib/schema.ts:68` (her sayfaya gömülüyor) ↔ `ai-yemek-plani-olusturma.astro:132` "Cookrange bir tıbbi cihaz ya da **sağlık uygulaması değildir**" / `en/ai-meal-plan-generator.astro:131` "is not a medical device or **a health application**"
**Neden risk:** Makine okunur beyan ile insan okunur hukuki feragat birbirinin tam tersi. Bir uyuşmazlıkta karşı taraf, ürünün kendi yapılandırılmış verisinde kendini sağlık uygulaması ilan ettiğini gösterebilir. KVKK açısından ayrıca özel nitelikli veri işleme iması taşır. Uygulama içi mağaza paneli de "Kategori | Sağlık ve fitness" gösteriyor.
**Önerilen düzeltme:** `applicationCategory: "LifestyleApplication"`.

## B2 · Feragatsız kilo projeksiyonu çipleri · **YÜKSEK**
**Yer:** `src/components/hero/hero-data.ts:851` — statik yedek çipleri: "+30g 76.9 kg", "+60g 75.8 kg", "+90g 75.1 kg"
**Neden risk:** Anlatı içinde bu üç değerin yanında güçlü bir feragat var ("kesikli çizilir çünkü bu bir söz değil, bir öngörüdür" — `:774`). Ama **statik çip hâlinde feragat yok**: çıplak üç kilo hedefi olarak duruyor. Kilo sonucu vaadi, sağlık beyanı riskinin çekirdeğidir. Üstelik uygulamada bu grafik hiç yok ve bu üç değer kodda geçmiyor.
**Önerilen düzeltme metni:**
> Çipler kaldırılır. Projeksiyon yalnızca feragatiyle birlikte anlatılır: "30, 60 ve 90 gün için bir tahmin yazar. Tahmin bir söz değil."

## B3 · Kaynaksız davranışsal etkinlik iddiaları · **YÜKSEK**
**Yer (en riskli):** `src/content/personas/tr/spor-salonlari.md:27-28` / `en/gyms.md:27` — "Üyelerin birbirini salonda bulması ve squad'lar, **salona gitme sıklığını da artırıyor**." / "**also increases how often people actually show up**."
**Diğerleri:** `ozellikler/topluluk-ve-squad.astro:39-41` — "davranış değişikliği literatüründe hesap verebilirlik ortağı etkisi ... **genellikle yalnız çabalardan daha güçlü çalışan**" (adı verilmemiş araştırma) · `hero-data.ts:754` — "üçüncü haftanın alışkanlığı **öldürmemesinin nedeni** de bu" (mutlak nedensellik) · `:769` — "Elde tutma stratejisinin tamamı bu" · `glossary/tr/makro-takibi.md` — "bu dağılım, **kas kütlesi korunumu ile tokluk hissi gibi sonuçları etkiler**" (kaynaksız fizyolojik mekanizma)
**Neden risk:** Persona iddiası koşulsuz, mevcut zaman ve **salona satılan bir iş sonucu vaadi** — ürünün hiç kullanıcı verisi yok. Blogdaki aynı iddia kaynaklı (Wing & Jeffery 1999, Carron 1996); personada kaynak düşmüş. Sonuç: sitenin en niteliksiz etkinlik iddiası, en ticari sayfada duruyor.
**Önerilen düzeltme metni (ikinci çoğul):**
> Davranış değişikliği araştırmaları, hesap verebilirlik ortaklığının program tamamlama oranlarını yükselttiğini gösteriyor (Wing & Jeffery, 1999). Cookrange bu mekanizmayı salon içine taşıyor. Kendi üye verinizle etkiyi pilot süresince ölçeceğiz.

## B4 · Blog başlıklarında sonuç dili · **ORTA**
**Yer:** `src/content/blog/tr/kalori-saymak-neden-tek-basina-yetmiyor.md` — anahtar kelime "**kalori sayarak zayıflama** neden işe yaramıyor"; `blog/tr/makro-takibi-nasil-yapilir-kimin-icin-gerekli.md:38` "**kilo verse bile** bu kaybın önemli bir kısmını kas kütlesinden verebilir"
**Neden risk:** İçerik metni dengeli ve kaynaklı; risk **başlık ve anahtar kelime** düzeyinde. Arama sonucunda ve LLM alıntısında bağlamdan koparak görünüyor. `docs/TONE-OF-VOICE.md:12` kendi kuralı: *"bir modelin bağlamdan kopardığı ilk cümle hâlâ doğru olmalı."*
**Önerilen düzeltme:** Anahtar kelime hedefi korunur, ama yazının ilk cümlesi bağlamdan koptuğunda da doğru olacak şekilde yeniden yazılır.

## B5 · Sağlık verisi işleme iddiası koşulsuz kurulmuş · **YÜKSEK**
**Yer:** `src/content/personas/tr/kilo-yonetimi.md:26` — "telefonunun **hareket verisini okuyarak** günlük hedefi güncelliyor"
**Neden risk:** İki katmanlı. (a) Özellik yok — uyum motoru mevcut değil. (b) Hareket verisi özel nitelikli kişisel veridir; koşulsuz mevcut zamanla "okuyor" demek, açık rıza mekanizmasının kurulduğu iddiasını da içerir. Sitenin kendi `docs/LEGAL-REVIEW.md:39-41` maddesi sağlık verisi açık rızasının **doğrulanmadığını** söylüyor.
**Önerilen düzeltme metni:**
> Yürüdüğün mesafe ve yakılan kalori günün üstünde görünür.

---

# C. VERİ VE MAHREMİYET RİSKİ
> Sitede verilen mahremiyet sözü ile uygulamanın gerçek izin modeli karşılaştırıldı. **Bu bölüm denetimin en ağır bulgularını taşıyor.** Olgusal tespitler kanıtlı; KVKK sonuçları hukuk müşaviri teyidi gerektirir.

## C1 · Kullanıcı dokümanı e-posta, IP geçmişi ve hedef kilo taşıyor ve herkese açık · **ACİL**
**Yer:** `firestore.rules:115` → `allow read: if isAuthenticated()` · içeriği: `lib/core/services/firestore_service.dart:134` (`'email'`), `:141` (`'login_ips': FieldValue.arrayUnion([...ip_address])`) · `lib/core/services/push_notification_service.dart:407-410` (`fcm_token`) · `lib/core/providers/onboarding_provider.dart:216-217` (`target_weight`, `main_goal` — kodun yorumu bunları "Non-PII" diyor)
**Neden risk:** Her oturumlu kullanıcı, her başka kullanıcının e-posta adresini, giriş IP geçmişini, cihaz modelini, push token'ını ve hedef kilosunu okuyabiliyor. `guvenlik.astro:17-19` "veri erişiminin gerçek hayattaki ilişkilere göre sınırlanması" ve "kimse bir başkasının vücut verisine erişemez" diyor. Uygulamanın kendi `CLAUDE.md` §5.5 (ADR-009) hedef kilonun kök dokümanda tutulmasını **yasaklıyor** — yani bu kendi kararına aykırı bir uygulama hatası. `assets/legal/kvkk_aydinlatma_tr.md:21-22` işlenen veriler listesinde IP adresini hiç saymıyor.
**Önerilen düzeltme metni:**
> Hesap dokümanında yalnızca görünen ad ve profil fotoğrafı tutulur. E-posta adresin, giriş IP kayıtların, cihaz bilgin ve bildirim token'ın yalnızca senin okuyabildiğin ayrı bir alanda saklanır. Hedef kilo ve hedef bilgin de aynı korumalı alana taşınmıştır.
**Kod aksiyonu:** 04 numaralı dosya, ŞİMDİ kovası N1.

## C2 · Koç yapay zekâ raporu: onaysız, yurt dışına aktarım · **ACİL**
**Yer:** `lib/screens/coach/coach_client_detail_screen.dart:100-152`, özellikle `:119-125`:
```dart
final prompt = 'You are a fitness coach assistant. Generate a brief progress report for '
    'my client $clientName based on: streak=$streak days, '
    'last logged ${daysSince == 999 ? "never" : "$daysSince days ago"}, ...';
final result = await AIService().generateJson(prompt: prompt, ...);
```
**Neden risk:** Tek kapı `AIService().isConfigured` (`:102`). `ConsentService().hasConsent(...)` çağrısı **yok**; `consent`, `permission`, `isPremium` kelimelerinin hiçbiri dosyada geçmiyor. `ConsentPurpose` kümesinde koç erişimi diye bir amaç da yok (`lib/core/models/consent_model.dart:11-19`). Gönderilen veri **danışana** ait, işlemi tetikleyen **koç**, alıcı OpenRouter — **yurt dışı** (`docs/COMPLIANCE.md:186`). Danışan bu işlemeyi ne görüyor ne durdurabiliyor. Bağ kurma danışanın kendi eylemiyle başlıyor (`coach_service.dart:248-267`) — yani *ilişkiye* rıza var, *yapay zekâ işlemeye ve aktarıma* yok. `faq/tr/koc-ve-arkadas-erisimi.md` "yalnızca senin ilerlemeni okur" diyor ve aktarımı hiç anmıyor. `docs/COACH_ECOSYSTEM.md:87-93` bunu bir *yükümlülük* olarak yazmış — okuyan uygulanmış sanabilir.
**Önerilen düzeltme metni:**
> Koçun, ilerleme raporu üretmek için adını ve seri bilgini yapay zekâ sağlayıcımıza gönderebilir. Bu, yurt dışında işlenen bir aktarımdır. Ayarlar → Rıza Merkezi'nden koç raporlarını kapatabilirsin; kapattığında koç bu özelliği kullanamaz.
**Kod aksiyonu:** Kısa vadede N2 (bayrakla kapat), kalıcı çözüm S2 (rıza akışı).

## C3 · Salon bireysel üye verisini okuyor ve CSV olarak indiriyor · **ACİL**
**Yer:** `firestore.rules:425-433` (salon sahibi tüm `members`), `:467-475` (tüm `checkins`) · `lib/core/models/checkin_model.dart:52-58` (`uid`, `display_name`, `photo_url`, `timestamp`, `method`) · `lib/core/services/gym_analytics_service.dart:99-104` (**14 gündür gelmeyenlerin isim listesi**), `:106-116` (aylık top 5), `:137-170` (**CSV başlığı: `uid,name,joined_at,total_checkins,last_checkin,tier` — fotoğraf CSV'de yok, uygulama içi analitik ekranında görünüyor: `gym_analytics_screen.dart:755-758`, `:911-914`**) · tetikleyici `lib/screens/gym/gym_analytics_screen.dart:131-135`. Ek bulgu: `exportCsv` check-in okuması `.limit()` ve tarih filtresi olmadan **tüm** koleksiyonu çekiyor (`:139-140`), oysa `computeAnalytics` 60 günle sınırlı (`:41-45`)
**Neden risk:** `faq/tr/salon-veri-erisimi.md` "**Erişemez.** Bir salon yalnızca kendi **toplam** doluluğunu, yoğun saatlerini ve check-in sayısını görür" diyor; `guvenlik.astro:31-32` "bireysel kullanıcı verisine erişimleri yoktur" diyor. İkisi de yanlış. Site KVKK metni (`kvkk-aydinlatma-metni.astro:135`) salonlara "yalnızca giriş-çıkış doğrulaması amacıyla, **sınırlı veri**" gittiğini beyan ediyor — CSV ihracı bu beyanın kapsamını aşıyor. Salonlarla veri paylaşım sözleşmesi / DPA ihtiyacı `docs/LEGAL-REVIEW.md:40-41` içinde hâlâ açık madde. Ayrıca CSV `.limit()` olmadan tüm koleksiyonu okuyor.
**Önerilen düzeltme metni:**
> Salon işletmesi, üye listesini ve check-in kayıtlarını görünen ad düzeyinde görür. Beslenme geçmişine, kilo verine ve ölçümlerine erişemez. Salon, devam istatistiklerini dosya olarak indirebilir; bu dosyada adın ve check-in tarihlerin yer alır.
**Not:** Vücut verisi koruması **gerçekten çalışıyor** ✅ (`firestore.rules:207-211` `private/{docId}` owner-only; `gym_member_model.dart:12-17` 5 alan, hiçbiri sağlık verisi değil). Yanlış olan "yalnızca toplam veri" kısmı.

## C4 · Rıza geri çekme hiçbir kod yolunu değiştirmiyor · **ACİL**
**Yer:** `lib/core/services/consent_service.dart:73-85` (`hasConsent`) — tüm `lib/` ağacında yalnızca `:92` (`applyCollectionConsent`) tarafından çağrılıyor. Rıza Merkezi 7 amaç için açma/kapama sunuyor (`lib/screens/profile/consent_center_screen.dart:53`).
**Neden risk:** `healthData`, `location`, `aiProcessing`, `crossBorderTransfer`, `notifications` rızası geri çekildikten sonra öğün planı üretimi, profil bağlamının OpenRouter'a gitmesi ve GPS check-in **aynen çalışıyor**. Rıza kaydından uygulanan tek amaç `analytics`. **Doğrulama turu notu:** iki kullanım anı kapısı var ama ikisi de rıza kaydını okumuyor — `food_scan_screen.dart:233-241` (yapay zekâ fotoğrafı, yerel `SharedPreferences` bayrağı; kabul edilince `setConsent` **yazıyor**) ve `gym_discovery_screen.dart:134-151` (OS konum izni). Yani sorun "kontrol yok" değil, **geri çekmenin hiçbir kapıyı etkilememesi**. `assets/legal/explicit_consent_tr.md:9-10`, `privacy_policy_tr.md:57` ve `docs/COMPLIANCE.md:47-48` ("withdrawable as easily as it was given") geri çekilebilirlik taahhüdü veriyor. `COMPLIANCE.md:116-118` bunu **zaten "Remaining gaps (deferred)" olarak kabul ediyor** — yani ekip biliyor.
**Önerilen düzeltme metni:**
> Rıza Merkezi'nde kapattığın her amaç, ilgili özelliği o anda durdurur. Sağlık verisi rızasını kapatırsan plan ve analiz üretimi durur; yapay zekâ rızasını kapatırsan istemler gönderilmez.
**Kod aksiyonu:** S1. **Bu, v1.0 halka açık lansmanın engelleyicisidir.**

## C5 · Zorunlu, üç amaç paketlenmiş tek rıza kutusu — ve metin tersini söylüyor · **ACİL**
**Yer:** `lib/core/services/consent_service.dart:120-122` (`put(healthData, true); put(aiProcessing, true); put(crossBorderTransfer, true);`) · `lib/screens/auth/register_screen.dart:103-110` (`_isFormValid()` içinde `_essentialDataConsent` zorunlu) · `assets/legal/explicit_consent_tr.md:8-10`, `:33`
**Neden risk:** Metin "rıza verip vermemekte **tamamen özgürsünüz** ... temel işlevlerden yararlanmaya devam edebilirsiniz" diyor; oysa kayıt olmadan uygulama kullanılamıyor ve kutu zorunlu. Aynı metin `:33`'te "kullanmaya başladığınızda ... açık rıza verdiğiniz kabul edilir" diyerek **zımnî rıza** kuruyor — ilk paragrafla iç çelişki. Özel nitelikli sağlık verisi, yapay zekâ işleme ve yurt dışı aktarım **tek kutuda** paketli. Sitenin `legal/acik-riza-metni.astro:91-93` maddesi kutunun "işaretlenmemiş" ve "**ayrı bir adımda**" olduğunu iddia ediyor.
*(Bu paketlemenin KVKK açısından geçerliliği hukuk müşaviri teyidi gerektirir → **DOĞRULANAMADI**. Metin içi çelişki kesindir.)*
**Önerilen düzeltme metni:**
> Sağlık verisi işleme, yapay zekâ kullanımı ve yurt dışına aktarım için ayrı ayrı onay veriyorsun. Bu onaylar uygulamanın çekirdek işlevleri için gereklidir; vermezsen hesap açılmaz. Onayı sonradan Rıza Merkezi'nden geri çekebilirsin.

## C6 · "En az 1.000 hesaplık kohort" — mekanizma yok, özellik yok · **ACİL**
**Yer:** `src/pages/legal/kvkk-aydinlatma-metni.astro:143-147`, `:106` (veri kategorisi), `:121` (işleme amacı) · `src/content/faq/{tr,en}/markalar-verimi-goruyor-mu | brands-data-access`
**Gerçek:** `cohort` → `lib/`, `functions/` genelinde **0 eşleşme**. `sponsored|sponsorlu|brand_partner` → 0. Marka ortağı, cihaz üzerinde eşleştirme, toplulaştırma eşiği — hiçbiri kodda yok.
**Neden risk:** Bu, denetimin en ağır kategorisi: **uygulanmamış bir gizlilik kontrolünü var gibi anlatmak.** Metin yalnızca bir özellik iddia etmiyor, o iddiaya dayanarak **hukuki sonuç ilan ediyor**: "bu, KVKK m.3 anlamında ... kişisel veri aktarımı teşkil etmez". Sitenin kendi `docs/LEGAL-REVIEW.md:79-86` maddesi bu teyidi istiyor ve *"yanlışsa bu bölümün tamamı yeniden yazılmalıdır"* diyor. Denetimin cevabı: dayanak yok.
**Önerilen düzeltme metni:**
> Sponsorlu ürün önerileri henüz uygulamada bulunmuyor. Bu özellik yayına girdiğinde eşleştirmenin nerede yapıldığını, marka ortağına hangi verinin gittiğini ve toplulaştırma eşiğini burada yayımlayacağız.

## C7 · Şirket künyesi boş; iki kaynak farklı duruş alıyor · **ACİL / lansman engelleyici**
**Yer:** `src/data/company.ts:38-52` — `legalName`, `address`, `mersisNumber`, `taxOffice`, `taxNumber`, `kvkkDataController`, `kvkkApplicationEmail`, `kepAddress` **hepsi null**, `isComplete: false` · `src/pages/legal/kvkk-aydinlatma-metni.astro:74-84` 6 satır "[eklenecek]" · `assets/legal/kvkk_aydinlatma_tr.md:11-12` "Burak Dereli tarafından işletilen Cookrange" — **eksiklik belirtilmiyor, uyarı bandı yok**
**Neden risk:** Site eksikliği kabul edip `CompanyIncompleteNotice` bandı basıyor ✅; uygulama aynı olguyu eksiksizmiş gibi sunuyor. Veri sorumlusu kimliği KVKK aydınlatmasının zorunlu unsuru. Başvuru kanalı da ikili: site `contact@cookrangeapp.com`, uygulama `privacy@cookrangeapp.com`. Üç uygulama metni de kendini taslak ilan ediyor (`kvkk_aydinlatma_tr.md:73-74`, `explicit_consent_tr.md:37`, `privacy_policy_tr.md:148-150`). Sitenin kendi `docs/LEGAL-REVIEW.md:129` maddesi şirket bilgileri sayfasını 6563 sayılı kanun uyarınca **yasal zorunluluk** olarak işaretliyor.
*(6563 ve mesafeli satış mevzuatının somut gereklilikleri bu denetimde incelenmedi → **DOĞRULANAMADI**. Ürünün kendi hukuki sayfalarını "yayına hazır değil" işaretlediği olgusu kesindir.)*
**Önerilen düzeltme metni:**
> Veri sorumlusu: [tescilli unvan], [adres], MERSİS [numara], [vergi dairesi] / [vergi no], KEP [adres]. KVKK başvuruları için tek kanal: privacy@cookrangeapp.com. Bu bilgiler tamamlanana kadar uygulama içi metinde de aynı eksiklik bandı gösterilir.

## C8 · Hesap silme kişisel veri bırakıyor; belge "tam" diyor · **YÜKSEK**
**Yer:** `functions/account.js:63-85` · Silinmeyenler: `gyms/*/checkins/*` (uid + display_name + photo_url; `firestore.rules:473` `allow update, delete: if false` — kullanıcı da silemiyor), `gyms/*/members/{uid}`, `coach_profiles/*/clients/{uid}` (`firestore.rules:505` `delete: if false`), `coach_profiles/*/reviews/{uid}`, `privacy_requests` (uid + **e-posta**; `firestore.rules:346` `delete: if false`), başkalarının gönderileri altındaki yorumlar (`account.js:76` yalnızca `posts.authorId == uid` tarıyor; oysa dışa aktarma `data_export_service.dart:102-107` `collectionGroup('comments')` tarıyor — **asimetri**), `chats/*/messages`, `squads` üyelikleri, `users/{başkası}/friends/{uid}`, `gym_applications` / `coach_applications`
**Neden risk:** `privacy_policy_tr.md:68-70` "sistemlerimizden 30 gün içinde kalıcı olarak silinir" diyor. `faq/tr/hesap-silme.md` "geriye dönük bir yedek olarak tutulmaz" diyor. `docs/COMPLIANCE.md:88-92` silmeyi "✅ complete ... **all** Storage prefixes" ilan ediyor. Üçü de gerçekten fazlasını iddia ediyor.
**Önerilen düzeltme metni:**
> Hesabını sildiğinde profilin, sağlık verilerin, kayıtların ve yüklediğin dosyalar silinir. Salon check-in kayıtlarındaki adın ve fotoğrafın ile koç bağlarındaki bilgilerin de aynı işlemde silinir; yalnızca yasal saklama yükümlülüğü olan mali kayıtlar kalır.

## C9 · Saklama süreleri hiçbir kaynakta yok · **YÜKSEK**
**Yer:** `assets/legal/kvkk_aydinlatma_tr.md` — saklama süresi **bölümü bile yok** · `kvkk-aydinlatma-metni.astro:155-163` ve `gizlilik-politikasi.astro:162-167` — "eklenecektir" · `faq/en/account-deletion.md` — "will be published ... once finalized" · tek rakam `privacy_policy_tr.md:68-70` "30 gün" ve o da C8 ile çelişiyor
**Neden risk:** Uygulamanın KVKK metninde bölüm bile bulunmuyor. Site kendi §6'sını zorunlu kabul ediyor ve `docs/LEGAL-REVIEW.md:34-35` bunu yayın öncesi madde yapıyor.
*(Aydınlatma Yükümlülüğünün Yerine Getirilmesinde Uyulacak Usul ve Esaslar Hakkında Tebliğ'in saklama süresini zorunlu kılıp kılmadığı → **DOĞRULANAMADI**, hukuk müşaviri teyidi gerekli.)*
**Önerilen düzeltme metni:**
> Saklama süreleri: hesap verileri üyelik boyunca ve sonrasında [süre]; sağlık verileri rıza geri çekilene kadar; pazarlama izin kayıtları geri çekmeden itibaren [süre]; mali kayıtlar mevzuattaki zamanaşımı süresi boyunca.

## C10 · Alt işleyici listesinde yapay zekâ sağlayıcısı yok · **YÜKSEK**
**Yer:** `src/pages/legal/alt-islemciler.astro:59-88` (Vercel, Google/Firebase, GA-GTM, Microsoft Clarity) · `kvkk-aydinlatma-metni.astro:132-142` (yurt dışı: yalnızca Vercel + Firebase) · `grep OpenRouter src/ docs/` → **0 sonuç**
**Neden risk:** Uygulama metinleri OpenRouter'ı adıyla anıyor (`kvkk_aydinlatma_tr.md:46`, `privacy_policy_tr.md:74`, `:98`). Site KVKK §3 yapay zekâ işlemeyi bir amaç olarak ilan ediyor ama §5 alıcıyı saymıyor. Apple / Google Play ve OpenStreetMap de listede yok.
**Önerilen düzeltme metni:**
> Yapay zekâ çıkarımı için OpenRouter kullanıyoruz; istem metnin ve profil bağlamın bu sağlayıcıya gider ve yurt dışında işlenir. Uygulama içi satın almalar Apple ve Google Play üzerinden, harita döşemeleri OpenStreetMap üzerinden gelir.

## C11 · Site "uygulama içi indirme düğmesi yok" diyor; kodda 24 kaynaklı tek-tuş ihracat var · **ACİL**
**Yer:** `src/content/faq/tr/veri-disa-aktarma.md` ("şu an uygulama içinde tek tuşla bir indirme düğmesi yok") ↔ `lib/core/services/data_export_service.dart:18-36` (tek çağrı) ve `:42-68` (**24 kaynak**, `export_version: '2.0'`, `private` PII dahil) · uygulama metinleri doğru: `kvkk_aydinlatma_tr.md:68`, `privacy_policy_tr.md:118` ("Ayarlar → verilerini dışa aktar")
**Neden risk:** Site, kullanıcıyı var olan bir hakkı kullanmaktan alıkoyup gereksiz e-posta başvurusuna yönlendiriyor. **Burada yanlış olan tek kaynak site**; uygulama ve yasal metinler hemfikir. Bu, ilgili kişinin hakkını kullanmasını zorlaştıran bir yanlış bilgilendirme.
**Önerilen düzeltme metni:**
> Verilerini uygulama içinden indirebilirsin: Ayarlar → Verilerini Dışa Aktar. Dosya JSON biçiminde gelir ve profilin, sağlık verilerin, kayıtların ile yüklediğin dosyaların listesini içerir.

## C12 · Konum rızası ve bildirim rızası hiç kaydedilmiyor · **YÜKSEK**
**Yer:** `lib/core/services/consent_service.dart:100` (yorum: "Location + notifications stay unset") · `grep "setConsent(ConsentPurpose.location" lib/` → **0 sonuç** · `lib/screens/gym/gym_checkin_screen.dart:54-60` ve `gym_discovery_screen.dart:130-153` yalnızca `PermissionPrimer` + OS diyalogu gösteriyor
**Neden risk:** `privacy_policy_tr.md:52-53` konum ve bildirim için hukuki sebebi "**Açık rızanız**" olarak ilan ediyor. Kayıtlı, sürümlü, ispatlanabilir bir rıza dokümanı hiç oluşmuyor — yani beyan edilen hukuki sebebin kanıtı üretilmiyor. Rıza Merkezi bu iki amacı sonsuza kadar "kapalı" gösteriyor.
**Önerilen düzeltme metni:**
> Konum ve bildirim onayını verdiğin an, tarih ve metin sürümüyle birlikte kaydediyoruz. Rıza Merkezi'nde bu iki kalemin güncel durumunu görebilirsin.

## C13 · iOS izleme izni sorulup yok sayılıyor · **YÜKSEK**
**Yer:** `lib/core/services/att_consent_service.dart:20-23` (`analyticsEnabled`) — `grep analyticsEnabled lib/` → yalnızca tanım; tek tüketici `lib/screens/splash_screen.dart:439` sadece `requestIfNeeded()` çağırıyor
**Neden risk:** iOS kullanıcısına izleme izni soruluyor, "hayır" cevabı hiçbir davranışı değiştirmiyor (Analytics zaten `ConsentPurpose.analytics`'e bağlı). `privacy_policy_tr.md:89-90` "izninizi isteriz; reddedebilirsiniz" diyor. **Sorup yok saymak, hiç sormamaktan daha riskli** — App Store ATT politikası ihlali olarak da değerlendirilebilir.
**Önerilen düzeltme metni:**
> iOS'ta izleme izni sorulmaz; analitik toplama yalnızca Rıza Merkezi'ndeki analitik onayına bağlıdır.

## C14 · Check-in doğrulaması istemcide — salona satılan güvence sahtelenebilir · **YÜKSEK**
**Yer:** `lib/core/services/gym_service.dart:405-416` (mesafe istemcide hesaplanıyor) · `firestore.rules:471-472` (yalnızca uid eşleşmesi arıyor, mesafe kontrolü yok)
**Neden risk:** Salona "check-in doğrulaması" satılıyor; 100 metre kontrolü yalnızca istemcide. Değiştirilmiş bir istemci salonda olmadan check-in üretebilir. Salon analitiği, liderlik tablosu ve salon savaşları bu veriye dayanıyor.
**Önerilen düzeltme metni:**
> Check-in doğrulaması sunucu tarafında yapılır. *(Bu ifade, S11 tamamlanmadan kullanılmaz.)*

## C15 · Konum vaadi yanlış özelliğe bağlanmış · **ORTA**
**Yer:** `guvenlik.astro:26` ve `faq/tr/veri-nerede-saklaniyor.md` → "yakınımdaki **arkadaş** sıralaması" · `grep nearbyFriends lib/` → **0 sonuç**
**Neden risk:** Vaadin kendisi doğru ✅ (koordinat sunucuya gitmiyor) ama gerekçe olarak var olmayan bir özellik gösterilmiş. Konumu kullanan gerçek özellikler salon ve koç keşfi. Aynı boşluk uygulama tarafında da var: `permission.location.rationale` ve `Info.plist` yalnızca GPS check-in'den bahsediyor, salon ve koç keşfini atlıyor — izin gerekçesi eksik.
**Önerilen düzeltme metni:**
> Yakınındaki salon ve koç sıralaması cihazında hesaplanır; koordinat sunucuya gönderilmez ya da kaydedilmez.

## C16 · Kısa notlar
| # | Bulgu | Yer | Öncelik |
|---|---|---|---|
| C16a | `marketplace_terms_{tr,en}.md` paketli ama uygulamada **gösterilmiyor** (`LegalDocumentType` içinde yok, `grep marketplace_terms lib/` → 0) → koç programı satın alan kullanıcı sözleşmeyi göremiyor | `pubspec.yaml:166` · `lib/screens/legal/legal_screen.dart:9-14` | ORTA |
| C16b | `profile_visibility` yazılıyor ve ayrıştırılıyor ama hiçbir okuma yolunda, sorguda ya da güvenlik kuralında kullanılmıyor → herhangi bir "gizli profil" vaadinin dayanağı yok | `user_provider.dart:148` · `user_model.dart:113` | ORTA |
| C16c | Çerez politikası "Pazarlama" onay kategorisi tanımlıyor; banner yalnızca `necessary` + `analytics` render ediyor | `cerez-politikasi.astro:71` ↔ `ConsentBanner.astro:85-106`, `consent.ts:53-55` | DÜŞÜK |
| C16d | `docs/COMPLIANCE.md:132-133` EXIF/GPS temizliğini hâlâ **eksik** ilan ediyor; kod aslında temizliyor → doküman olumsuz yönde yanlış | `storage_upload_service.dart:16-30` | DÜŞÜK |
| C16e | Salon analitiği ve liderlik tablosu `.limit()` olmadan tüm koleksiyonu okuyor; CSV tüm zamanların check-in'lerini çekiyor → maliyet, performans ve veri minimizasyonu riski | `gym_analytics_service.dart:38-48`, `:139` · `gym_leaderboard_service.dart:32-38` | ORTA |
| C16f | Koç incelemeleri ilişki doğrulaması olmadan yazılabiliyor ve değiştirilemez | `TODO.md` S13 | ORTA |
| C16g | İYS kaydı yapılmadan gerçek pazarlama iletişimi göndermek ayrı bir mevzuata aykırılık; çift onaylı e-posta **hiç kodlanmadı**, Turnstile **hiç entegre değil** — ekip bunu biliyor | `docs/COMPLIANCE-NOTES.md:26-28`, `:32` · `docs/LAUNCH-CHECKLIST.md` | YÜKSEK |
| C16h | Bekleme listesi formunun canlıda çalıştığı **doğrulanmadı** — ekibin kendi notu: "400 yanıtı Firebase kimlik bilgilerinin çalıştığını kanıtlamaz" | `docs/LAUNCH-CHECKLIST.md:66-68` | YÜKSEK |
| C16i | Test Modu anahtarı son kullanıcıya açık; açıldığında salon keşfi, koç keşfi, liderlik tablosu, öğün planı, alışveriş listesi ve yemek veritabanı **sahte veri** döndürüyor | `settings_screen.dart:1191-1213` | YÜKSEK |
| C16j | Program pazaryerindeki tek içerik, her istemcinin açılışta yazdığı **3 demo program** | `app_initialization_service.dart:335` | YÜKSEK |

---

# D. KORUNACAK OLUMLU BULGULAR
> Denetim kötü haberi bulmak için yapıldı, ama bu sekiz nokta doğru kurulmuş ve bozulmaması gerekiyor.

1. **Uydurma değerlendirme puanı yok.** `aggregateRating`, `ratingValue`, `reviewCount`, kullanıcı sayısı → `src/` ve `public/` genelinde 0 eşleşme. `src/lib/schema.ts:6-9` bunu bilinçli karar olarak belgeliyor.
2. **Konum koordinatı gerçekten sunucuya yazılmıyor.** `checkin_model.dart:52-58` lat/lng alanı yok; mesafe istemcide hesaplanıp atılıyor; salon analitiği yalnızca zaman damgası okuyor. **Madde 48 vaadi kodda DOĞRU** — sitenin ve kodun en net örtüştüğü yer.
3. **Vücut ölçüleri sahibine kapalı.** `firestore.rules:207-211`; boy, kilo, doğum tarihi, alerji `private/nutrition` altında (`onboarding_provider.dart:232-251`). *Ama hedef kilo ve hedef bu ayrımın dışında bırakılmış — bkz. C1.*
4. **Yüklenen görsellerden EXIF/GPS temizleniyor.** `storage_upload_service.dart:16-30`.
5. **Analytics ve Crashlytics varsayılan KAPALI ve gerçekten rızaya bağlı.** `consent_service.dart:91-95`, `analytics_service.dart:93`.
6. **Sitenin çerez uygulaması dürüst.** Clarity onaydan önce hiç yüklenmiyor; GTM'in "yüklenir ama sinyal denied" davranışı politikada olduğu gibi anlatılmış.
7. **Alt işleyici sayfası uydurma sağlayıcı listelemiyor.** Turnstile entegre olmadığı için kasıtlı çıkarılmış (`alt-islemciler.astro:10-14`).
8. **Mağaza linkleri kasıtlı olarak `null`.** `constants.ts:9-11` yorumu: "Store links are intentionally null — apps are pre-launch". `indir.astro` "Uygulama henüz mağazada değil" diyor. Lansman durumu beyanı tutarlı ve dürüst — sitenin en iyi yönetilmiş alanı.

Ayrıca: **alerjen filtresi iddiadan güçlü** (`allergen_safety.dart` + havuz boşsa üretmeyi reddetme) ve **"Yakınımdaki salonlar" onay akışı** (`gym_discovery_screen.dart:135-186`) dokümanın referans deseni olarak tanıttığı şeyi gerçekten yapıyor — konum cihazda kalıyor, ret yolu açık, KVKK/GDPR gerekçesi yazılı.

---

# E. RİSK ÖZET TABLOSU

| Başlık | ACİL | YÜKSEK | ORTA | DÜŞÜK | Toplam |
|---|---|---|---|---|---|
| A · Yanıltıcı beyan | 7 | 3 | — | — | 10 |
| B · Sağlık iddiası | — | 4 | 1 | — | 5 |
| C · Veri ve mahremiyet | 8 | 10 | 5 | 2 | 25 |
| **Toplam** | **15** | **17** | **6** | **2** | **40** |

*(C16 alt maddeleri (a-j) tek tek sayılmıştır.)*

**Lansman engelleyicileri (v1.0 halka açık):** C1 · C2 · C4 · C6 · C7 · A8 · A4 · C16g
**En hızlı azaltma:** `ozellikler/sponsorlu-urunler.astro` geri çekilir + `hero-data.ts`'ten 6 satır kaldırılır + KVKK kohort maddesi çıkarılır → A2, A3, C6 kapanır, A1 ve A10'un yarısı düşer. Tek oturumluk iş.
