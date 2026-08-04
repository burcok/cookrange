# 00 — YÖNETİCİ ÖZETİ

**Cookrange üç kaynaklı doğruluk denetimi · 4 Ağustos 2026**
Kaynaklar: `cookrange/` (uygulama, v0.9.6 dahili alfa, Flutter) · `cookrange-landing/` (site, Astro, **canlı**) · `cookrange-landing/docs/` + basın kiti + personalar + blog (pazarlama)

---

## RAKAMLAR

**Denetlenen:** 60 özellik maddesi (61 tablo satırı; madde 60, madde 28 ile birleştirildi) · 17 çapraz bulgu · 14 ek bulgu (uygulamada var, listede yok) = **92 satır**
**Bulunan çakışma: 64** · Temiz: 27

| Tip | Adet | Anlamı |
|---|---|---|
| **TİP A** | **25** | Site iddia ediyor, uygulama yapmıyor — **yanıltıcı beyan riski** (17'si çekirdek maddede, 8'i çapraz bulgu) |
| TİP A-TERS | 3 | Uygulama içi metin gerçeği aşıyor — *bu tipi kontrol listesi öngörmemişti* |
| TİP B | 17 | Uygulama yapıyor, site anmıyor — kaybedilen değer |
| TİP C | 4 | Aynı özellik, farklı isim |
| TİP D | 8 | Aynı özellik, farklı rakam |
| TİP E | 7 | Kapsam uyuşmazlığı — ücretsiz/Premium, izinli/izinsiz |

**Öncelik:** ACİL 26 · YÜKSEK 19 · ORTA 32 · DÜŞÜK 12 *(ana tablo satırları; 05 numaralı site düzeltme listesindeki satır bazlı öncelikler ayrıca sayılmıştır)*
**Risk raporu:** 40 risk — yanıltıcı beyan 10 · sağlık iddiası 5 · veri ve mahremiyet 25

**Canlı site kaynakla birebir aynı.** `cookrangeapp.com` üzerinde beş sayfa çekildi, sapma 0. Bu rapordaki her site bulgusu şu an yayında.

---

## EN KRİTİK 5 BULGU

### 1. Ürünün tüm konumlandırması var olmayan bir özelliğe dayanıyor
"Sıfırlamak yerine uyum sağlayan sistem" — markanın çekirdek karşıtlığı, birincil anahtar kelimesi, sözlük tanımı, karşılaştırma sayfası ve hero anlatısının tamamı **uyum motoruna** dayanıyor. Uyum motoru yok. Yakılan kalori yalnızca ekranda gösteriliyor (`home.dart:1179-1198`); kalori hedefini değiştirmiyor, plan yeniden hesaplanmıyor, ve planın yeniden üretim hash'inde kilo, aktivite ve tüketim **hiç yok** (`weekly_meal_plan_service.dart:316-321`).

Bu tek bulgu sitenin yarısını etkiliyor. Özelliği yapmak Efor **L**; iddiayı geri çekmek bir oturum.

### 2. Sponsorlu ürün katmanının tamamı kurgu — ve ücretsiz katmanın finansman gerekçesi bu
`sponsor` kelimesi uygulamanın ~115 bin satırında **0 kez** geçiyor. Buna karşılık site bir özellik sayfası, bir hero sahnesi, iki SSS ve **bir KVKK maddesi** yayınlıyor; sıralama kuralını ("±%10 kalori, en az %90 protein"), susturma anahtarını, indirim kodunu ve ₺18/₺32 fiyat örneğini veriyor. `hero-data.ts:705` bu katmanı açıkça **"ücretsiz katman nasıl finanse ediliyor"** gerekçesi olarak sunuyor.

Kaldırıldığında "temel özellikler her zaman ücretsiz" taahhüdünün arkasında hiçbir gelir mekanizması kalmıyor. Bu artık bir metin sorunu değil, **iş modeli kararı**.

### 3. Her kullanıcı, her başka kullanıcının e-postasını ve IP geçmişini okuyabiliyor
`firestore.rules:113-115` kullanıcı kök dokümanını tüm oturumlulara açıyor (kural yorumu: "Users can read any profile"). İçinde: e-posta (`firestore_service.dart:134`), giriş IP geçmişi (`:142`, `:628`), cihaz bilgisi, FCM token (`push_notification_service.dart:408`), hedef kilo ve hedef (`onboarding_provider.dart:221`).

Site "kimse bir başkasının vücut verisine erişemez" diyor (`guvenlik.astro:17-19`). Uygulamanın **kendi kararı** (ADR-009, `CLAUDE.md` §5.5) hedef kilonun kök dokümanda tutulmasını yasaklıyor. KVKK aydınlatma metni işlenen veriler listesinde IP adresini hiç saymıyor. Düzeltmesi Efor **S** ve ilk salon pilotunun engelleyicisi.

### 4. Salon ve koç mahremiyet vaatlerinin ikisi de kodda tutmuyor
**Salon:** Site "Bir salon yalnızca kendi **toplam** doluluğunu görür, bireysel kullanıcı verisine erişimi yoktur" diyor. Gerçekte salon her üyenin adını, fotoğrafını, katılım tarihini ve tam devam geçmişini okuyor (`firestore.rules:425-433, 467-475`), 14 gündür gelmeyenlerin isim listesini üretiyor (`gym_analytics_service.dart:99-104`) ve `uid,name,joined_at,total_checkins,last_checkin,tier` başlıklı **CSV indiriyor** (`:137-170`; fotoğraf CSV'de değil, analitik ekranında). Ayrıca satılan anlık "doluluk" özelliği hiç yok — `occupancy|doluluk` → 0 eşleşme; var olan şey son 7 günün devam grafiği ve 60 günlük yoğun saat deseni.

**Koç:** Koç yapay zekâ raporu danışanın verisini OpenRouter'a (yurt dışı) gönderiyor. Dosyada `consent`, `permission`, `isPremium` kelimelerinin **hiçbiri geçmiyor**; tek kapı `AIService().isConfigured` (`coach_client_detail_screen.dart:100-152`). `ConsentPurpose` kümesinde koç erişimi diye bir amaç yok. Danışan bu işlemeyi ne görüyor ne durdurabiliyor.

Buna bağlı olarak Rıza Merkezi'nin kendisi de dekoratif: `hasConsent` tüm ağaçta yalnızca tek bir yerden çağrılıyor (`consent_service.dart:73-92`) — **7 amaçtan yalnızca `analytics` rıza kaydından uygulanıyor.** Yapay zekâ fotoğrafı (`food_scan_screen.dart:233-241`, yerel `SharedPreferences` bayrağı) ve konum (`gym_discovery_screen.dart:134-151`, OS izni) için kullanım anı kapıları var, ama hiçbiri Firestore rıza kaydını okumuyor. Sonuç aynı: **Rıza Merkezi'nden sağlık verisi, yapay zekâ ya da yurt dışı aktarım rızasını geri çekmek hiçbir davranışı değiştirmiyor.**

### 5. Beş uydurma rakam, ve biri marka kuralının içine yerleşmiş
| Rakam | Nerede | Gerçek |
|---|---|---|
| **"~2,4 saniye"** barkod | 20+ dosya | Ölçüm yok. Kaynak küresel Open Food Facts; barkodla eşleşen TR paketli ürün kaynağı yok |
| **"34 ürün, 7 market reyonu"** | 8 sayfa | `Ingredient` modelinde kategori alanı yok; yalnızca 2 grup var |
| **"Altı kişi, tek seri"** (squad) | Özellik sayfası, **sözlük**, **yayınlanmış changelog** | 6 = davet kodu uzunluğu. Üye sınırı yok, ortak seri yok; güvenlik kuralları katılmayı engelliyor görünüyor (çalışma zamanı testi yapılmadı) |
| **"12.400 sütun"** | Ana sayfa eyebrow | Kaynağı yok, tanımı yok. Sıfır kullanıcılı üründe **kullanıcı sayısı gibi okunuyor** |
| **"en az 1.000 hesaplık kohort"** | **KVKK aydınlatma metni** | Kohort mekanizması kodda yok. Uygulanmamış bir gizlilik kontrolü hukuki sonuç ilan etmek için kullanılıyor |

`docs/TONE-OF-VOICE.md:14` "2,4 saniye"yi **iyi somut sayı örneği** olarak kural metnine gömmüş. Kök sebep şu: marka sesi kurallarında *"metne giren her sayı gösterilebilir olmalı"* diye bir madde yok. Beş rakamın hepsi tasarım mock'undan metne geçmiş.

---

## ÖNERİLEN İLK 3 AKSİYON

### Aksiyon 1 — Bir oturumda 9 TİP A çakışması kapat *(bugün, kod yok)*
`ozellikler/sponsorlu-urunler.astro` ve EN karşılığı `noindex` ile geri çekilir. `hero-data.ts` içinden 8 satır kaldırılır: "12.400 sütun" üç kopyası (`:699` EN, `:782` TR, `:853` çip) · "pazar günü yazıldı" (`:731`) · "Altı sütun, tek bir seri" iki dili (`:685`, `:768`) · "28 ÖĞÜN · 34 ÜRÜN · 7 REYON" çipi · feragatsız projeksiyon kiloları (`:851`) · `partners` sahnesi (`:705-706`, `:854`). KVKK metnindeki 1.000 hesaplık kohort maddesi çıkarılır.
**Kapanan:** 9 TİP A · en ağır ölçek iddiası · en riskli KVKK beyanı. **Ayrıntı:** 05 numaralı dosya.

### Aksiyon 2 — Uygulamanın kendi yalanını düzelt *(bu hafta, 5 dize)*
Premium satın alma ekranı beş şey satıyor, uygulama beşini de yapmıyor: "Sınırsız Plan" (gerçek: 20/gün) · "Reklamsız deneyim" (uygulamada reklam SDK'sı **hiç yok**) · "Öncelikli AI işleme" (rate limit iki kademede aynı) · "Gelişmiş öğün özelleştirme" (yok) · "Detaylı beslenme analitiği" (ücretsizde var).
Bu bir pazarlama cümlesi değil, **ödeme alan ekranın ürün tanımı** — tüketici hukuku ve mağaza inceleme riski. Site burada uygulamadan daha dürüst; sitenin dili uygulamaya taşınır.

### Aksiyon 3 — İki kapıyı kur, sonra pilotu başlat *(v1.0 öncesi, yalnızca bu ikisi)*
- **N1 · Veri sızıntısını kapat.** Kök dokümandan e-posta, IP, token ve hedef kilo `private/` altına. Efor **S**.
- **N2 · Özellik bayraklarını gerçekten bağla.** `isFeatureEnabled` ve `isInRollout` yazılmış ama **0 çağrı yerine** sahip. Salon (13 ekran), koç (8), program (3) ve squad yüzeyleri bayrağa takılır; "Developer / Test Modu" anahtarı `kDebugMode` + `isAdmin` arkasına alınır. Efor **M**.

N2 tek başına 30'dan fazla maddeyi lansman engelleyicisi olmaktan çıkarıyor: rıza kontrolü olmayan koç raporu, kırık squad ve son kullanıcıya açık sahte veri modu — üçü de kapatılabilir hâle geliyor. **Yol haritasındaki en yüksek kaldıraç budur.**

> **Bir uyarı:** `docs/GYM_ECOSYSTEM.md`, `docs/COACH_ECOSYSTEM.md` ve ADR-012 bu yüzeylerin "kill-switch arkasında durduğunu" söylüyor. Durmuyorlar — yan menüden canlı erişilebilir. Bu varsayımla alınmış her ürün kararı yeniden gözden geçirilmeli.

---

## KAYBEDİLEN DEĞERİN BOYUTU
Denetim yalnızca fazla iddia bulmadı; **eksik anlatım da buldu.** Uygulamada çalışan ve sitede hiç geçmeyen 17 yüzey var. En büyükleri:

- **Yapay zekâ sohbeti ve sesli asistan** — profil bağlamlı, prompt injection korumalı, çalışıyor. Sitede yok.
- **Tam bir topluluk katmanı** — akış, öğün fotoğrafı paylaşımı, yorum, tepki, "Signal" dürtme, birebir ve grup sohbeti, başarım rozetleri (`community.*` 67 + `chat.*` 23 + `signal.*` 10 + `achievements.*` 15 localization anahtarı). Sitede topluluk = squad + salon sıralaması.
- **Salon savaşları** — iki salonun 7 gün check-in yarışı, arayüzü canlı. Site anmıyor, **uygulama "YAKINDA GELECEK" etiketi taşıyor**, doküman "effectively unbuilt" diyor. Üç kaynakta da görünmez bir çalışan özellik.
- **Salon başvuru hattı** — 2 zorunlu belge, 6 haneli OTP, 2-5 iş günü SLA (`gym.docs_count`, `gym.phone_otp_hint`, `gym.app_pending_step2`). Salon pilotunun satış hunisi hazır ve sitede yok.
- **75 Türk yemeği** — sitenin kullanmadığı, doğrulanabilir tek somut rakam.

---

## KORUNACAKLAR
Denetimin işi kötü haberi bulmak, ama bu üçü doğru kurulmuş ve bozulmaması gerekiyor:

1. **Uydurma değerlendirme puanı yok.** `aggregateRating`, `ratingValue`, `reviewCount`, kullanıcı sayısı → `src/` ve `public/` genelinde 0 eşleşme. `schema.ts:6-9` bunu bilinçli karar olarak belgelemiş. Acil risk hipotezi çürütüldü.
2. **Konum vaadi kodda doğru.** `checkin_model.dart:52-58` lat/lon alanı taşımıyor; mesafe istemcide hesaplanıp atılıyor. Sitenin ve kodun en net örtüştüğü yer.
3. **Lansman durumu beyanı dürüst.** Mağaza linkleri kasıtlı `null` (`constants.ts:9-11`), `/indir` "Uygulama henüz mağazada değil" diyor, sağlık feragatnameleri beş yerde güçlü ifadeyle mevcut, blogdaki tüm yüzdeler akademik kaynaklı. Sitenin en iyi yönetilen alanı.

Ayrıca: **alerjen filtresi iddiadan güçlü** — havuzda güvenli yemek kalmazsa plan hiç üretilmiyor, ve site bunu söylemiyor bile.

---

## BİR CÜMLEYLE
Cookrange'in kodu, sitesinin anlattığı üründen **daha küçük ama farklı yerlerde daha iyi**: satılan uyum motoru ve sponsorlu katman yok, buna karşılık satılmayan bir topluluk katmanı, bir sesli asistan ve çalışan bir salon yarışması var. Ayrışmanın kök sebebi tek: **hiçbir kaynakta "bu sayının kanıtı nerede" diye soran bir kural yoktu.** 03 numaralı sözlük o kuralı koyuyor.

---

## TESLİM EDİLEN DOSYALAR
| Dosya | İçerik |
|---|---|
| `00-YONETICI-OZETI.md` | Bu dosya |
| `01-OZELLIK-ENVANTERI.xlsx` | 92 satırlık ana tablo — filtrelenebilir, renk kodlu (TİP A ve TİP A-TERS kırmızı, diğer çakışmalar sarı, temiz yeşil) + formüllü özet sekmesi + okuma notu |
| `02-CAKISMA-RAPORU.md` | Çakışmalar tip sırasına göre: bulgu, kanıt, uygulanan kural, karar, düzeltme metni. 51 çakışma ayrı başlık altında; 12 ek bulgu çakışması özet tabloda (ayrıntısı xlsx'te) |
| `03-SOZLUK.md` | **Terminoloji kilidi** — her özelliğin kanonik TR/EN adı, tek cümlelik tanımı, kanonik rakamı, yasak eş anlamlıları. En kalıcı çıktı |
| `04-URUN-YOL-HARITASI.md` | Puanlama, dört kova (ŞİMDİ'de 2 madde), gerekçeler, kopyala-yapıştır TODO bloğu |
| `05-SITE-DUZELTME-LISTESI.md` | Sayfa sayfa, satır satır: şu anki metin / olması gereken metin — doğrudan uygulanabilir |
| `06-RISK-RAPORU.md` | 38 risk üç başlıkta, her biri için düzeltme metni |
| `07-VARSAYIMLAR.md` | 14 varsayım gerekçesiyle + 16 DOĞRULANAMADI maddesi ve tam olarak neye bakılacağı |

Uygulama repo'sunun kökündeki `TODO.md` dosyasının **sonuna** tarihli bir bölüm eklendi (`## Denetim bulguları — 2026-08-04`). Var olan hiçbir satır silinmedi veya değiştirilmedi. `uygulama/` ve `site/` klasörlerindeki hiçbir kaynak kod dosyasına dokunulmadı.
