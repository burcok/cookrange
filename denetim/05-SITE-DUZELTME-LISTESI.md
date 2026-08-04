# 05 — SİTE DÜZELTME LİSTESİ

Cookrange · 4 Ağustos 2026 · **Doğrudan uygulanabilir**
Her satır: sayfa · bölüm · şu anki metin · olması gereken metin · gerekçe · öncelik
Marka sesi: tüketiciye ikinci tekil (sen) · salon ve koça ikinci çoğul (siz) · kısa cümle · somut sayı · iddia değil mekanizma · ünlem ve emoji yok

**Canlı site kaynakla birebir aynı** (`cookrangeapp.com` üzerinde `/`, `/fiyatlandirma`, `/ozellikler`, `/basin-kiti`, `/indir` doğrulandı) — yani aşağıdaki her madde şu an yayında.

EN karşılıkları: her TR düzeltmesi `src/pages/en/...` içindeki eşleşen sayfada da uygulanır. Sayfa çiftleri `src/lib/routes.ts` ile eşlenmiştir; 48 TR sayfanın 48'inin EN karşılığı var.

---

## ACİL — 1. SAYFA YAYINDAN GERİ ÇEKİLECEK

### `src/pages/ozellikler/sponsorlu-urunler.astro` + `src/pages/en/features/sponsored-products.astro`
**Sayfanın tamamı var olmayan bir özelliği anlatıyor.** `sponsor` kelimesi uygulamanın ~115k satırında **0 kez** geçiyor.

| Öncelik | Aksiyon |
|---|---|
| **ACİL** | Sayfa `noindex` + menüden çıkarılır (silinmez). Yerine tek paragraflık bir "iş modeli" notu konur. |

**Yerine konacak metin (TR):**
> ## Ücretsiz katmanı nasıl finanse edeceğiz
> Cookrange'in temel özellikleri ücretsiz. Bunu sürdürülebilir kılacak modeli henüz açıklamadık. Açıkladığımızda kuralları da yayımlayacağız: neyin önerildiğini, neye göre sıralandığını ve nasıl kapatıldığını. Şu an uygulamada sponsorlu ürün önerisi bulunmuyor.

**EN:**
> ## How the free tier will be funded
> Cookrange's core features are free. We have not yet announced the model that keeps them that way. When we do, we will publish the rules with it: what gets suggested, what it is ranked by, and how you switch it off. There are no sponsored suggestions in the app today.

**Aynı kaldırma kapsamındaki diğer yerler:**

| Sayfa | Bölüm | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|---|
| `src/components/hero/hero-data.ts:705-706, 854` | `partners` sahnesi | "₺0 · How the free tier is funded" / "₺18 lor ... ₺32 protein barı" / "0 sponsorlu öğe" | Sahne tamamen kaldırılır | Özellik yok; ayrıca ana sayfada ücretsiz katmanın finansman gerekçesi olarak duruyor | ACİL |
| `src/content/faq/tr/sponsorlu-urunler-reklam-mi.md` | tamamı | "sıralama fiyata göre yapılır, bize kim ödeme yaptığına göre değil" | Geri çekilir (`draft: true`) | Var olmayan mekanizmanın kuralını anlatıyor | ACİL |
| `src/content/faq/tr/sponsorlu-urunler-premium.md` | tamamı | "kapatma anahtarı Premium'a bağlı değildir" | Geri çekilir (`draft: true`) | Aynı | ACİL |
| `src/content/faq/{tr,en}/markalar-verimi-goruyor-mu / brands-data-access` | tamamı | "yalnızca en az 1.000 hesaplık gruplar hâlinde toplu, kimliksizleştirilmiş sayılar" | Geri çekilir | Kohort mekanizması kodda yok (`cohort` → 0 eşleşme) | ACİL |
| `src/pages/legal/kvkk-aydinlatma-metni.astro:106, 121, 143-147` | §5 aktarım | "marka ortaklarına yalnızca en az 1.000 hesaplık gruplar ... iletilir — bu, KVKK m.3 anlamında ... kişisel veri aktarımı teşkil etmez" | Madde çıkarılır | **Uygulanmamış bir gizlilik kontrolünü var gibi anlatmak, aydınlatma yükümlülüğünün ihlalidir.** Sitenin kendi `docs/LEGAL-REVIEW.md:79-86` maddesi bunu istiyor: "yanlışsa bu bölümün tamamı yeniden yazılmalıdır" | ACİL |
| `src/pages/fiyatlandirma.astro:74` | gelir kalemleri | "salonlar, koçlar ve white-label iş birlikleri" (mevcut zaman) | "Gelir modelini yayımladığımızda burada anlatacağız." | Üç gelir hattının hiçbiri kodda yok | ACİL |

---

## ACİL — 2. ANA SAYFA (`src/pages/index.astro` → `src/components/hero/hero-data.ts`)

Ana sayfanın tüm metni `hero-data.ts` `narrativeCopy.tr` (satır 714-796) ve statik yedek çipleri (satır ~840-860) içinde. Sayfa `chrome="none"` — header/footer render edilmiyor.

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:699` (EN eyebrow) | "12,400 columns · One substrate" | **Rakam kaldırılır.** Yerine: "One substrate" | Rakamın kaynağı yok, tanımı yok. Sıfır kullanıcılı, mağazada olmayan bir üründe **kullanıcı sayısı gibi okunuyor**. `docs/TONE-OF-VOICE.md:19` kendi kuralı bunu yasaklıyor | **ACİL** |
| `:782` (TR eyebrow) | "12.400 sütun · Tek bir altyapı" | **Rakam kaldırılır.** Yerine: "Tek bir altyapı" | Aynı — TR nüshası. Bu satır atlanırsa iddia canlıda kalır | **ACİL** |
| `:853` (statik çip) | `field: ["12.400 sütun"]` | Çip kaldırılır | Aynı rakamın üçüncü kopyası, feragat ya da bağlam olmadan | **ACİL** |
| `:731` | "Hafta, pazar günü yazıldı." | "Haftalık planını sen üretirsin. Pazartesi sabahı hatırlatma gelir." | Sunucuda plan üreten cron yok; bildirim pazartesi 07:00 UTC (`functions/index.js:997`) | ACİL |
| `:739` | "Atladığın kayıt bir daha geri gelmeyen veridir." | "Bir gün kayıt tutmazsan o gün boş kalır. Geri kalan gün buna göre yeniden hesaplanır; geçmişe dönük ceza yoktur." | Marka sesi kuralı: suçlayıcı olmayan. Blogun kendi tonu bu (`blog/tr/yeni-baslayanlar-icin-ilk-30-gun-rehberi.md:70`) | YÜKSEK |
| `:754` | "Birini kanepeden kaldıran bildirim budur — üçüncü haftanın alışkanlığı öldürmemesinin nedeni de bu." | "Karşılıklı arkadaşın salona girdiğinde bildirim alırsın." | Mutlak nedensellik iddiası, ürünün hiç kullanıcı verisi yok | YÜKSEK |
| `:769` | "Elde tutma stratejisinin tamamı bu." | "Topluluk katmanı bu yüzden var." | Aynı — ölçülmemiş etkinlik iddiası | ORTA |
| `:774, 851` | "+30g 76.9 kg · +60g 75.8 kg · +90g 75.1 kg" (statik çip, **feragat metni olmadan**) | Çipler kaldırılır. Anlatıdaki feragat cümlesi ("bir söz değil, bir öngörü") korunur | Uygulamada grafik yok, bu üç değer kodda yok, ve çip hâlinde feragatsız duruyor | ACİL |
| `:768` (TR başlık) · `:685` (EN başlık) | "Altı sütun, tek bir seri." / "Six columns, one streak." | "Arkadaşlarının serileri yan yana" / "Your friends' streaks, side by side" | Uygulamada altı sınırı yok (6 = davet kodu uzunluğu), ortak seri yok | ACİL |
| `:784` | "Bir koç kendi kadrosunu okur." | "Bir koç kendi danışan listesini okur." | Salon kadro paneli yok; "kadro" o paneli çağırıyor | ORTA |
| `:794` | "Kayıt, planlar, tarifler… ücretsiz ve eksiksiz" | "Kayıt ve haftalık plan ücretsiz. Yapay zekâ üretimi günde 2 ile sınırlı." | Ücretsiz katmanın tek gerçek kısıtı bu ve site onu hiç söylemiyor. Kanonik kaynak: `functions/index.js:30-31` ve `ai_credit_model.dart:10-11` (ikisi uyumlu) | ACİL |
| Statik çipler `:840-860` | "28 ÖĞÜN · 34 ÜRÜN · 7 REYON" | "28 ÖĞÜN · TEK LİSTE" | Reyon gruplaması yok, 34 kaynaksız | ACİL |
| Statik çipler | "8690504010203" barkod + "389 kcal/100 g" + tarama süresi | Barkod çipi kalır (gerçekçi TR GS1 örneği), **süre çipi kaldırılır** | 2,4 saniye ölçümü yok | ACİL |
| Tüm anlatı | "1.2 km / 92.5 kg / 76.9 kg" (nokta) ↔ "1,2 km / 92,5 kg" (virgül) aynı sayfada | TR yüzeyde her yerde **virgül** | Ondalık ayırıcı tutarsızlığı; aynı ana sayfada yan yana duruyor | DÜŞÜK |
| Tüm hero | Görünür "örnek veri" uyarısı yok (`grep temsili\|illustrative` → 0) | Simülasyon telefonun altına bir satır: "Ekranlardaki veriler örnektir." | Hero'nun tamamı mock; ziyaretçi bunu bilmiyor | YÜKSEK |

---

## ACİL — 3. ÖZELLİK SAYFALARI

### `src/pages/ozellikler/yapay-zeka-koc.astro` (EN: `en/features/ai-coach.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:15` | "3,2 km yürüdün. Plan bunu zaten biliyor." | "3,2 km yürüdün. Yakılan kalori günün üstünde görünür. Planı yeniden ürettiğinde bu veriyi hesaba katar." | Uyum motoru yok: yakılan kalori hedefi değiştirmiyor, plan yeniden hesaplanmıyor (`home.dart:1179-1198`, `weekly_meal_plan_service.dart:316-321`) | **ACİL** |
| `:24` | "Kaydedilmiş hiçbir öğün geriye dönük değiştirilmez." | "Plan geçmiş kayıtlarını yeniden yazmaz." | Kural düzeyinde koruma yok (`firestore.rules:163-165`); daraltılmış hâli doğru | YÜKSEK |
| `:38` | "\"muza çikolata sosu döktüm\" yazarsın, plan güncellenir." | "\"muza çikolata sosu döktüm\" yazarsın; yapay zekâ besin değerini çıkarır ve kaydına ekler." | Serbest metinle besin analizi var, plan özelleştirme yok (`prompt_service.dart` 3 prompt, kullanıcı metni parametresi yok) | **ACİL** |
| — | Yapay zekâ **sohbeti** ve **sesli asistan** sayfada hiç yok | Yeni bölüm eklenir (aşağıdaki metin) | Çalışan, farklılaştırıcı özellik sitede görünmüyor — TİP B | YÜKSEK |

**Eklenecek yeni bölüm (TR):**
> ### Sorabilirsin
> Aklına takılanı yazarsın ya da söylersin. Yapay zekâ senin profilini, hedefini ve son kayıtlarını bilerek cevap verir. Ücretsiz katmanda günde 2, Premium'da günde 20 soru.

**EN:**
> ### You can just ask
> You type it or say it. The AI answers knowing your profile, your goal and your recent logs. Two a day on the free tier, twenty on Premium.

### `src/pages/ozellikler/beslenme-ve-planlama.astro` (EN: `en/features/nutrition-planning.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:15` | "Hafta, pazar günü yazıldı." | "Haftalık planını istediğin an üretirsin." | Aynı — pazar günü mekanizması yok | ACİL |
| `:24` | "filtre sen öğünleri görmeden önce uygulanır" | **Korunur** + eklenir: "Havuzda güvenli yemek kalmazsa plan üretilmez. 8 alerjen grubu tanınıyor." | İddia doğru ve kod iddiadan güçlü — K3 uyarınca somutlaştırılır. "12 alerjen" YAZILMAZ (anahtarlar örtüşüyor) | ORTA |
| `:33` | "Türkiye barkod veritabanı ürünü tanır ve yaklaşık 2,4 saniye sonra sonucu gösterir." | "Barkodu okutursun. Ürün Open Food Facts veritabanından çekilir; kalori ve makro bilgisi kaydına eklenir." | Kod küresel `world.openfoodfacts.org/api/v0` kullanıyor, TR filtresi yok, yerel `products` koleksiyonu yok; 2,4 saniyenin kaynağı yok | **ACİL** |
| `:33` | "beş yolu var: günün planı, hızlı ekle, tarif arama, fotoğraf, barkod" | "beş yolu var: günün planı, hızlı ekle, barkod, fotoğraf analizi, tarif üretimi. Tarif üretimi günlük yapay zekâ kotasından düşer." | "Tarif arama" arama değil, kotalı AI üretimi (`explore_screen.dart:59-67, :77`). Fotoğrafın kotaya bağlılığı DOĞRULANAMADI (07/D1) — bu yüzden metin yalnızca tarif üretimini adlandırıyor | **ACİL** |
| `:59` | "Haftanın 28 öğünü 34 ürüne indirgenir ve 7 market reyonuna göre gruplanır." | "Haftanın 28 öğünündeki malzemeler tek listede toplanır. Aldıkça işaretlersin; işaretlediğin ürünler sepete geçer." | Reyon alanı `Ingredient` modelinde yok; yalnızca 2 grup var (`shopping_list_screen.dart:298-301`) | **ACİL** |
| — | Yemek sayısı verilmiyor | Eklenir: "Havuzda 75 Türk yemeği var." | Sitenin kullanmadığı, doğrulanabilir tek somut rakam (`dish_data.dart`) — K3 | ORTA |

### `src/pages/ozellikler/salon-ekosistemi.astro` (EN: `en/features/gym-ecosystem.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:39` | "Salon kendi doluluğunu ve yoğun saatlerini görür ... salonun hiçbir zaman erişimi olmaz" | "Salonunuz kendi check-in sayısını ve son 60 günün yoğun saat desenini görür. Üye listenizi ve check-in kayıtlarınızı görünen ad düzeyinde görürsünüz. Üyelerin beslenme geçmişine, kilo verisine ve ölçümlerine erişemezsiniz." | Doluluk özelliği yok (`occupancy\|doluluk` → 0); salon **bireysel** veri görüyor ve CSV indiriyor (`firestore.rules:426-429, 467-470`; `gym_analytics_service.dart:137-170`). Hitap salona olduğu için baştan sona ikinci çoğul | **ACİL** |
| `:34` | "İzni reddedersen ... aynen çalışmaya devam eder" | "Konum iznini reddedersen yakındaki salon sıralaması kapanır; kaydın, planın ve serin etkilenmez." | Rıza geri çekme yalnızca `analytics` için gerçekten uygulanıyor (`consent_service.dart:73-92`); "aynen çalışır" kapsamı belirsiz | YÜKSEK |
| `:23` | "yalnızca karşılıklı arkadaşlar arasında ve opt-in'dir" | **Korunur** ✅ | Kodda doğrulandı (`friend_service.dart:16-20`, sunucu otoritatif) | — |
| — | Salon savaşları anılmıyor | Eklenir: "İki salon 7 gün boyunca check-in sayısıyla yarışabilir." | Özellik var (`gym_leaderboard_service.dart:98-104`), sitede yok — TİP B | ORTA |
| — | Liderlik tablosu kapsamı verilmiyor | Eklenir: "Salon sıralaması haftalık, ilk 200 üye." | K3 somutlaştırma (`gym_service.dart:337`) | DÜŞÜK |

### `src/pages/ozellikler/topluluk-ve-squad.astro` (EN: `en/features/community-squad.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:15` | "Altı sütun, tek bir seri" | "Arkadaşlarının serileri yan yana" | 6 = davet kodu uzunluğu; üye sınırı yok, ortak seri yok (`streak_squad_service.dart:24-30, :171-187`) | **ACİL** |
| `:26` | "40 günlük bir seri \"bugün risk altında\"" | **Korunur**, ama seri tanımı düzeltilir: "Seri, uygulamaya art arda girdiğin gün sayısı." | Seri **giriş** tabanlı, kayıt tabanlı değil (`firestore_service.dart:180-191`) | YÜKSEK |
| `:39-41` | "davranış değişikliği literatüründe hesap verebilirlik ortağı etkisi olarak bilinen ve genellikle yalnız çabalardan daha güçlü çalışan bir mekanizma" | Kaynak eklenir (blogda zaten var: Wing & Jeffery 1999) ya da "araştırmalar bunu … olarak tanımlıyor" biçiminde koşullu kurulur | Adı verilmemiş araştırmaya atıf; blogdaki aynı iddia kaynaklı | ORTA |
| — | Topluluk akışı, öğün fotoğrafı paylaşımı, sohbet, "paylaş = kaydet" anılmıyor | Yeni bölüm (aşağıda) | `community.*` 67 anahtar + `chat.*` 23 + `signal.*` 10 — tam bir sosyal katman sitede görünmüyor. Denetimdeki en büyük kaybedilen değer | YÜKSEK |

**Eklenecek yeni bölüm (TR):**
> ### Akış
> Pişirdiğin yemeği paylaşırsın. Tek onayla hem kaydın oluşur hem gönderi çıkar — iki ayrı iş değil. Gönderiler yorum ve tepki alır; arkadaşların serisi düzleştiğinde görünür. Birebir ve grup sohbeti de aynı yerde.

**EN:**
> ### The feed
> You share what you cooked. One confirmation logs it and posts it — not two separate jobs. Posts take comments and reactions, and a friend's flattening streak shows up. Direct and group chat sit in the same place.

### `src/pages/ozellikler/ilerleme-analizi.astro` (EN: `en/features/progress-analytics.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:20` | "squat'ının 60 kilodan 92,5 kiloya çıktığı bir Aralık" | "Aralık ayında kaç gün kayıt tuttuğun, ne kadar kalori ve protein aldığın ve serinin nerede durduğu görünür." | Ağırlık/set/tekrar metriği hiç yok; Firestore'da kalori + 4 makro + egzersiz kalorisi + seri var | **ACİL** |
| `:26` | "Şubat ayında sadece dokuz gün ... Bu veri silinmez" | "Şubat ayında sadece dokuz gün kayıt tuttuysan, o dokuz gün orada durur; boş günler doldurulmaz." | Boşluk koruma doğru ✅ (`food_log_service.dart:248-251`), ama "silinmez" kural düzeyinde garanti değil | ORTA |
| `:32, :46-49` | "kesikli çizgiyle, çünkü bu bir tahmin, bir garanti değil ... +30 günde 76,9 kg, +60 günde 75,8 kg, +90 günde 75,1 kg" | "30, 60 ve 90 gün için bir tahmin yazar. Tahmin bir söz değil: kayıt alışkanlığın değiştiğinde tahmin de değişir." | Grafik yok, çıktı serbest metin (`ai_insight_service.dart:212-214`); üç kilo değeri kodda yok | **ACİL** |
| `:62` | "Bir koç kendi sporcusunun ilerlemesini okur." | "Bir koç, danışanı olduğun sürece ilerlemeni okur. Rapor üretmek için adın ve seri bilgin yapay zekâ sağlayıcımıza gönderilir; bu yurt dışında işlenen bir aktarımdır." | Koç yapay zekâ raporunda **hiç rıza kontrolü yok** (`coach_client_detail_screen.dart:100-152`) — bkz. 06 numaralı dosya R3 | **ACİL** |
| — | Kilo verisinin cihazda olduğu söylenmiyor | Eklenir: "Kilo kayıtların şu an yalnızca telefonunda tutuluyor." | `storage_service.dart:20` Hive `weight_box`; telefon değişince kayboluyor. "Sınırsız uzun vadeli geçmiş" vaadiyle çelişiyor | YÜKSEK |

### `src/pages/ozellikler/premium.astro` (EN: `en/features/premium.astro`)
Sayfa uygulamadan **daha dürüst**. Tek ekleme:

| Öncelik | Aksiyon |
|---|---|
| ORTA | Kota rakamı eklenir: "Ücretsiz katmanda günde 2, Premium'da günde 20 yapay zekâ üretimi." Kaynak: `functions/index.js:31-32` (sunucu otoritesi). Not: istemci varsayılanı 5/50 farklı — gösterilecek değer sunucu değeri. |

---

## ACİL — 4. FİYATLANDIRMA (`src/pages/fiyatlandirma.astro`, EN: `en/pricing.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:9` | "Sınırsız öğün kaydı (barkod, hızlı ekle, tarif arama, fotoğraf)" | "Sınırsız öğün kaydı — barkod, hızlı ekle ve fotoğraf" | Tarif üretimi yapay zekâ kotasından düşüyor, "sınırsız" onun için yanlış. Fotoğrafın kotaya bağlılığı DOĞRULANAMADI (07/D1) — doğrulanırsa o da listeden çıkar | **ACİL** |
| `:10` | "Salon check-in, doluluk görünürlüğü ve arkadaş bildirimleri" | "Salon check-in ve arkadaş bildirimleri" | Doluluk özelliği yok | **ACİL** |
| `:11` | "Squad'lar ve seri takibi" | "Seri takibi" (Squad çalışır hâle gelene kadar) | Squad'a davet koduyla katılma güvenlik kurallarıyla çelişiyor, büyük olasılıkla hiç çalışmıyor | YÜKSEK |
| `:13` | "Sınırsız uzun vadeli ilerleme geçmişi" | "Uzun vadeli ilerleme geçmişi. Kilo kayıtların şu an yalnızca telefonunda tutuluyor." | Kilo verisi sunucuda değil | YÜKSEK |
| — | Yapay zekâ kotası hiç yazılmıyor | Ücretsiz kartına eklenir: "Günde 2 yapay zekâ üretimi (plan, tarif üretimi, sohbet)." Premium kartına: "Günde 20." | Ücretsiz katmanın tek gerçek kısıtı; sayfa "kaç plan üretebilirim?" sorusunu soruyor ve cevaplamıyor (`ai-yemek-plani-olusturma.astro:54`). Kanonik: `functions/index.js:30-31` = `ai_credit_model.dart:10-11` | **ACİL** |
| `:8-14` | "her zaman ücretsiz kalacak" (6 yerde) | "Bu özellikler ücretsiz katmanda yer alıyor." | "Her zaman" süresiz hukuki taahhüt; alfa aşamasında verilmemeli | YÜKSEK |
| `:74` | "salonlar, koçlar ve white-label iş birlikleri" | "Gelir modelini yayımladığımızda burada anlatacağız." | Üç hattın hiçbiri kodda yok | ACİL |
| EN `$0` | `en/pricing.astro` → "$0" | "₺0" | EN yüzeyin geri kalanı ₺ kullanıyor (`hero-data.ts` EN "₺0", "₺18", "₺32"); `$` yalnızca 1 yerde | ORTA |

---

## ACİL — 5. YOL HARİTASI (`src/pages/yol-haritasi.astro`, EN: `en/roadmap.astro`)

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:11` | "Beslenme planlama, barkod kaydı, salon check-in, squad'lar ve ilerleme analizi **tamamlandı**." | "Beslenme planlama, barkod kaydı ve salon check-in çalışıyor. Squad'lar ve ilerleme analizi geliştirme aşamasında." | Beş sistemin üçünde temel eksik: barkod → TR paketli ürün kaynağı yok · squad → altı sınırı ve ortak seri yok · ilerleme → ağırlık metriği yok, kilo cihazda. Uygulamanın kendi `PROJECT_STATE.md`'si 9 açık blocker sayıyor. Düzeltme metni üçüncü şahıs tutulur — aynı sayfanın birinci çoğul ihlali aşağıda ayrıca düzeltiliyor | **ACİL** |
| `:32, :50` | "Nereden nereye gidiyoruz", "Yönümüzü neyle ölçüyoruz" | "Nereden nereye" / "Yön neyle ölçülüyor" | `docs/TONE-OF-VOICE.md:17-18` birinci çoğul şahsı yasaklıyor | DÜŞÜK |

---

## YÜKSEK — 6. BASIN KİTİ (`src/pages/basin-kiti.astro`, EN: `en/press.astro`)
**En yüksek risk yüzeyi:** sayfa `:38` "düzenlenmeden kullanılmaları tercih edilir" diyor — gazeteci olduğu gibi basar.

| Satır | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `:44` (etiket) | "Kısa (**160 karakter**)" | "Kısa (**175 karakter**)" ya da metin 160'a indirilir | Gerçek uzunluk 175; 160'lık alan metni keser. EN karşılığı 143 — TR/EN arası 32 karakter fark "tam eşitlik" iddiasıyla çelişiyor | YÜKSEK |
| `:52-58` (orta) | "şu anda **beta öncesi** aşamadadır" | "şu anda **v0.9.6 dahili alfa** aşamasındadır" | Aynı sayfa `:23` ve `:69` "dahili alfa" diyor — boilerplate kendi sayfasıyla çelişiyor. EN'de aynı hata: "pre-beta" ↔ "internal alpha" | **ACİL** |
| `:64` (uzun) | "vücut verilerine, hedeflerine, alerjenlerine **ve bütçesine** göre üretilir" | "vücut verilerine, hedeflerine ve alerjenlerine göre üretilir" | Bütçe özelliği yok (`budget\|bütçe\|cost\|price` → 0 eşleşme). Bu iddianın **tek kaynağı** basın kiti | **ACİL** |
| `:65` | "gün içinde gerçek aktiviteye göre kendini günceller — plan sıfırdan yeniden üretilmez, yalnızca henüz yenmemiş öğünler ayarlanır" | "haftalık planı sen üretirsin; kayıtların ve hedefin değiştiğinde yeniden üretebilirsin" | Uyum motoru yok | **ACİL** |
| `:66` | "tek tek **atıştırmalıklar da serbest metinle düzenlenebilir**" | "yediğini serbest metinle yazarsın; besin değeri çıkarılıp kaydına eklenir" | Plan/öğün serbest metinle düzenlenemiyor | **ACİL** |
| `:24` | "iOS ve Android (planlanan) · iOS 14+ / Android 8+" | "iOS 14+ · Android sürüm eşiği yayınla birlikte açıklanacak" | Android minSdk repoda sabit değil (`build.gradle:79`), 26'ya çözülmüyor | YÜKSEK |
| `:97` | "yayına hazır ekran görüntüleri henüz burada değil" | **Korunur** ✅ | Dürüst | — |

---

## YÜKSEK — 7. SSS VE SÖZLÜK (`src/content/faq/`, `src/content/glossary/`)

| Dosya | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `ozellikler/topluluk-ve-squad.astro:13` (description) | "Altı kişi tek bir seriyi paylaşır." | "Arkadaşlarının serileri yan yana durur." | Sayfa `h1` ile aynı yanlış; meta description olarak arama sonucunda da görünüyor | **ACİL** |
| `glossary/tr/squad.md:5` + `glossary/en/squad.md:5` | "aynı seriyi paylaşan **altı kişilik** bir hesap verebilirlik grubudur" | "arkadaşlarının serilerini yan yana gördüğün gruptur; birinin sütunu düzleşirse diğerleri fark eder" | Kanonik tanım yanlış — bu, sözlük olduğu için diğer tüm metinlerin kaynağı | **ACİL** |
| `glossary/tr/adaptif-beslenme-plani.md:5` + EN | "gerçek aktivite ve kayıt verisine göre **gün içinde yeniden hesaplanan**" | "Adaptif beslenme planı, sabit bir liste yerine kayıt verisine göre yeniden üretilebilen plandır." (kavram yazısı olarak kalır, **ürün iddiası olarak kullanılmaz**) | Uyum motoru yok; terim aynı zamanda birincil anahtar kelime ve URL'de gömülü — URL korunur, tanım daraltılır | **ACİL** |
| `glossary/tr/seri-streak.md:5` + EN | "art arda **kayıt tutulan** veya antrenman yapılan gün sayısı" | "Seri, uygulamaya art arda girdiğin gün sayısıdır." | Seri giriş tabanlı (`firestore_service.dart:180-191`) | YÜKSEK |
| `glossary/tr/barkodla-besin-kaydi.md` + EN | "barkodunu telefon kamerasıyla tarayarak kalori ve makro bilgisini otomatik olarak öğün kaydına eklemektir" | **Korunur** ✅ (tanım doğru), yalnızca kaynak eklenir: "Veri Open Food Facts'ten gelir." | Tanım mekanizmayı doğru anlatıyor | DÜŞÜK |
| `faq/tr/salon-veri-erisimi.md` + `faq/en/gym-data-access.md` | "**Erişemez.** Bir salon yalnızca kendi **toplam** doluluğunu, yoğun saatlerini ve check-in sayısını görür" | "Salon işletmesi üye listesini ve check-in kayıtlarını görünen ad düzeyinde görür ve devam istatistiklerini dosya olarak indirebilir. Beslenme geçmişine, kilo verine ve ölçümlerine erişemez." | Salon bireysel veri görüyor + CSV ihracı var. Bu bir KVKK aydınlatma sorunu | **ACİL** |
| `faq/tr/koc-ve-arkadas-erisimi.md` + `faq/en/coach-friend-data-access.md` | "yalnızca senin ilerlemeni okur" (aktarım anılmıyor) | "Koçun ilerlemeni okur. Rapor üretirken adın ve seri bilgin yapay zekâ sağlayıcımıza gönderilir; bu yurt dışında işlenen bir aktarımdır." | Rıza kontrolü olmadan yurt dışına aktarım (`coach_client_detail_screen.dart:119-125`) | **ACİL** |
| `faq/tr/veri-disa-aktarma.md` + `faq/en/data-export.md` | "şu an uygulama içinde tek tuşla bir indirme düğmesi **yok**" | "Verilerini uygulama içinden indirebilirsin: Ayarlar → Verilerini Dışa Aktar." | **Site yanlış, uygulama doğru.** `data_export_service.dart:18-36` tek çağrıyla 24 kaynağı ihraç ediyor; site kullanıcıyı gereksiz e-posta başvurusuna yönlendiriyor | **ACİL** |
| `faq/tr/barkod-veritabani.md` + `faq/en/barcode-database.md` | "**about 2.4 seconds** ... **far more accurately recognized** than with generic international databases" | "Barkod okuma Open Food Facts verisini kullanır. Türkiye market ürünlerinde kapsama oranını ölçüyoruz; sonucu yayımlayacağız." | İki iddia da desteklenmiyor; ikincisi ayrıca kanıtsız karşılaştırma | **ACİL** |
| `faq/tr/ucretsiz-mi.md` + `faq/en/is-it-free.md` | "Sınırsız öğün kaydı, haftalık plan, salon check-in, squad'lar ve ilerleme geçmişi **her zaman ücretsiz kalacak**" | "Öğün kaydı, haftalık plan, salon check-in ve ilerleme geçmişi ücretsiz katmanda yer alıyor. Yapay zekâ üretimi günde 2 ile sınırlı." | "Her zaman" süresiz taahhüt; "sınırsız" ve "doluluk" yanlış; squad çalışmıyor | **ACİL** |
| `faq/en/account-deletion.md` | "Exact, category-by-category retention periods **will be published** ... once finalized" | Saklama süreleri yayımlanır (bkz. 06 numaralı dosya R11) | Açık hukuki eksik; KVKK metninde bölüm bile yok | YÜKSEK |
| `faq/tr/referans-linki.md` + `faq/en/referral-link.md` | "the more people you invite, **the sooner you get beta access**" | Mekanizma yazılır ya da iddia kaldırılır | Sıra hızlandırma mekanizması doğrulanamadı | ORTA |
| `faq/tr/diyetisyen-yerine-gecer-mi.md` | Resmî "siz" hitabı (diğer 21 TR SSS "sen") | "sen" hitabına çevrilir | Marka sesi tutarlılığı | DÜŞÜK |
| `faq/tr/veri-nerede-saklaniyor.md` | "koordinatların sunucuya gönderilmez" (dilbilgisi) + "yakınımdaki **arkadaş** sıralaması" | "Koordinatın sunucuya gönderilmez. Yakınındaki salon ve koç sıralaması cihazında hesaplanır." | `nearbyFriends` → 0 eşleşme; konumu kullanan gerçek özellikler salon ve koç keşfi | ORTA |
| `faq/en/notification-preferences.md` | Türkçe `/legal/acik-riza-metni` sayfasına link | Link EN yüzeyde açıklamayla verilir ya da EN karşılığı yazılır | TR-only yasal sayfa EN SSS'den linklenmiş | DÜŞÜK |

---

## YÜKSEK — 8. KARŞILAŞTIRMA SAYFALARI (`src/content/comparisons/`)

| Dosya | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `cookrange-myfitnesspal-karsilastirmasi.md:23` | "Salon entegrasyonu \| **Yok** \| QR check-in, doluluk görünürlüğü, arkadaş bildirimleri" | "Salon entegrasyonu \| Bu karşılaştırmanın yapıldığı tarihte belgelenmiş bir salon check-in özelliği bulunamadı (Ağustos 2026) \| QR check-in, arkadaş bildirimleri" | Rakip hakkında mutlak, kaynaksız, tarihsiz olumsuz iddia; ayrıca "doluluk" Cookrange'de de yok | YÜKSEK |
| `:22` | "Türkiye'ye özel, barkod bazlı, **~2,4 saniyede** sonuç" | "Barkod bazlı, Open Food Facts verisi" | Kendi ürünü hakkında yanlış | **ACİL** |
| `:23` (veritabanı satırı) | "Food database \| Large, global, **largely user-submitted** \| ..." | Satır kaldırılır ya da her iki kolon aynı kaynağı gösterir | **Karşılaştırma tersine dönmüş:** Cookrange tam olarak o veritabanını kullanıyor | **ACİL** |
| `:14` | "MyFitnessPal ... **milyonlarca kullanıcısı**" | Kaynak eklenir ya da rakam kaldırılır | Kaynaksız niceliksel iddia (rakip lehine de olsa) | ORTA |
| `adaptif-plan-vs-sabit-diyet-listesi.md` | "**A printed sheet from a dietitian** ... falls into the 'static plan' category" | "Basılı bir liste, tanımı gereği sabit plan kategorisindedir." | Diyetisyen çıktısına olumsuz genelleme | DÜŞÜK |

---

## YÜKSEK — 9. PERSONALAR (`src/content/personas/`)

| Dosya | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `tr/spor-salonlari.md:27-28` + `en/gyms.md:27` | "Üyelerin birbirini salonda bulması ve squad'lar, **salona gitme sıklığını da artırıyor**." | "Davranış değişikliği araştırmaları, hesap verebilirlik ortaklığının program tamamlama oranlarını yükselttiğini gösteriyor (Wing & Jeffery 1999). Cookrange bu mekanizmayı salon içine taşıyor; kendi üye verinizle etkiyi pilot süresince ölçeceğiz." | Kaynaksız, koşulsuz, mevcut zaman B2B sonuç vaadi. Ürünün hiç kullanıcı verisi yok. Salona satılan bir vaat olduğu için sözleşme riski | YÜKSEK |
| `tr/spor-salonlari.md:25-26` | "tek bir QR turnike sistemi hem check-in hem **doluluk görünürlüğü** sağlıyor" | "QR ile check-in alırsınız; son 60 günün yoğun saat desenini görürsünüz." | Doluluk yok | **ACİL** |
| `tr/kilo-yonetimi.md:26` | "telefonunun hareket verisini okuyarak **günlük hedefi güncelliyor** — yürüdüğün mesafe arttıkça kalan öğünler için alan açılıyor" | "Yürüdüğün mesafe ve yakılan kalori günün üstünde görünür." | Uyum motoru yok; ayrıca özel nitelikli veri işleme iddiası koşulsuz kurulmuş | **ACİL** |
| `tr/performans-sporculari.md` | "squat'ın 60 kilodan 92,5 kiloya çıkışı ... **hiçbir ay silinmiyor**" | "Kayıt tuttuğun her gün geçmişte kalıyor; boş günler doldurulmuyor." | Ağırlık metriği yok | **ACİL** |
| `tr/kocular.md:25` | "bir koç ... **okuyabilir**" (mevcut zaman) | "Koç yüzeyi hazırlanıyor; self-servis kayıt akışı henüz yok." | Aynı sitede iki gerçeklik: `blog/tr/koclar-icin-...md:62` "self-servis bir kayıt akışı **henüz yok**" diyor | YÜKSEK |
| `tr/spor-salonlari.md:32` ↔ `tr/kocular.md:31` | "ulaşabilirsiniz" ↔ "ulaşabilirsin" | B2B personalarda her yerde **"siz"** | Hitap tutarlılığı | DÜŞÜK |

---

## YÜKSEK — 10. TEKNİK / YAPILANDIRILMIŞ VERİ

| Dosya | Şu anki değer | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `src/lib/schema.ts:68` | `applicationCategory: "HealthApplication"` | `"LifestyleApplication"` | Sayfa metni "Cookrange bir tıbbi cihaz ya da **sağlık uygulaması değildir**" diyor (`ai-yemek-plani-olusturma.astro:132`). Makine beyanı hukuki feragatin tersi; KVKK açısından özel nitelikli veri iması | YÜKSEK |
| `src/lib/schema.ts:74-77` | `price: "0", priceCurrency: "USD", availability: PreOrder` | `offers` lansmana kadar kaldırılır; ya da locale'e göre TRY/USD + `ComingSoon` | `constants.ts:9-10` mağaza URL'leri `null` → ön sipariş mekanizması yok; TR sayfa ₺0 gösteriyor | ORTA |
| `src/lib/schema.ts:191` | `inLanguage: "tr-TR"` (sabit) | Locale'e göre `tr-TR` / `en-US` | ~15 İngilizce yazı kendini Türkçe beyan ediyor (`en/blog/[slug].astro:40` aynı fabrikayı çağırıyor) | ORTA |
| `src/lib/schema.ts:6-9` | AggregateRating üretici **kasıtlı olarak yok** | **Korunur** ✅ | Denetimin en önemli olumlu bulgusu: uydurma değerlendirme puanı riski yok | — |
| 30 blog dosyası (`publishDate`) | 15 EN + 15 TR yazı **gelecek tarihli**, hepsi `draft: false`. Örn. `blog/en/whats-new-in-v0-9-6-...md:7` → `2026-11-02` | `draft: true` ya da `src/pages/blog/[slug].astro:9`'a `publishDate <= new Date()` filtresi | Google `datePublished`'ın gerçek yayın tarihi olmasını şart koşuyor; gelecek tarih rich result bastırması ve "spammy markup" riski | YÜKSEK |
| `src/pages/llms-full.txt.ts:30-36` | Blog ve sözlük **gövdelerini** inline ediyor → "Türkiye'ye özel veritabanı", "2,4 saniye", "altı kişilik ortak seri" dahil | Yukarıdaki içerik düzeltmeleri yapıldıktan sonra otomatik düzelir; öncesinde `robots.txt` AI tarayıcı izni gözden geçirilir | `robots.txt.ts:28-79` 18 AI tarayıcısına `Allow: /` veriyor — her uydurma rakam LLM alıntısı için optimize | YÜKSEK |
| `astro.config.mjs:7` + `src/lib/constants.ts:1` | `https://www.cookrangeapp.com` | Canlı host **www'suz** yanıt veriyor → `vercel.json`'a yönlendirme eklenir | İki host aynı `@id`'lerle indekslenebilir | ORTA |
| `src/pages/degisiklik-notlari.astro` ← `src/content/changelog/{tr,en}/v0-9-6.md` | "**Türkiye barkod veritabanı** ... ortalama 2,4 saniyede" · "**Altı kişilik gruplar** artık **tek bir seriyi** paylaşabiliyor" | Satırlar **silinmez** (yayınlanmış sürüm notu); altına düzeltme notu eklenir | Yayınlanmış changelog yanlış bilgi içeriyor; şeffaf düzeltme daha güvenilir | YÜKSEK |

**Changelog'a eklenecek düzeltme notu (TR):**
> **Düzeltme — 4 Ağustos 2026.** Yukarıdaki iki madde yanlış yazılmış. Barkod okuma Open Food Facts verisini kullanıyor; Türkiye'ye özel bir veritabanı yok ve tarama süresi henüz ölçülmedi. Squad'larda altı kişilik üye sınırı ve ortak seri hesabı bulunmuyor; her üyenin kendi serisi görünüyor. Denetim sonrası düzeltildi.

---

## 11. UYGULAMA EKRAN METNİ DÜZELTMELERİ
> Kod değil, `assets/localization/tr.json` ve `en.json` içindeki dizeler. **Uygulamanın kendi metni siteden daha çok abartıyor** — ödeme alan bir ekranda yanlış vaat olduğu için mağaza incelemesi ve tüketici hukuku riski.

| Anahtar | Şu anki metin | Olması gereken | Gerekçe | Öncelik |
|---|---|---|---|---|
| `premium.perk_meal_plans` | "Sınırsız Plan" | "Günde 20 yapay zekâ üretimi" | Gerçek limit 20/gün (`functions/index.js:31-32`) | **ACİL** |
| `premium.description` | "Reklamsız deneyim" | "Yapay zekâ üretim hakkın artar" | Uygulamada reklam SDK'sı **hiç yok** — ücretsizde de reklam yok | **ACİL** |
| `ai.paywall_feature2` | "Öncelikli AI işleme" | Kaldırılır | Rate limit her iki kademede 12 istek/dk | **ACİL** |
| `ai.paywall_feature3` | "Gelişmiş öğün özelleştirme" | Kaldırılır | Böyle bir özellik yok | **ACİL** |
| `ai.paywall_feature4` | "Detaylı beslenme analitiği" | Kaldırılır | `nutritionAnalytics => true`, ücretsiz | **ACİL** |
| `gym.feature_challenges` | "YAKINDA GELECEK" | Etiket kaldırılır | Salon savaşları çalışıyor (`gym_leaderboard_service.dart:98-104`) | YÜKSEK |
| `gym.setup_coming_soon` | "yakında" | Etiket kaldırılır | Salon kurulumu, QR giriş ve analitik çalışıyor | YÜKSEK |
| `squad.empty_msg` | "seriyi birlikte sürdürün" (ortak seri ima ediyor) | "Serilerinizi yan yana görün" | Ortak seri hesabı yok | YÜKSEK |
| `gym.stats_tier` | "Seviye" (abonelik kademesi göstergesi) | Kaldırılır | `GymModel.subscriptionTier` alanı var ama ticaret yok — ödemeli kademe varmış izlenimi veriyor | ORTA |
| `permission.location.rationale` | Yalnızca GPS check-in'den bahsediyor | Salon ve koç keşfi de eklenir | Konum bu üç yerde kullanılıyor; izin gerekçesi eksik | YÜKSEK |
| 6 çevrilmemiş TR dizesi | `profile.last_seen`, `profile.friends_modal.search_hint`, `.no_friends`, `profile.friend_actions.received_text`, `explore.suggestion.smoothie`, `program.paid_locked_title` — TR'de İngilizce | Türkçeye çevrilir | 2725=2725 anahtar paritesi var ama değer paritesi yok; CI testi yalnızca anahtar karşılaştırıyor | ORTA |
| `nutrition_analytics_screen.dart:515`, `gym_analytics_screen.dart:548`, `gym_leaderboard_screen.dart:220` | Sabit İngilizce gün etiketleri `['Mo','Tu',...]` | Localization'a taşınır | Türkçe arayüzde İngilizce görünüyor | ORTA |
| `assets/legal/kvkk_aydinlatma_tr.md:11-12` | "Burak Dereli tarafından işletilen Cookrange" (eksiklik belirtilmiyor) | Sitenin `CompanyIncompleteNotice` bandının karşılığı eklenir | Site eksikliği kabul ediyor, uygulama eksiksizmiş gibi sunuyor | **ACİL** |

---

## 12. ÖNCELİK ÖZETİ

| Öncelik | Satır sayısı | Kapsam |
|---|---|---|
| **ACİL** | 54 | Yanıltıcı beyan ve KVKK riski. 1 sayfa geri çekilir, 3 SSS + 1 KVKK maddesi çıkarılır, 5 uygulama içi Premium dizesi düzeltilir |
| **YÜKSEK** | 25 | Güvenilirlik, hukuki eksik, kaybedilen değer, yapılandırılmış veri |
| **ORTA** | 17 | Somutlaştırma, terminoloji, teknik tutarlılık |
| **DÜŞÜK** | 7 | Marka sesi, hitap, biçim |

*Bu sayılar bu dosyadaki satır bazlı düzeltmeleri sayar; `01-OZELLIK-ENVANTERI.xlsx` ise özellik bazlı satırları sayar (ACİL 25). Aynı özellik birden çok sayfada düzeltme gerektirdiği için bu dosyanın sayısı daha yüksek.*

**Tek en hızlı risk azaltması:** `hero-data.ts` içinde 8 satır — 12.400 sütun (`:699` EN, `:782` TR, `:853` çip) · pazar günü (`:731`) · altı sütun tek seri (`:685` EN, `:768` TR) · 28/34/7 çipi · projeksiyon kiloları (`:851`) · `partners` sahnesi (`:705-706`, `:854`) — ve `ozellikler/sponsorlu-urunler.astro` sayfasının geri çekilmesi. Bu iki iş, çekirdek 17 TİP A çakışmasının 9'unu ve en ağır ölçek iddiasını tek oturumda kapatıyor.
