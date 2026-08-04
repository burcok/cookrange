# 07 — VARSAYIMLAR VE DOĞRULANAMAYANLAR

Cookrange · 4 Ağustos 2026
Denetim sırasında soru sorulmadı; her belirsizlik varsayıma çevrildi ve burada gerekçesiyle kaydedildi.

---

# A. YAPISAL VARSAYIMLAR

## V1 · `pazarlama/` klasörü bağlı değil
**Varsayım:** Pazarlama kaynağı olarak `cookrange-landing/docs/` (15 markdown), basın kiti sayfaları (`basin-kiti.astro`, `en/press.astro`), personalar (5+5), blog (20+20) ve kurumsal sayfalar (hakkımızda, ekip, yol haritası, kariyer) kullanıldı.
**Gerekçe:** Oturuma yalnızca `cookrange` ve `cookrange-landing` klasörleri bağlıydı. `cookrange-landing/docs/` içinde marka sesi (`TONE-OF-VOICE.md`), içerik planı (`CONTENT-CALENDAR.md`), anahtar kelime haritası (`KEYWORD-MAP.md`), dağıtım planı (`OFF-SITE-GEO.md`), hukuki inceleme (`LEGAL-REVIEW.md`) ve uyum notları (`COMPLIANCE-NOTES.md`) bulundu — brief'in "marka brief'i, sosyal medya planları, hesap stratejisi" tanımının fiilî karşılığı bunlar.
**Etkisi:** Ayrı bir marka brief'i belgesi varsa görülmedi. Marka sesi kuralları `TONE-OF-VOICE.md`'den alındı; o dosyanın kendisi kaynağını `DESIGN-INVENTORY.md` §1'e dayandırıyor.
**Doğrulamak için:** Ayrı bir `pazarlama/` klasörü varsa oturuma eklenmeli. Özellikle aranacaklar: onaylanmış konumlandırma cümlesi, LinkedIn gönderi taslakları, 30 günlük gönderi planı.

## V2 · "30 günlük plan" ve "LinkedIn gönderi taslakları" bulunamadı
**Varsayım:** Bunlar mevcut değil. `CONTENT-CALENDAR.md` (2.941 bayt, 35 satır) yalnızca 20 blog yazısının numaralı listesini içeriyor — tarih yok, kanal yok, gönderi metni yok. "Takvim" adı yanlış; dosya tamamlanmış içerik envanteri.
**Gerekçe:** `OFF-SITE-GEO.md` LinkedIn şirket sayfasını **açılacak** kalemler arasında sayıyor (tamamı işaretsiz `[ ]`); `LAUNCH-CHECKLIST.md` §10 `@cookrangeapp` hesaplarının "gerçekten var olduğunu doğrulayın" diyor. Yani sosyal hesapların varlığı bile teyit edilmemiş.
**Doğrulamak için:** Gönderi taslakları başka bir yerde tutuluyorsa (Notion, Google Docs, ayrı repo) oraya bakılmalı.

## V3 · Çıktı klasörünün yeri: `cookrange/denetim/`
**Varsayım:** Brief "TÜM ÇIKTILAR denetim/ klasörüne" diyor ama hangi repo olduğunu belirtmiyor. Denetim çıktıları uygulama repo'sunun kökündeki `denetim/` klasörüne yazıldı.
**Gerekçe:** Üç sebep: (a) K1 uyarınca uygulama doğruluk kaynağı; (b) TODO.md eki de aynı repo kökünde; (c) yazılabilir tek iki konum bu iki klasör, ve denetim ikisini de kapsıyor.
**Etkisi:** Bu, uygulama repo'suna yeni bir klasör eklemektir — mevcut hiçbir kaynak kod dosyası değiştirilmedi, silinmedi, taşınmadı. Site repo'sunda hiçbir değişiklik yapılmadı. Dosyalar ayrıca sohbete de teslim edilmiştir.

## V4 · Site kaynağı canlı siteye tercih edildi
**Varsayım:** `cookrange-landing/src/` doğruluk kaynağı; canlı site yalnızca sapma kontrolü için okundu.
**Gerekçe:** Brief "Boşsa canlı siteyi oku" diyor; klasör boş değil. Sapma kontrolü yapıldı: `cookrangeapp.com` üzerinde `/`, `/fiyatlandirma`, `/ozellikler`, `/basin-kiti`, `/indir` çekildi — **sapma 0**. Kontrol edilen her rakamda kaynak = yayın (2,4 sn · 12.400 sütun · 28/34/7 · "Altı kişi tek bir seriyi paylaşır" · ₺0 · iOS 14+/Android 8+ · v0.9.6 · 76,9/75,8/75,1 kg · ₺18 vs ₺32).
**Etkisi:** Bu rapordaki her site bulgusu şu an canlıda geçerli.

## V5 · Madde 60, madde 28 ile birleştirildi
**Varsayım:** Kontrol listesindeki 60 ("Salon gelir paneli") ile 28 aynı özellik. Brief "28 ile aynıysa birleştir" diyor — birleştirildi, kanonik ID **28**.
**Gerekçe:** İkisi de `TODO.md:2496` `GYM-07` kaydına düşüyor, dosya listesi `none`. Denetlenen madde sayısı bu yüzden 61 değil **60**.

## V6 · Kod okuma kapsamı
**Varsayım:** Uygulama envanteri localization dosyaları (2×2725 anahtar), 21 doküman, `firestore.rules`, `TODO.md` (362 KB) ve hedefli `grep` taramaları üzerinden çıkarıldı; 128 ekran dosyasının tamamı satır satır okunmadı.
**Gerekçe:** Bir özelliğin varlığı/yokluğu için en güvenilir kanıt (a) localization anahtarının varlığı, (b) servis/model tanımı, (c) **çağrı yerinin varlığı**. Denetimin en değerli bulguları bu üçüncüsünden geldi: `FeatureGateService().check()` → 0 çağrı yeri, `createProgram` → 0 çağrı yeri, `isFeatureEnabled` → 0 tüketici.
**Etkisi:** Tanımlı ama çağrılmayan kod "YOK" değil "SADECE ARAYÜZ VAR" / "ölü kod" olarak işaretlendi. Yanlış negatif riski düşük (grep tüm ağacı taradı), yanlış pozitif riski daha düşük (her hüküm dosya:satır ile bağlandı).

## V7 · "28 öğün" savunulabilir kabul edildi
**Varsayım:** Sitenin "haftanın 28 öğünü" ifadesi doğru; 7 gün × 4 öğün (kahvaltı, öğle, akşam, ara öğün).
**Gerekçe:** `dish_data.dart` dört öğün tipi taşıyor (kahvaltı 18 / öğle 25 / akşam 29 / ara öğün 3). Aynı üçlünün diğer iki üyesi (34 ürün, 7 reyon) reddedildi çünkü kodda karşılığı yok.
**Doğrulamak için:** `weekly_meal_plan_service.dart` üretilen plandaki günlük öğün sayısını sabit 4 olarak mı belirliyor — plan şeması okunmalı.

## V8 · Site sayfa çiftleri `routes.ts` üzerinden eşlendi
**Varsayım:** TR ve EN eşitlik denetimi dosya adı değil `routeKey` ve `translationId` üzerinden yapıldı.
**Gerekçe:** Slug'lar SEO için kasıtlı yerelleştirilmiş (`is-it-free` ↔ `ucretsiz-mi`). Ön incelemede "`medical-disclaimer` sadece EN'de, `diyetisyen-yerine-gecer-mi` sadece TR'de" diye görünen şey aslında **aynı içeriğin iki dili** — ikisi de `translationId: faq-medical-disclaimer`. Eşitlik ölçütü slug olarak alınsaydı 22 yanlış bulgu üretilirdi.

## V9 · "Yakında" etiketli çalışan özellikler "VAR" sayıldı
**Varsayım:** Salon savaşları, salon kurulumu, QR giriş ve salon analitiği — uygulamada "YAKINDA GELECEK" etiketli olmalarına rağmen **TAM VAR** işaretlendi.
**Gerekçe:** K1 (ürün gerçeği kazanır) kod düzeyinde uygulandı: kod çalışıyorsa özellik vardır, etiket yanlıştır. Aksi hâlde çalışan bir özelliği yol haritasına koyup ikinci kez yaptırma riski doğardı (bkz. 04 numaralı dosya, REDDET R3).

## V10 · Özellik bayrağı kapalı olanlar ayrı işaretlenmedi — çünkü bayrak yok
**Varsayım:** "ÖZELLİK BAYRAĞI KAPALI" durum etiketi hiçbir maddede kullanılmadı.
**Gerekçe:** Mekanizma var ama **hiçbir yerden çağrılmıyor**: `isFeatureEnabled` → 0 tüketici, `isInRollout` → 0 tüketici. `feature_voice_assistant` ve `feature_nutrition_analytics` varsayılan `false` ama okunmadıkları için özellikler **açık**. Yani "var ama görünmüyor" kategorisi bu üründe fiilen mevcut değil — tersi geçerli: "kapalı sanılıyor ama açık". Bu, denetimin en yüksek kaldıraçlı bulgusu oldu (04 numaralı dosya, ŞİMDİ N2).

## V11 · Marka sesine iki yeni kural eklendi
**Varsayım:** `TONE-OF-VOICE.md` hitap kuralı, cümle uzunluğu sınırı, ünlem/emoji politikası ve "iddia değil mekanizma" ilkesini **yazılı olarak içermiyor**; brief bunları kural sayıyor. Fiilî kullanım ve brief birleştirilerek 03 numaralı dosyada 10 maddelik bağlayıcı liste üretildi; 9. ve 10. maddeler **YENİ ÖNERİ** olarak işaretlendi.
**Gerekçe:** 9. madde (kanıt kuralı) olmadığı için "2,4 saniye", "34 ürün", "7 reyon", "12.400 sütun" ve "1.000 hesap" rakamları tasarım mock'undan metne geçti. Kuralın yokluğu doğrudan beş uydurma rakamın sebebi.

## V12 · Yol haritası puanlaması ve ŞİMDİ seçimi
**Varsayım:** "ŞİMDİ" kovasına özellik değil **kapı** konuldu: N1 (veri sızıntısı) ve N2 (özellik bayrakları).
**Gerekçe:** Brief'in testi uygulandı — "bu özellik olmadan ilk salon pilotu başlayabilir mi?" N1 için hayır (gerçek kullanıcıların e-postası ve IP'si açıkta). N2 için hayır (rıza kontrolü olmayan koç yapay zekâ raporu, kırık squad ve sahte veri gösteren Test Modu kapatılamıyor). Uyum motoru (11) daha stratejik ama pilot onsuz başlayabilir — metin düzeltmesi riski bugün kapatıyor, özellik haftalar alıyor.
**Karşı görüş kaydı:** Rıza geri çekmenin çalışmaması (C4) da ŞİMDİ adayıydı. SONRA'ya alındı çünkü pilotta katılımcı sayısı sınırlı ve geri çekme yolu olarak sunucu tarafı hesap silme çalışıyor (`functions/account.js:48`). **v1.0 halka açık lansman için engelleyici olarak işaretlendi.**

## V13 · Hukuki hükümler verilmedi
**Varsayım:** Mevzuat yorumu gerektiren hiçbir yerde kesin hüküm verilmedi; olgusal tespit ile hukuki sonuç ayrıldı.
**Gerekçe:** Kodun ne yaptığı ve metnin ne dediği kanıtlanabilir; bir uygulamanın KVKK'ya aykırı olup olmadığı hukuk müşaviri işi. Bu yüzden "rıza paketlemesi geçersizdir" değil "metin içi çelişki kesindir, geçerlilik DOĞRULANAMADI" yazıldı.

## V14 · Ekip tarafından zaten bilinen açıklar ayrı tutuldu
**Varsayım:** `docs/ASSUMPTIONS.md` (14 kayıt), `docs/LEGAL-REVIEW.md` (17), `docs/COMPLIANCE-NOTES.md` (6), `docs/LAUNCH-CHECKLIST.md` (13) — toplam **50 kayıt** ekibin kendi açık madde listesi.
**Gerekçe:** Bu, denetimin değerini ölçmek için gerekli: hangi bulgu yeni, hangisi zaten biliniyordu?
**Yeni bulgular (bilinen listelerde HİÇ yok):** "tamamlandı" iddiası · basın kiti bütçe ve atıştırmalık cümleleri · koç personası ile blog arasındaki çelişki · 2,4 saniyenin kaynaksızlığı · B2B etkinlik vaadi · +230 kcal hesabı · hero rakamlarının etiketsizliği · MyFitnessPal tablosu · aşama enflasyonu (6 ad) · birinci çoğul şahıs ihlalleri · hitap tutarsızlığı · adaptif/wishlist terim çelişkileri · Gym↔Salon karışıklığı · Turkey↔local · boilerplate karakter sapmaları · "takvim" adının yanlışlığı · **ve uygulama tarafındaki bulguların neredeyse tamamı** (veri sızıntısı, bayrakların bağlı olmaması, koç rıza boşluğu, squad'ın 6 iddiası, doluluk özelliğinin yokluğu, sponsorlu katmanın yokluğu, Premium'un beş yanlış vaadi, Test Modu).
**Zaten bilinen:** şirket künyesi eksikliği · İYS ve çift onay · Turnstile · saklama süreleri · kohort iddiasının teyit ihtiyacı (`LEGAL-REVIEW.md:79-86` — "yanlışsa bu bölümün tamamı yeniden yazılmalıdır") · rıza geri çekme boşluğu (`COMPLIANCE.md:116-118` "Remaining gaps (deferred)") · sosyal hesapların doğrulanmamışlığı · bekleme listesi formunun canlıda test edilmemişliği.

---

# B. DOĞRULANAMADI — TAM LİSTE
> Kanıt bulunamadı. Her satırda **doğrulamak için tam olarak neye bakılmalı** yazıyor.

| # | Madde / iddia | Neden doğrulanamadı | Doğrulamak için tam olarak neye bakılmalı |
|---|---|---|---|
| D1 | **Fotoğraf analizinin yapay zekâ kotasına bağlı olup olmadığı** (madde 16, 42) | Tarif üretiminin kota tükettiği kanıtlandı (`explore_screen.dart:59-67`); fotoğraf analizi için aynı bağ gösterilemedi | `analyzeFoodPhoto` çağrı zincirinin `functions/index.js:83-120` `recordUsage` ve kota kontrolünden geçip geçmediği. Bu, "Sınırsız öğün kaydı (… fotoğraf)" iddiasının doğru mu yanlış mı olduğunu belirler |
| D2 | **Barkod tarama süresi** (madde 17) | Harici API, kodda ölçüm yok, testte yok, dokümanda yok | Gerçek cihazda 20 TR market barkodu ile ölçüm; ayrıca `tr.openfoodfacts.org` kapsama istatistiği ve TR barkod hit-rate testi. Rakam ölçülene kadar sitede sayı verilmez |
| D3 | **Open Food Facts'in TR ürün sayısı** (madde 17) | Harici veritabanı, sayım imkânsız | Open Food Facts ülke filtresi istatistiği (`tr.openfoodfacts.org` ürün sayacı) — ve bunun bir Cookrange varlığı **olmadığının** metinde belirtilmesi |
| D4 | **Android `minSdkVersion`** (madde 51) | `android/app/build.gradle:79` → `minSdkVersion flutter.minSdkVersion`; repoda sabit yok, Flutter sürüm pini yok | Kullanılan Flutter SDK sürümünün `flutter.minSdkVersion` değeri (`flutter/packages/flutter_tools/gradle/`), ya da `build.gradle`'a doğrudan `minSdkVersion 26` yazılması. Site "Android 8" diyor; gerçek zemin büyük olasılıkla 21 veya 24 |
| D5 | **Hazırlık süresinin plan girdisi olup olmadığı** (madde 05) | Site "mutfakta ayırabileceğin süre" diyor; bütçenin yokluğu kanıtlandı, sürenin varlığı kanıtlanamadı | `dish_data.dart` içinde `prepTime`/`cookTime` alanı var mı ve `weekly_meal_plan_service.dart` bunu kısıt olarak kullanıyor mu; onboarding'de süre sorusu var mı |
| D6 | **Koç yapay zekâ raporunun hangi kotadan düştüğü** | `AIService().generateJson` çağrısı görüldü, kota bağlantısı izlenemedi | Koçun mu danışanın mı kotası tükendiği — `functions/index.js` `recordUsage` çağrısındaki uid. Faturalandırma ve kötüye kullanım açısından önemli |
| D7 | **`grantStreakFreeze` çağrı yerleri** (madde 37) | Fonksiyon bulundu, tetikleyicileri izlenemedi | `grep -rn "grantStreakFreeze" lib/ functions/` — dondurma jetonu kaç kez ve hangi koşulda veriliyor |
| D8 | **`high` risk penceresinin uzunluğu** (madde 61) | Dört risk seviyesi ve üç eşik bulundu (10:00 / 14:00 / kayıt=0), pencere süresi bulunamadı | `ai_insight_service.dart:35-43` çevresindeki zaman hesabı |
| D9 | **`check_in_radius`'un salon kurulum ekranından düzenlenebilirliği** | Varsayılan 100 m doğrulandı (`gym_model.dart:63`), yazma yolu bulunamadı | `gym_setup_screen` ya da salon kurulum akışında `check_in_radius` alanına yazan bir kod yolu var mı |
| D10 | **`sameAs` sosyal hesaplarının varlığı** | `schema.ts:36-39` → `instagram.com/cookrangeapp`, `linkedin.com/in/burcok`. Instagram `robots.txt` çekmeyi engelliyor | Hesapların manuel açılıp kontrol edilmesi. Var olmayan hesabı `sameAs`'te beyan etmek yapılandırılmış veri hatası; `LAUNCH-CHECKLIST.md` §10 de bunu istiyor |
| D11 | **`cookrangeapp.com/llms.txt`** | WebFetch izin isteği zaman aşımına düştü | Tarayıcıdan doğrudan açılması; içeriğinin `llms.txt.ts` kaynağıyla eşleşip eşleşmediği |
| D12 | **İlçe topluluk akışının varlığı** (madde 33) | 3 gerçek akış bulundu, 6 etiketli filtre bulundu; ilçe kapsamı ayrı bir akış mı belirsiz | `community_service.dart` sorgu parametreleri ve `turkish_locations.dart` ile ilişkisi |
| D13 | **Squad'ın canlıda gerçekten çalışıp çalışmadığı** (madde 36) | Statik analiz kural çelişkisi gösteriyor (`joinSquad` üyelik gerektiren kurala takılmalı) ama çalışma zamanı testi yapılmadı | Emülatörde ya da canlıda davet koduyla squad'a katılma denemesi + Firestore kural log'u. Ayrıca `firestore.indexes.json` içinde `inviteCode` indeksi var mı |
| D14 | **Çevrilmemiş TR dizesi sayısı** (madde 52) | İki farklı sayım çıktı: 6 (uzunluk eşiğine duyarlı otomatik karşılaştırma) ve 15 (grup bazlı inceleme) | `tr.json` ve `en.json` üzerinde birebir aynı değer taşıyan tüm anahtarların insan gözüyle taranması; marka adı ve biçim dizeleri ayıklanarak. Kesin sayı `test/i18n_parity_test.dart` değer karşılaştırması eklendiğinde otomatik çıkar |
| D15 | **Karşılaştırmalı reklam ve saklama süresi mevzuat gereklilikleri** | Hukuki yorum gerektiriyor | Hukuk müşaviri: Ticari Reklam ve Haksız Ticari Uygulamalar Yönetmeliği'nin karşılaştırmalı reklam koşulları; Aydınlatma Tebliği'nin saklama süresi zorunluluğu; 6563 sayılı kanun kapsamında şirket bilgisi zorunluluğu; hassas veri rızasının paketlenmesinin geçerliliği |
| D16 | **v0.9.6 changelog'unun doğruluğu** | Yayınlanmış sürüm notu üç madde sayıyor; ikisi denetimde yanlış çıktı (TR barkod veritabanı, altı kişilik ortak seri), üçüncüsü (salon varlığı bildirimi) doğrulanamadı | Karşılıklı arkadaş salona girdiğinde push bildiriminin gerçekten gittiği — `functions/` içinde check-in tetiklemeli bildirim var mı |

---

# C. DENETİM DIŞINDA BIRAKILANLAR

| Alan | Neden |
|---|---|
| Erişilebilirlik (WCAG) | Brief kapsamında değil. Site `erisilebilirlik-beyani.astro` sayfası taşıyor; `docs/LEGAL-REVIEW.md:151` uygunluk iddiasının incelenmediğini not ediyor |
| Performans / Lighthouse | Kapsamda değil. `lighthouserc.json` mevcut |
| Test kapsamı | Yalnızca sayısal olarak not edildi (12 Dart testi + 1 rules suite, kapsam ~%1) |
| Tasarım tutarlılığı | `DESIGN-INVENTORY.md` ve `HERO-*` dosyaları yalnızca **iddia** aramak için tarandı, tasarım denetimi yapılmadı |
| Firestore maliyet modellemesi | Limitsiz okuma bulguları not edildi (C16e) ama maliyet hesabı yapılmadı |
| Uygulama kaynak kodunun tamamı | 128 ekranın hepsi satır satır okunmadı; bkz. V6 |

---

# D. BU DENETİMİN KENDİ SINIRLARI

1. **Statik analiz, çalışma zamanı değil.** Hiçbir şey emülatörde çalıştırılmadı. "Squad çalışmıyor" hükmü kural çelişkisine dayanıyor, gözlenmiş hataya değil (D13).
2. **Canlı Firestore yapılandırması görülmedi.** `app_config/global` dokümanının içeriği yayınlanan yapay zekâ kotasını belirliyor: sunucu sabiti 2/20, istemci varsayılanı 5/50. Canlı dokümana 5/50 yazılmışsa gerçek limit odur. Kanonik değer olarak sunucu sabiti alındı (fail-closed davranışı nedeniyle) — ama canlı doküman kontrol edilmeli.
3. **Rakip iddiaları doğrulanmadı.** MyFitnessPal'ın salon entegrasyonu olup olmadığı denetlenmedi; yalnızca iddianın **kaynaksız ve tarihsiz** olduğu tespit edildi.
4. **Blogdaki akademik kaynaklar okunmadı.** PubMed / JAMA / ScienceDirect linkleri var; linklerin varlığı doğrulandı, atıfların doğruluğu doğrulanmadı.
5. **`TODO.md` 362 KB.** Tamamı okunmadı; hedefli arama yapıldı. Kontrol listesindeki 54-61 maddeleri için backlog kayıtları arandı ve bulundu (`ICE-21`, `ICE-22`, `ICE-24`, `NUT-11`, `COA-04`, `COA-05`, `GYM-07`, `GYM-08`).


---

# E. DOĞRULAMA TURU — 4 Ağustos 2026

Denetim tamamlandıktan sonra bulgular **bağımsız bir çürütme turundan** geçirildi: en sonuç doğurucu 14 iddia için kanıt sıfırdan yeniden arandı, her iddia için alternatif açıklamalar (farklı isimlendirme, dolaylı çağrı, başka dosya, generated kod) tarandı. Ayrıca teslim dosyaları kendi kalite kurallarına karşı denetlendi.

**Tam onaylanan 6 iddia:** uyum motorunun yokluğu · `sponsor` kelimesinin 0 eşleşmesi · squad'daki 6'nın davet kodu uzunluğu olması · market listesinde reyon alanının yokluğu · kullanıcı kök dokümanının herkese açık olması · Premium ekranındaki 5 yanlış vaat.

**Düzeltilen 7 iddia — hepsi bu teslimde uygulandı:**

| # | İlk hâli | Düzeltilmiş hâli |
|---|---|---|
| 1 | "Yapay zekâ kotası için üç çelişen rakam var; kullanıcıya gösterilen değer belirsiz" | Kullanıcıya gösterilen değer `ai_credit_model.dart:10-11` üzerinden **2/20** ve sunucuyla (`functions/index.js:30-31`) **birebir uyumlu**. `app_config_model.dart:71-72` (5/50) ve `subscription_model.dart:47-51` (10/50) **hiç okunmayan ölü yapılandırma**. Kullanıcıya görünen tutarsızlık yok; risk, uzaktan yapılandırmanın etkisiz olması |
| 2 | "Rıza geri çekme için hiçbir kontrol yok" | İki kullanım anı kapısı **var** (`food_scan_screen.dart:233-241` yerel bayrak; `gym_discovery_screen.dart:134-151` OS izni) ama hiçbiri Firestore rıza kaydını okumuyor. Sonuç aynı — geri çekme etkisiz — ama gerekçe farklı |
| 3 | "Squad büyük olasılıkla hiç çalışmıyor" | **DOĞRULANAMADI.** Statik analizde kural çelişkisi var, çalışma zamanı testi yapılmadı. Durum hükmü olarak "çalışmıyor" kullanılmaz (bkz. D13) |
| 4 | "Türkiye veritabanı yok" | Kapsam daraltıldı: **barkodla eşleşen TR paketli ürün kaynağı** yok. TR yemek verisi (`dish_data.dart`, 75 yemek) ve TR il/ilçe verisi (`turkish_locations.dart`) **var** |
| 5 | "Kilo Firestore'a gitmiyor" | **Günlük kilo ve su serisi** cihazda. Onboarding'de bir kez girilen kilo `private/nutrition` altına yazılıyor (`onboarding_provider.dart:241`) |
| 6 | "`occupancy` → 0 eşleşme, salon hiçbir devam verisi görmüyor" | `occupancy|capacity|doluluk` gerçekten 0; ama `getWeeklyAttendanceStream` (`gym_service.dart:453`) son 7 günün gün bazlı devam grafiğini salon sahibine gösteriyor. Anlık doluluk yok iddiası geçerli |
| 7 | "`FeatureGateService` ölü kod" | Servisin **kapı yarısı** ölü (`check()` → 0 çağrı yeri), **ödeme duvarı yarısı canlı** (`showPaywall()` → 3 çağrı yeri). Bulgu aslında daha geniş: `Entitlements` sınıfının tamamı okunmuyor, yani hiçbir özellik hak kontrolüyle kapatılmıyor |

**Düzeltilen dosya hataları:** 3 yanlış dosya yolu (`voice_assistant_overlay`, `create_post_card`, `cooking_mode_screen` satır aralığı) · `functions/index.js` satır numarası 31-32 → 30-31 · `app_config_model.dart` 52-53 → 71-72 · `firestore.rules` salon blokları 426-429/467-470 → 425-433/467-475 · `hero-data.ts` içinde "12.400 sütun"un TR nüshası (`:782`) ve statik çipi (`:853`) düzeltme listesine eklendi · 05 ve 06 numaralı dosyaların öncelik özet tabloları gövdeden yeniden sayıldı (risk toplamı 38 → **40**, ACİL 13 → **15**) · ana tabloya eksik olan **X-17** satırı (kök doküman PII sızıntısı) eklendi · 02 numaralı dosyaya eksik olan **EK BULGULAR** bölümü eklendi.

**Kabul edilen, düzeltilmeyen bulgular:**
- `03` numaralı dosyadaki marka sesi kural 3'ü (birinci çoğul şahıs yasağı) ile düzeltme metinlerinin "yayımlayacağız / kullanıyoruz" dili arasındaki gerilim, kuralın kapsamı netleştirilerek çözüldü: yasak, **ürünü övmek için** kullanılan birinci çoğulu kapsar; veri sorumlusu olarak taahhüt veren hukuki ve bilgilendirici metinlerde birinci çoğul kullanılır.
- `01` numaralı dosyada bazı durum hücreleri kanonik etiketin yanında parantezli niteleme taşıyor (ör. "KISMEN VAR · tek yön"). Etiket her zaman izin verilen altı değerden biriyle başlar; niteleme okunabilirlik içindir.
