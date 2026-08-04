# 04 — ÜRÜN YOL HARİTASI

Cookrange · 4 Ağustos 2026 · Denetim çıktısı
Puanlama: **Stratejik ağırlık** 1-5 (salon/koç/topluluk hendeğine hizmet ediyor mu) · **Kullanıcı etkisi** 1-5 · **Efor** S/M/L (kod tabanına bakılarak, gerekçesiyle) · **Engelleyici** (v1.0 için şart mı)

---

## ÖNCE ŞUNU OKU: BU YOL HARİTASININ YARISI KOD DEĞİL, METİN

Denetim çekirdek 60 maddede 17, çapraz bulgularla birlikte toplam 24 TİP A çakışması buldu — sitede iddia edilen, uygulamada olmayan özellikler. **Bunların çoğu için doğru cevap özelliği yapmak değil, iddiayı kaldırmaktır.** İddia kaldırma 05 numaralı dosyada, bu yol haritasında değil; efor toplamda birkaç saat, risk azalması ise anında.

Bir alfa ürününe lansman öncesi özellik yığmak çıkmama sebebidir. Bu yüzden **ŞİMDİ kovasında sadece 2 madde var** ve ikisi de özellik değil, kapı: biri veri sızıntısını kapatıyor, öbürü yarım kalmış 30+ yüzeyi görünmez kılıyor.

---

# ŞİMDİ (v1.0 öncesi) — EN FAZLA 2 MADDE

## N1 · Kişisel veri sızıntısını kapat
**Ne:** `users/{uid}` kök dokümanı şu an her oturumlu kullanıcıya okunabilir ve içinde e-posta, giriş IP geçmişi, cihaz bilgisi, FCM token ve hedef kilo var. Bunlar owner-only bir alt dokümana taşınır.
**Kanıt:** `firestore.rules:115` (`allow read: if isAuthenticated()`) · `lib/core/services/firestore_service.dart:134` (`'email'`), `:141` (`'login_ips': FieldValue.arrayUnion([...ip_address])`) · `lib/core/services/push_notification_service.dart:407-410` (`fcm_token`) · `lib/core/providers/onboarding_provider.dart:216-217` (`target_weight`, `main_goal`)
**İkincil kapsam:** `food_logs` için `update`/`delete` serbest (`firestore.rules:163-165`) → seri, liderlik tablosu ve başarım oyunlaştırması manipüle edilebilir. Aynı dosyada `checkins` için `allow update, delete: if false` deseni **hazır**.

| Ölçüt | Değer |
|---|---|
| Stratejik ağırlık | **5** — salon pilotunda gerçek kullanıcı verisi var; sızıntı hendeği değil hukuki yükümlülüğü büyütür |
| Kullanıcı etkisi | **5** |
| Efor | **S** — `firestore.rules` + iki alanın `private/` alt dokümanına taşınması; desen aynı dosyada mevcut |
| Engelleyici | **EVET** |
| Bağımlılıklar | Yok |

**Neden ŞİMDİ:** "Bu özellik olmadan ilk salon pilotu başlayabilir mi?" → **Hayır.** Pilotta gerçek üyeler olacak; her üyenin e-postasını ve IP geçmişini her başka üye okuyabiliyor. `guvenlik.astro:17-19` "kimse bir başkasının vücut verisine erişemez" diyor ve uygulamanın kendi `CLAUDE.md` §5.5 (ADR-009) hedef kilonun kök dokümanda olmasını **yasaklıyor**. Bu, kendi kararına aykırı bir uygulama hatası; düzeltmesi küçük.

## N2 · Özellik bayraklarını gerçekten bağla
**Ne:** `isFeatureEnabled` ve `isInRollout` yazılmış ama **hiçbir yerden çağrılmıyor**. `FeatureGateService().check()` de öyle — aynı servisin `showPaywall()` yarısı 3 yerden çağrılıyor (`discover_hub_screen.dart:143`, `program_detail_screen.dart:54`, `settings_screen.dart:1654`), yani ödeme duvarı canlı ama **hiçbir özellik hak kontrolüyle kapatılmıyor**. Salon (13 ekran), koç (8 ekran), program pazarı (3 ekran), squad ve "Test Modu" yüzeyleri bu bayraklara takılır; pilotta kapatılabilir hâle gelir.
**Kanıt:** `lib/core/models/app_config_model.dart:216` (`isFeatureEnabled` — 0 tüketici) · `lib/core/services/app_config_service.dart:124` (`isInRollout` — 0 tüketici) · `feature_voice_assistant` ve `feature_nutrition_analytics` **varsayılan `false` ama okunmadığı için özellikler açık** · `lib/screens/profile/settings_screen.dart:1191-1213` (Test Modu anahtarı `kDebugMode` ve `isAdmin` korumasından yoksun)
**Doküman çelişkisi:** `docs/GYM_ECOSYSTEM.md:6-8`, `docs/COACH_ECOSYSTEM.md:6-8` ve ADR-012 bu yüzeylerin "kill-switch arkasında durduğunu" söylüyor. Durmuyorlar — yan menüden canlı erişilebilir.

| Ölçüt | Değer |
|---|---|
| Stratejik ağırlık | **5** — hendek yüzeylerinin tamamının açılış kontrolü bu tek maddede |
| Kullanıcı etkisi | **4** — kullanıcı yarım özellik görmez |
| Efor | **M** — mekanizma hazır, ~25 ekran girişine ve router guard'a bağlanması gerekiyor |
| Engelleyici | **EVET** |
| Bağımlılıklar | Yok. N1'den bağımsız, paralel yürür |

**Neden ŞİMDİ:** "Bu özellik olmadan ilk salon pilotu başlayabilir mi?" → **Hayır.** Pilotta kapatılması gereken üç şey var ve hiçbiri kapatılamıyor: (a) rıza kontrolü olmayan koç yapay zekâ raporu (KVKK bulgusu R3), (b) büyük olasılıkla hiç çalışmayan squad katılımı, (c) son kullanıcıya açık Test Modu — açıldığında salon keşfi, liderlik tablosu ve öğün planı **sahte veri** gösteriyor. Bu madde, diğer 30 maddeyi lansman engelleyicisi olmaktan çıkarır. Yol haritasındaki en yüksek kaldıraç budur.

### ŞİMDİ'ye alınmayanlar ve neden
| Aday | Neden SONRA |
|---|---|
| Uyum motoru (11) | Konumlandırmanın çekirdeği ama pilot bunsuz başlayabilir — metin düzeltmesiyle bugün risksiz hâle gelir. Özelliği aceleyle yapmak, alfa ürününü daha da geciktirir. |
| Rıza geri çekmenin çalışması (50) | KVKK açısından ciddi, ama pilotta katılımcı sayısı sınırlı ve geri çekme yolu olarak sunucu tarafı hesap silme **çalışıyor** (`functions/account.js:48`). **v1.0 halka açık lansman engelleyicisi** — ŞİMDİ değil, SONRA'nın en başı. |
| Koç rıza akışı (26) | N2 bunu bayrakla kapatarak pilot süresince nötralize eder. Yüzey geri açıldığında şart. |
| Salon veri sınırı (49) | Kod değişikliği değil, **aydınlatma** sorunu. 05 ve 06 numaralı dosyalardaki metin düzeltmesiyle kapanır. |
| Squad'ın çalışması (36) | Topluluk hendeğinin parçası ama pilot salon check-in'i üzerinden yürüyebilir. N2 ile kapatılır, sonra düzeltilir. |
| Doluluk sayacı (22) | Salona satılan şey; ama yoğun saat deseni (23) zaten var ve pilot onunla başlayabilir. Satış konuşması düzeltilir. |

---

# SONRA (v1.1 – v1.2)

| # | Madde | Strat. | Etki | Efor | Engelleyici | Bağımlılık | Efor gerekçesi |
|---|---|---|---|---|---|---|---|
| S1 | **Rıza geri çekmeyi koda bağla** (50) — `hasConsent` çağrılarını healthData / aiProcessing / crossBorderTransfer / location / notifications yollarına tak; location ve notifications rıza kaydını yaz | 3 | 4 | **M** | **v1.0 halka açık lansman: EVET** | N2 | `consent_service.dart:73-85` hazır, tek tüketicisi var; ~8 çağrı noktası eklenecek |
| S2 | **Koç rıza akışı** (26) — `ConsentPurpose`'a koç erişimi eklenir, koç yapay zekâ raporu bu kapıya bağlanır | 5 | 4 | **M** | Koç yüzeyi açılacaksa EVET | S1 | Yeni amaç + izin ekranı + `coach_client_detail_screen.dart:100-152` kapısı |
| S3 | **Kilo ve su verisini sunucuya taşı** (40) — Hive'dan Firestore'a, `private/` altına | 2 | 5 | **S** | HAYIR | N1 | Model ve kural deseni hazır; telefon değişince veri kaybını bitirir |
| S4 | **Squad'ı çalışır hâle getir** (36) — davet koduyla katılma için kural/indeks düzeltmesi, üye tavanı, ortak seri hesabı | 5 | 4 | **M** | HAYIR | N2 | Kural değişikliği S; ortak seri hesabı yeni mantık M |
| S5 | **Uyum motoru** (11) — yakılan kaloriyi hedefe bağla, kalan öğünleri yeniden hesapla, kayıtlı öğüne dokunma | 4 | 5 | **L** | HAYIR | S6 | Yeniden üretim hash'ine kilo/aktivite/tüketim eklenmesi + kısmi yeniden hesaplama mantığı + kayıt değişmezliği; ürünün en büyük tek işi |
| S6 | **Değişmezlik kuralı** (12) — `food_logs` için update/delete kısıtı | 3 | 3 | **S** | HAYIR | Yok | `firestore.rules` içinde `checkins` deseni birebir uygulanabilir |
| S7 | **`swapMeal` toplam güncelleme hatası** (07) — değiştirme sonrası `total_calories` ve `macros` yeniden hesaplanır | 1 | 4 | **S** | HAYIR | Yok | `weekly_meal_plan_service.dart:259-277`, tek fonksiyon |
| S8 | **Market listesi reyon gruplaması** (08) — `Ingredient`'a kategori alanı, 7 reyona eşleme | 1 | 3 | **S** | HAYIR | Yok | Model alanı + sabit eşleme tablosu; **sitenin en ucuz TİP A kapanışı** |
| S9 | **Salon doluluk sayacı** (22) — check-out kaydı ya da oturum penceresi, anlık sayaç | 5 | 3 | **M** | HAYIR | N2 | Yeni veri modeli (check-out ya da TTL) + toplama sorgusu |
| S10 | **Salon analitiğinde limitsiz okuma** — `members` ve 60 günlük check-in'ler `.limit()` olmadan okunuyor; CSV tüm zamanları çekiyor | 3 | 2 | **S** | HAYIR | Yok | `gym_analytics_service.dart:38-48`, `:139`; sayfalama eklenecek. Maliyet ve performans riski |
| S11 | **Sunucu tarafı check-in doğrulaması** (24) — yarıçap kontrolü istemcide, sahtelenebilir | 4 | 2 | **M** | Salona doğrulama satılıyorsa EVET | Yok | `firestore.rules:471-472` yalnızca uid arıyor; Cloud Function ya da kural içi mesafe kontrolü |
| S12 | **Seri tabanı kararı** (37) — giriş tabanlı seriyi kayıt tabanına çevir | 3 | 4 | **M** | HAYIR | S6 | `firestore_service.dart:180-191`; oyunlaştırmanın anlamı buna bağlı |
| S13 | **Projeksiyon grafiği** (41) — 30/60/90 gün için gerçek kesikli çizgi | 2 | 3 | **M** | HAYIR | S3 | Kilo verisi sunucuda olmadan anlamlı grafik çizilemez |
| S14 | **Hesap silmenin eksik kalan kısımları** (R10) — salon check-in'lerindeki ad ve fotoğraf, koç bağları, `privacy_requests` e-postası | 2 | 3 | **M** | v1.0: EVET | N1 | `functions/account.js:63-85` + 3 koleksiyonda `delete: if false` kuralının gevşetilmesi |
| S15 | **i18n değer paritesi testi** (52) — CI anahtar değil değer karşılaştırsın; çevrilmemiş TR dizeleri (6 doğrulanmış, üst sınır 15 — bkz. 07/D14) ve 3 dosyadaki sabit İngilizce etiket düzeltilsin | 1 | 2 | **S** | HAYIR | Yok | `test/i18n_parity_test.dart` genişletilir |
| S16 | **Android `minSdkVersion` sabitlenmesi** (51) — site "Android 8" diyor, repo sabit taşımıyor; bundle id çelişkisi de düzeltilir | 2 | 2 | **S** | Mağaza kaydı: EVET | Yok | `android/app/build.gradle:79` + `pubspec.yaml:16` ↔ `project.pbxproj:496` |
| S17 | **Kayıt boşluğu telafisi bildirimi** (61) — 500 kullanıcı tavanı kaldırılır, üç parça tek akışta birleşir | 3 | 3 | **M** | HAYIR | Yok | `functions/index.js:941` sayfalama + akış tasarımı |
| S18 | **Salon savaşlarının "YAKINDA" etiketleri** (54) — çalışan özellik gizli; etiket kaldırılır, otomatik bitiş eklenir | 4 | 3 | **S** | HAYIR | N2 | Etiket kaldırma S; otomatik bitiş küçük bir scheduled function |
| S19 | **Topluluk ve yapay zekâ sohbetinin siteye eklenmesi** (18, 34, 35) — kod işi değil, içerik işi | 4 | 3 | **S** | HAYIR | Yok | İki özellik sayfası bölümü; kaybedilen değerin en büyük parçası |

---

# DEĞERLENDİR
> Karar gerektiren, kod değil strateji maddeleri.

| # | Madde | Neden değerlendirmede |
|---|---|---|
| D1 | **Sponsorlu ürün katmanı** (44-47) | Ücretsiz katmanın beyan edilen finansman mekanizması bu. Kaldırıldığında iş modeli boşta kalıyor. Yapılacaksa: ürün eşleştirme verisi, fiyat kaynağı, marka ortağı sözleşmesi ve **gerçek bir kohort mekanizması** gerekir — KVKK metni şu an var olmayan bir mekanizmaya dayanıyor. Efor **L**. Karar: bu mu, yoksa başka bir gelir modeli mi? |
| D2 | **Salon gelir modeli** (20, 28/60) | `TODO.md:2496` GYM-07 kendi notu: *"The gym ecosystem is a distribution bet with no revenue model defined."* Salon tarafı ürünün en büyük hendeği ve hiç geliri yok. Ürün kararı, kod kararı değil. |
| D3 | **Ücretli koçluk ve program satışı** (30, 31) | Payout sağlayıcısı, komisyon oranı, vergi ve `marketplace_terms` sunumu gerekli. `assets/legal/marketplace_terms_{tr,en}.md` paketli ama uygulamada gösterilmiyor (`LegalDocumentType` içinde yok). Efor **L**. |
| D4 | **Bütçeye göre plan** (05) | Basın kiti bu iddiayı taşıyor ama özellik yok ve **ürün fiyat verisi de yok**. Yapılabilmesi D1'e bağlı (fiyat kaynağı). Ya D1 ile birlikte yapılır ya iddia kalıcı olarak kalkar. |
| D5 | **Hane modu** (55) | Onboarding hane büyüklüğünü **topluyor** ama ölçekleme rafta (`onboarding_provider.dart:44` "shelved"); `TODO.md:2263` NUT-11 Icebox. Veri zaten toplandığı için efor **M**. Hedef kitle kararı: tek kişi mi hane mi? |
| D6 | **Ramazan / özel dönem modları** (57) | `TODO.md:3158` ICE-21. Türkiye pazarında yüksek sezonsal etki, düşük teknik risk (öğün zamanlaması + sahur/iftar pencereleri). Efor **M**. Zamanlama kararı: Ramazan 2027'ye yetişmesi için v1.2. |
| D7 | **Diyetisyen onay katmanı** (59) | `TODO.md:2513` COA-04 kendi risk notu: *"Approving unverified people to give nutrition advice is a liability. The screens exist; the standard does not."* **Önce standart, sonra kod.** Koç incelemeleri de şu an ilişki doğrulaması olmadan yazılabiliyor. |
| D8 | **Seri tabanı** (37) | **S12'nin karar adımı, ayrı bir iş değil.** Önce bu karar verilir, sonra S12 uygulanır: seri neyi ödüllendiriyor — uygulamayı açmayı mı, kayıt tutmayı mı? |

---

# REDDET

| # | Madde | Neden reddedildi |
|---|---|---|
| R1 | **Salon TV modu** (58) | Ne kodda ne backlog'da hiçbir izi yok; `FUTURE_FEATURES.md` §B'de de geçmiyor. Salon donanımına bağımlı, doluluk sayacı olmadan gösterecek verisi yok (S9'a bağımlı), ve talep kanıtı sıfır. Salon pilotundan gerçek talep gelirse yeniden değerlendirilir. |
| R2 | **Market listesinin online sipariş sepetine aktarılması** (56) | `TODO.md:3159` ICE-22. Market zinciriyle entegrasyon sözleşmesi, ürün eşleştirme (SKU) ve sepet API'si gerektiriyor — üçü de yok. Alfa aşamasında bir alfa ürününün taşıyamayacağı iş ortaklığı yükü. Var olan çözüm (listeyi metin olarak paylaşma, `sharing_service.dart:111-133`) yeterli. |
| R3 | **Salonlar arası haftalık meydan okuma "yapılması"** (54) | **Reddedilen bir yapım işi, çünkü zaten var.** `gym_leaderboard_service.dart:98-104`, varsayılan 7 gün, arayüzü canlı. Yapılacak iş yeni özellik değil, S18: yanlış "YAKINDA" etiketinin kaldırılması. |
| R4 | **Sponsorlu ödül / indirim kodu** (47) | D1 kararı verilmeden bu tek başına yapılamaz; ayrıca ödül sisteminin tamamı şu an içsel (bonus kredi, başarım, seri dondurma) ve tutarlı çalışıyor. Dış ödül eklemek gelir modeli kararından önce yapılırsa sistemi bozar. |

---

# KOPYALA-YAPIŞTIR TODO BLOĞU

```
## Denetim bulguları — 2026-08-04

### ŞİMDİ (v1.0 öncesi — en fazla 2)
- [ ] [S] [ŞİMDİ] N1 Kişisel veri sızıntısını kapat: users/{uid} kök dokümanından email, login_ips, fcm_token, target_weight, main_goal → private/ altına; firestore.rules:115 daralt. İkincil: food_logs update/delete kısıtı (firestore.rules:163-165). ENGELLEYİCİ
- [ ] [M] [ŞİMDİ] N2 Özellik bayraklarını bağla: isFeatureEnabled/isInRollout'u salon (13 ekran), koç (8), program (3), squad yüzeylerine ve router guard'a tak; Test Modu anahtarını kDebugMode+isAdmin arkasına al (settings_screen.dart:1191-1213). ENGELLEYİCİ

### SONRA (v1.1–1.2)
- [ ] [M] [SONRA] S1 Rıza geri çekmeyi koda bağla; location+notifications rıza kaydını yaz (consent_service.dart:73-100). v1.0 halka açık lansman engelleyicisi
- [ ] [M] [SONRA] S2 Koç rıza akışı: ConsentPurpose'a koç erişimi, coach_client_detail_screen.dart:100-152 kapısı
- [ ] [S] [SONRA] S3 Kilo ve su verisini Hive'dan Firestore private/ altına taşı (storage_service.dart:20)
- [ ] [M] [SONRA] S4 Squad'ı çalışır hâle getir: inviteCode kural+indeks, üye tavanı, ortak seri (streak_squad_service.dart:82-113)
- [ ] [L] [SONRA] S5 Uyum motoru: yakılan kaloriyi hedefe bağla, kalan öğünleri yeniden hesapla (weekly_meal_plan_service.dart:316-321)
- [ ] [S] [SONRA] S6 Değişmezlik kuralı: food_logs update/delete kısıtı
- [ ] [S] [SONRA] S7 swapMeal sonrası total_calories ve macros yeniden hesaplansın (weekly_meal_plan_service.dart:259-277)
- [ ] [S] [SONRA] S8 Ingredient modeline kategori alanı + 7 reyon eşlemesi (ingredient_model.dart)
- [ ] [M] [SONRA] S9 Salon doluluk sayacı: check-out kaydı ya da oturum penceresi
- [ ] [S] [SONRA] S10 Salon analitiğinde sayfalama; CSV tüm zamanları çekmesin (gym_analytics_service.dart:38-48, :139)
- [ ] [M] [SONRA] S11 Check-in yarıçapını sunucu tarafında doğrula (firestore.rules:471-472)
- [ ] [M] [SONRA] S12 Seri tabanını girişten kayda çevir (firestore_service.dart:180-191)
- [ ] [M] [SONRA] S13 Projeksiyon grafiği (30/60/90, kesikli) — S3'e bağımlı
- [ ] [M] [SONRA] S14 Hesap silmede eksik kalan koleksiyonlar (functions/account.js:63-85)
- [ ] [S] [SONRA] S15 i18n değer paritesi testi + çevrilmemiş TR dizeleri (6 doğrulanmış, üst sınır 15) + 3 dosyada sabit İngilizce etiket
- [ ] [S] [SONRA] S16 Android minSdkVersion 26 sabitle; bundle id çelişkisini gider (build.gradle:79, pubspec.yaml:16)
- [ ] [M] [SONRA] S17 Kayıt boşluğu telafisi: 500 kullanıcı tavanını kaldır, üç parçayı birleştir (functions/index.js:941)
- [ ] [S] [SONRA] S18 Salon savaşlarındaki "YAKINDA" etiketini kaldır, otomatik bitiş ekle (gym.feature_challenges)
- [ ] [S] [SONRA] S19 Topluluk akışı ve yapay zekâ sohbetini siteye ekle (kaybedilen değer, TİP B)

### DEĞERLENDİR
- [ ] [L] [DEĞERLENDİR] D1 Sponsorlu ürün katmanı: yapılacak mı? Ücretsiz katmanın finansman beyanı buna dayanıyor, kodda hiç yok
- [ ] [?] [DEĞERLENDİR] D2 Salon gelir modeli (TODO.md:2496 GYM-07 — "no revenue model defined")
- [ ] [L] [DEĞERLENDİR] D3 Ücretli koçluk + program satışı: payout sağlayıcı, komisyon, marketplace_terms sunumu
- [ ] [?] [DEĞERLENDİR] D4 Bütçeye göre plan — D1'e bağımlı (fiyat verisi kaynağı)
- [ ] [M] [DEĞERLENDİR] D5 Hane modu (veri toplanıyor, ölçekleme rafta — onboarding_provider.dart:44)
- [ ] [M] [DEĞERLENDİR] D6 Ramazan / özel dönem modları (TODO.md:3158 ICE-21) — Ramazan 2027 için v1.2
- [ ] [?] [DEĞERLENDİR] D7 Diyetisyen onay katmanı: önce standart, sonra kod (TODO.md:2513 COA-04)
- [ ] [?] [DEĞERLENDİR] D8 Seri neyi ödüllendiriyor: uygulamayı açmayı mı, kayıt tutmayı mı? (S12'nin karar adımı — ayrı iş değil)

### REDDET
- [ ] [—] [REDDET] R1 Salon TV modu — kodda ve backlog'da iz yok, doluluk sayacına bağımlı, talep kanıtı yok
- [ ] [—] [REDDET] R2 Market listesi → online sipariş sepeti (TODO.md:3159 ICE-22) — market entegrasyonu alfa yükü değil
- [ ] [—] [REDDET] R3 Salonlar arası meydan okuma "yapımı" — zaten var, iş S18'de
- [ ] [—] [REDDET] R4 Sponsorlu ödül / indirim kodu — D1 kararından önce yapılamaz

### METİN İŞLERİ (kod değil — 05 ve 06 numaralı denetim dosyaları)
- [ ] [ACİL] 17 çekirdek TİP A iddiası siteden kaldırılsın: bütçe (05), ikame (07), reyon+34 ürün (08), serbest metinle plan özelleştirme (09), uyum motoru (11), değişmezlik (12), tarif arama (15), TR barkod veritabanı+2,4 sn (17), doluluk (22), ücretli koçluk kipi (31), squad altı kişi+tek seri (36), ağırlık takibi (40), kesikli çizgi+kilo değerleri (41), sponsorlu katmanın tamamı (44-47)
- [ ] [ACİL] "12.400 sütun" kaldırılsın (hero-data.ts:699)
- [ ] [ACİL] Premium ekranındaki 5 yanlış vaat düzeltilsin (tr.json / en.json)
- [ ] [ACİL] Salon veri sınırı gerçeğe göre yazılsın (faq salon-veri-erisimi, guvenlik.astro:31)
- [ ] [ACİL] Veri dışa aktarma SSS'si düzeltilsin: uygulamada 24 kaynaklı tek-tuş ihracat VAR, site "yok" diyor (faq/tr/veri-disa-aktarma.md)
- [ ] [ACİL] KVKK metnindeki 1.000 hesaplık kohort maddesi çıkarılsın (mekanizma yok)
- [ ] [ACİL] yol-haritasi.astro:11 "tamamlandı" iddiası düzeltilsin
- [ ] [YÜKSEK] Alt işleyici listesine OpenRouter, Apple/Google Play, OpenStreetMap eklensin
- [ ] [YÜKSEK] applicationCategory HealthApplication → LifestyleApplication (schema.ts:68)
- [ ] [YÜKSEK] 30 gelecek tarihli blog yazısı draft:true ya da tarih filtresi
- [ ] [YÜKSEK] Aşama adı tek ada indirilsin: "v0.9.6 dahili alfa" (16 yerde "private beta" geçiyor)
- [ ] [ORTA] pubspec.yaml version 1.0.0+1 → 0.9.6
- [ ] [ORTA] schema.ts offers kaldırılsın ya da locale'e göre TRY/USD + ComingSoon
- [ ] [ORTA] inLanguage sabiti düzeltilsin (schema.ts:191 — EN yazılar tr-TR beyan ediyor)
- [ ] [ORTA] www canonical yönlendirmesi (vercel.json)
- [ ] [ORTA] MyFitnessPal karşılaştırma tablosuna tarih ve kaynak; "Salon entegrasyonu: Yok" yumuşatılsın
- [ ] [ORTA] Persona B2B etkinlik vaadi ("salona gitme sıklığını artırıyor") kaynaklandırılsın ya da koşullu kipe çevrilsin
```
