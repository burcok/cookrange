/// Static Turkish location dataset — 81 provinces with their districts.
///
/// Used for city/district filter dropdowns in gym and coach discovery screens.
/// Keys are canonical Turkish province names; values are alphabetically sorted
/// district lists. All names use correct Turkish characters.
class TurkishLocations {
  TurkishLocations._();

  /// Returns an alphabetically sorted list of all province names.
  static List<String> get provinces =>
      _data.keys.toList()..sort((a, b) => a.compareTo(b));

  /// Returns districts for [province], or an empty list if not found.
  static List<String> districtsOf(String province) =>
      _data[province] ?? const [];

  static const Map<String, List<String>> _data = {
    'Adana': [
      'Aladağ', 'Ceyhan', 'Çukurova', 'Feke', 'İmamoğlu', 'Karaisalı',
      'Karataş', 'Kozan', 'Pozantı', 'Saimbeyli', 'Sarıçam', 'Seyhan',
      'Tufanbeyli', 'Yumurtalık', 'Yüreğir',
    ],
    'Adıyaman': [
      'Adıyaman Merkez', 'Besni', 'Çelikhan', 'Gerger', 'Gölbaşı',
      'Kahta', 'Samsat', 'Sincik', 'Tut',
    ],
    'Afyonkarahisar': [
      'Afyonkarahisar Merkez', 'Başmakçı', 'Bayat', 'Bolvadin', 'Çay',
      'Çobanlar', 'Dazkırı', 'Dinar', 'Emirdağ', 'Evciler', 'Hocalar',
      'İhsaniye', 'İscehisar', 'Kızılören', 'Sandıklı', 'Sinanpaşa',
      'Sultandağı', 'Şuhut',
    ],
    'Ağrı': [
      'Ağrı Merkez', 'Diyadin', 'Doğubayazıt', 'Eleşkirt', 'Hamur',
      'Patnos', 'Taşlıçay', 'Tutak',
    ],
    'Amasya': [
      'Amasya Merkez', 'Göynücek', 'Gümüşhacıköy', 'Hamamözü', 'Merzifon',
      'Suluova', 'Taşova',
    ],
    'Ankara': [
      'Altındağ', 'Akyurt', 'Ayaş', 'Bala', 'Beypazarı', 'Çamlıdere',
      'Çankaya', 'Çubuk', 'Elmadağ', 'Etimesgut', 'Evren', 'Gölbaşı',
      'Güdül', 'Haymana', 'Kalecik', 'Kazan', 'Keçiören', 'Kızılcahamam',
      'Mamak', 'Nallıhan', 'Polatlı', 'Pursaklar', 'Sincan', 'Şereflikoçhisar',
      'Yenimahalle',
    ],
    'Antalya': [
      'Aksu', 'Alanya', 'Demre', 'Döşemealtı', 'Elmalı', 'Finike',
      'Gazipaşa', 'Gündoğmuş', 'İbradı', 'Kaş', 'Kemer', 'Kepez',
      'Konyaaltı', 'Korkuteli', 'Kumluca', 'Manavgat', 'Muratpaşa',
      'Serik',
    ],
    'Artvin': [
      'Ardanuç', 'Arhavi', 'Artvin Merkez', 'Borçka', 'Hopa', 'Kemalpaşa',
      'Murgul', 'Şavşat', 'Yusufeli',
    ],
    'Aydın': [
      'Bozdoğan', 'Buharkent', 'Çine', 'Didim', 'Efeler', 'Germencik',
      'İncirliova', 'Karacasu', 'Karpuzlu', 'Koçarlı', 'Köşk', 'Kuşadası',
      'Kuyucak', 'Nazilli', 'Söke', 'Sultanhisar', 'Yenipazar',
    ],
    'Balıkesir': [
      'Altıeylül', 'Ayvalık', 'Balya', 'Bandırma', 'Bigadiç', 'Burhaniye',
      'Dursunbey', 'Edremit', 'Erdek', 'Gömeç', 'Gönen', 'Havran',
      'İvrindi', 'Karesi', 'Kepsut', 'Manyas', 'Marmara', 'Savaştepe',
      'Sındırgı', 'Susurluk',
    ],
    'Bartın': ['Amasra', 'Bartın Merkez', 'Kurucaşile', 'Ulus'],
    'Batman': ['Batman Merkez', 'Beşiri', 'Gercüş', 'Hasankeyf', 'Kozluk', 'Sason'],
    'Bayburt': ['Aydıntepe', 'Bayburt Merkez', 'Demirözü'],
    'Bilecik': [
      'Bozüyük', 'Gölpazarı', 'İnhisar', 'Merkez', 'Osmaneli', 'Pazaryeri',
      'Söğüt', 'Yenipazar',
    ],
    'Bingöl': [
      'Adaklı', 'Bingöl Merkez', 'Genç', 'Karlıova', 'Kiğı', 'Solhan',
      'Yayladere', 'Yedisu',
    ],
    'Bitlis': [
      'Adilcevaz', 'Ahlat', 'Bitlis Merkez', 'Güroymak', 'Hizan', 'Mutki',
      'Tatvan',
    ],
    'Bolu': [
      'Bolu Merkez', 'Dörtdivan', 'Gerede', 'Göynük', 'Kıbrıscık',
      'Mengen', 'Mudurnu', 'Seben', 'Yeniçağa',
    ],
    'Burdur': [
      'Ağlasun', 'Altınyayla', 'Bucak', 'Burdur Merkez', 'Çavdır', 'Çeltikçi',
      'Gölhisar', 'Karamanlı', 'Kemer', 'Tefenni', 'Yeşilova',
    ],
    'Bursa': [
      'Büyükorhan', 'Gemlik', 'Gürsu', 'Harmancık', 'İnegöl', 'İznik',
      'Karacabey', 'Keles', 'Kestel', 'Mudanya', 'Mustafakemalpaşa',
      'Nilüfer', 'Orhaneli', 'Orhangazi', 'Osmangazi', 'Yıldırım', 'Yenişehir',
    ],
    'Çanakkale': [
      'Ayvacık', 'Bayramiç', 'Biga', 'Bozcaada', 'Çan', 'Çanakkale Merkez',
      'Eceabat', 'Ezine', 'Gelibolu', 'Gökçeada', 'Lapseki', 'Yenice',
    ],
    'Çankırı': [
      'Atkaracalar', 'Bayramören', 'Çankırı Merkez', 'Eldivan', 'Ilgaz',
      'Kızılırmak', 'Korgun', 'Kurşunlu', 'Orta', 'Şabanözü', 'Yapraklı',
    ],
    'Çorum': [
      'Alaca', 'Bayat', 'Boğazkale', 'Çorum Merkez', 'Dodurga', 'İskilip',
      'Kargı', 'Laçin', 'Mecitözü', 'Oğuzlar', 'Ortaköy', 'Osmancık',
      'Sungurlu', 'Uğurludağ',
    ],
    'Denizli': [
      'Acıpayam', 'Babadağ', 'Baklan', 'Bekilli', 'Beyağaç', 'Bozkurt',
      'Buldan', 'Çal', 'Çameli', 'Çardak', 'Çivril', 'Güney', 'Honaz',
      'Kale', 'Merkezefendi', 'Pamukkale', 'Sarayköy', 'Serinhisar', 'Tavas',
    ],
    'Diyarbakır': [
      'Bağlar', 'Bismil', 'Çermik', 'Çınar', 'Çüngüş', 'Dicle', 'Eğil',
      'Ergani', 'Hani', 'Hazro', 'Kayapınar', 'Kocaköy', 'Kulp', 'Lice',
      'Silvan', 'Sur', 'Yenişehir',
    ],
    'Düzce': [
      'Akçakoca', 'Cumayeri', 'Çilimli', 'Düzce Merkez', 'Gölyaka', 'Gümüşova',
      'Kaynaşlı', 'Yığılca',
    ],
    'Edirne': [
      'Edirne Merkez', 'Enez', 'Havsa', 'İpsala', 'Keşan', 'Lalapaşa',
      'Meriç', 'Süloğlu', 'Uzunköprü',
    ],
    'Elazığ': [
      'Ağın', 'Alacakaya', 'Arıcak', 'Baskil', 'Elazığ Merkez', 'Karakoçan',
      'Keban', 'Kovancılar', 'Maden', 'Palu', 'Sivrice',
    ],
    'Erzincan': [
      'Çayırlı', 'Erzincan Merkez', 'İliç', 'Kemah', 'Kemaliye', 'Otlukbeli',
      'Refahiye', 'Tercan', 'Üzümlü',
    ],
    'Erzurum': [
      'Aşkale', 'Aziziye', 'Çat', 'Hınıs', 'Horasan', 'İspir', 'Karaçoban',
      'Karayazı', 'Köprüköy', 'Narman', 'Oltu', 'Olur', 'Palandöken',
      'Pasinler', 'Pazaryolu', 'Şenkaya', 'Tekman', 'Tortum', 'Uzundere',
      'Yakutiye',
    ],
    'Eskişehir': [
      'Alpu', 'Beylikova', 'Çifteler', 'Günyüzü', 'Han', 'İnönü', 'Mahmudiye',
      'Mihalgazi', 'Mihalıççık', 'Odunpazarı', 'Sarıcakaya', 'Seyitgazi',
      'Sivrihisar', 'Tepebaşı',
    ],
    'Gaziantep': [
      'Araban', 'İslahiye', 'Karkamış', 'Nizip', 'Nurdağı', 'Oğuzeli',
      'Şahinbey', 'Şehitkamil', 'Yavuzeli',
    ],
    'Giresun': [
      'Alucra', 'Bulancak', 'Çamoluk', 'Çanakçı', 'Dereli', 'Doğankent',
      'Espiye', 'Eynesil', 'Giresun Merkez', 'Görele', 'Güce', 'Keşap',
      'Piraziz', 'Şebinkarahisar', 'Tirebolu', 'Yağlıdere',
    ],
    'Gümüşhane': [
      'Gümüşhane Merkez', 'Kelkit', 'Köse', 'Kürtün', 'Şiran', 'Torul',
    ],
    'Hakkari': ['Çukurca', 'Derecik', 'Hakkari Merkez', 'Şemdinli', 'Yüksekova'],
    'Hatay': [
      'Altınözü', 'Antakya', 'Arsuz', 'Belen', 'Defne', 'Dörtyol', 'Erzin',
      'Hassa', 'İskenderun', 'Kırıkhan', 'Kumlu', 'Payas', 'Reyhanlı',
      'Samandağ', 'Serinyol', 'Yayladağı',
    ],
    'Iğdır': ['Aralık', 'Iğdır Merkez', 'Karakoyunlu', 'Tuzluca'],
    'Isparta': [
      'Aksu', 'Atabey', 'Eğirdir', 'Gelendost', 'Gönen', 'Keçiborlu',
      'Senirkent', 'Sütçüler', 'Şarkikaraağaç', 'Uluborlu', 'Yalvaç', 'Yenişarbademli',
    ],
    'İstanbul': [
      'Adalar', 'Arnavutköy', 'Ataşehir', 'Avcılar', 'Bağcılar',
      'Bahçelievler', 'Bakırköy', 'Başakşehir', 'Bayrampaşa', 'Beşiktaş',
      'Beykoz', 'Beylikdüzü', 'Beyoğlu', 'Büyükçekmece', 'Çatalca',
      'Çekmeköy', 'Esenler', 'Esenyurt', 'Eyüpsultan', 'Fatih',
      'Gaziosmanpaşa', 'Güngören', 'Kadıköy', 'Kağıthane', 'Kartal',
      'Küçükçekmece', 'Maltepe', 'Pendik', 'Sancaktepe', 'Sarıyer',
      'Silivri', 'Sultanbeyli', 'Sultangazi', 'Şile', 'Şişli', 'Tuzla',
      'Ümraniye', 'Üsküdar', 'Zeytinburnu',
    ],
    'İzmir': [
      'Aliağa', 'Balçova', 'Bayındır', 'Bayraklı', 'Bergama', 'Beydağ',
      'Bornova', 'Buca', 'Çeşme', 'Çiğli', 'Dikili', 'Foça', 'Gaziemir',
      'Güzelbahçe', 'Karabağlar', 'Karaburun', 'Karşıyaka', 'Kemalpaşa',
      'Kınık', 'Kiraz', 'Konak', 'Menderes', 'Menemen', 'Narlıdere',
      'Ödemiş', 'Seferihisar', 'Selçuk', 'Tire', 'Torbalı', 'Urla',
    ],
    'Kahramanmaraş': [
      'Afşin', 'Andırın', 'Çağlayancerit', 'Dulkadiroğlu', 'Ekinözü',
      'Elbistan', 'Göksun', 'Nurhak', 'Onikişubat', 'Pazarcık', 'Türkoğlu',
    ],
    'Karabük': [
      'Eflani', 'Eskipazar', 'Karabük Merkez', 'Ovacık', 'Safranbolu', 'Yenice',
    ],
    'Karaman': [
      'Ayrancı', 'Başyayla', 'Ermenek', 'Karaman Merkez', 'Kazımkarabekir', 'Sarıveliler',
    ],
    'Kars': [
      'Akyaka', 'Arpaçay', 'Digor', 'Kağızman', 'Kars Merkez', 'Sarıkamış',
      'Selim', 'Susuz',
    ],
    'Kastamonu': [
      'Abana', 'Ağlı', 'Araç', 'Azdavay', 'Bozkurt', 'Cide', 'Çatalzeytin',
      'Daday', 'Devrekani', 'Doğanyurt', 'Hanönü', 'İhsangazi', 'İnebolu',
      'Kastamonu Merkez', 'Küre', 'Pınarbaşı', 'Seydiler', 'Şenpazar',
      'Taşköprü', 'Tosya',
    ],
    'Kayseri': [
      'Akkışla', 'Bünyan', 'Develi', 'Felahiye', 'Hacılar', 'İncesu',
      'Kocasinan', 'Melikgazi', 'Özvatan', 'Pınarbaşı', 'Sarıoğlan',
      'Sarız', 'Talas', 'Tomarza', 'Yahyalı', 'Yeşilhisar',
    ],
    'Kilis': ['Elbeyli', 'Kilis Merkez', 'Musabeyli', 'Polateli'],
    'Kırıkkale': [
      'Bahşili', 'Balışeyh', 'Çelebi', 'Delice', 'Karakeçili', 'Keskin',
      'Kırıkkale Merkez', 'Sulakyurt', 'Yahşihan',
    ],
    'Kırklareli': [
      'Babaeski', 'Demirköy', 'Kırklareli Merkez', 'Kofçaz', 'Lüleburgaz',
      'Pehlivanköy', 'Pınarhisar', 'Vize',
    ],
    'Kırşehir': [
      'Akçakent', 'Akpınar', 'Boztepe', 'Çiçekdağı', 'Kaman', 'Kırşehir Merkez',
      'Mucur',
    ],
    'Kocaeli': [
      'Başiskele', 'Çayırova', 'Darıca', 'Derince', 'Dilovası', 'Gebze',
      'Gölcük', 'İzmit', 'Kandıra', 'Karamürsel', 'Kartepe', 'Körfez',
    ],
    'Konya': [
      'Ahırlı', 'Akören', 'Akşehir', 'Altınekin', 'Beyşehir', 'Bozkır',
      'Cihanbeyli', 'Çeltik', 'Çumra', 'Derbent', 'Derebucak', 'Doğanhisar',
      'Emirgazi', 'Ereğli', 'Güneysınır', 'Hadim', 'Halkapınar', 'Hüyük',
      'Ilgın', 'Kadınhanı', 'Karapınar', 'Karatay', 'Kulu', 'Meram',
      'Sarayönü', 'Selçuklu', 'Seydişehir', 'Taşkent', 'Tuzlukçu', 'Yalıhüyük',
      'Yunak',
    ],
    'Kütahya': [
      'Altıntaş', 'Aslanapa', 'Çavdarhisar', 'Domaniç', 'Dumlupınar',
      'Emet', 'Gediz', 'Hisarcık', 'Kütahya Merkez', 'Pazarlar', 'Şaphane',
      'Simav', 'Tavşanlı',
    ],
    'Malatya': [
      'Akçadağ', 'Arapgir', 'Arguvan', 'Battalgazi', 'Darende', 'Doğanşehir',
      'Doğanyol', 'Hekimhan', 'Kale', 'Kuluncak', 'Pütürge', 'Yazıhan',
      'Yeşilyurt',
    ],
    'Manisa': [
      'Ahmetli', 'Akhisar', 'Alaşehir', 'Demirci', 'Gölmarmara', 'Gördes',
      'Kırkağaç', 'Köprübaşı', 'Kula', 'Salihli', 'Sarıgöl', 'Saruhanlı',
      'Selendi', 'Soma', 'Şehzadeler', 'Turgutlu', 'Yunusemre',
    ],
    'Mardin': [
      'Artuklu', 'Dargeçit', 'Derik', 'Kızıltepe', 'Mazıdağı', 'Midyat',
      'Nusaybin', 'Ömerli', 'Savur', 'Yeşilli',
    ],
    'Mersin': [
      'Akdeniz', 'Anamur', 'Aydıncık', 'Bozyazı', 'Çamlıyayla', 'Erdemli',
      'Gülnar', 'Mezitli', 'Mut', 'Silifke', 'Tarsus', 'Toroslar', 'Yenişehir',
    ],
    'Muğla': [
      'Bodrum', 'Dalaman', 'Datça', 'Fethiye', 'Kavaklıdere', 'Köyceğiz',
      'Marmaris', 'Menteşe', 'Milas', 'Ortaca', 'Seydikemer', 'Ula', 'Yatağan',
    ],
    'Muş': ['Bulanık', 'Hasköy', 'Korkut', 'Malazgirt', 'Muş Merkez', 'Varto'],
    'Nevşehir': [
      'Acıgöl', 'Avanos', 'Derinkuyu', 'Gülşehir', 'Hacıbektaş', 'Kozaklı',
      'Nevşehir Merkez', 'Ürgüp',
    ],
    'Niğde': [
      'Altunhisar', 'Bor', 'Çamardı', 'Çiftlik', 'Niğde Merkez', 'Ulukışla',
    ],
    'Ordu': [
      'Akkuş', 'Altınordu', 'Aybastı', 'Çamaş', 'Çatalpınar', 'Çaybaşı',
      'Fatsa', 'Gölköy', 'Gülyalı', 'Gürgentepe', 'İkizce', 'Kabadüz',
      'Kabataş', 'Korgan', 'Kumru', 'Mesudiye', 'Perşembe', 'Ulubey',
      'Ünye',
    ],
    'Osmaniye': [
      'Bahçe', 'Düziçi', 'Hasanbeyli', 'Kadirli', 'Osmaniye Merkez',
      'Sumbas', 'Toprakkale',
    ],
    'Rize': [
      'Ardeşen', 'Çamlıhemşin', 'Çayeli', 'Derepazarı', 'Fındıklı',
      'Güneysu', 'Hemşin', 'İkizdere', 'İyidere', 'Kalkandere', 'Pazar',
      'Rize Merkez',
    ],
    'Sakarya': [
      'Adapazarı', 'Akyazı', 'Arifiye', 'Erenler', 'Ferizli', 'Geyve',
      'Hendek', 'Karapürçek', 'Karasu', 'Kaynarca', 'Kocaali', 'Mithatpaşa',
      'Pamukova', 'Sapanca', 'Serdivan', 'Söğütlü', 'Taraklı',
    ],
    'Samsun': [
      'Alaçam', 'Asarcık', 'Atakum', 'Ayvacık', 'Bafra', 'Canik', 'Çarşamba',
      'Havza', 'İlkadım', 'Kavak', 'Ladik', 'Ondokuzmayıs', 'Salıpazarı',
      'Tekkeköy', 'Terme', 'Vezirköprü', 'Yakakent',
    ],
    'Siirt': ['Baykan', 'Eruh', 'Kurtalan', 'Pervari', 'Siirt Merkez', 'Şirvan', 'Tillo'],
    'Sinop': [
      'Ayancık', 'Boyabat', 'Dikmen', 'Durağan', 'Erfelek', 'Gerze',
      'Saraydüzü', 'Sinop Merkez', 'Türkeli',
    ],
    'Sivas': [
      'Akıncılar', 'Altınyayla', 'Divriği', 'Doğanşar', 'Gemerek', 'Gölova',
      'Hafik', 'İmranlı', 'Kangal', 'Koyulhisar', 'Sivas Merkez', 'Suşehri',
      'Şarkışla', 'Ulaş', 'Yıldızeli', 'Zara',
    ],
    'Şanlıurfa': [
      'Akçakale', 'Birecik', 'Bozova', 'Ceylanpınar', 'Eyyübiye', 'Halfeti',
      'Haliliye', 'Harran', 'Hilvan', 'Karaköprü', 'Siverek', 'Suruç',
      'Viranşehir',
    ],
    'Şırnak': [
      'Beytüşşebap', 'Cizre', 'Güçlükonak', 'İdil', 'Silopi', 'Şırnak Merkez',
      'Uludere',
    ],
    'Tekirdağ': [
      'Çerkezköy', 'Çorlu', 'Ergene', 'Hayrabolu', 'Kapaklı', 'Malkara',
      'Marmaraereğlisi', 'Muratlı', 'Saray', 'Süleymanpaşa', 'Şarköy',
    ],
    'Tokat': [
      'Almus', 'Artova', 'Başçiftlik', 'Erbaa', 'Niksar', 'Pazar',
      'Reşadiye', 'Sulusaray', 'Tokat Merkez', 'Turhal', 'Yeşilyurt', 'Zile',
    ],
    'Trabzon': [
      'Akçaabat', 'Araklı', 'Arsin', 'Beşikdüzü', 'Çarşıbaşı', 'Çaykara',
      'Dernekpazarı', 'Düzköy', 'Hayrat', 'Köprübaşı', 'Maçka', 'Merkez',
      'Of', 'Ortahisar', 'Sürmene', 'Şalpazarı', 'Tonya', 'Vakfıkebir',
      'Yomra',
    ],
    'Tunceli': [
      'Çemişgezek', 'Hozat', 'Mazgirt', 'Nazımiye', 'Ovacık', 'Pertek',
      'Pülümür', 'Tunceli Merkez',
    ],
    'Uşak': [
      'Banaz', 'Eşme', 'Karahallı', 'Sivaslı', 'Ulubey', 'Uşak Merkez',
    ],
    'Van': [
      'Bahçesaray', 'Başkale', 'Çaldıran', 'Çatak', 'Edremit', 'Erciş',
      'Gevaş', 'Gürpınar', 'İpekyolu', 'Muradiye', 'Özalp', 'Saray',
      'Tuşba',
    ],
    'Yalova': ['Altınova', 'Armutlu', 'Çiftlikköy', 'Çınarcık', 'Termal', 'Yalova Merkez'],
    'Yozgat': [
      'Akdağmadeni', 'Aydıncık', 'Boğazlıyan', 'Çandır', 'Çayıralan',
      'Çekerek', 'Kadışehri', 'Saraykent', 'Sarıkaya', 'Şefaatli', 'Sorgun',
      'Yenifakılı', 'Yerköy', 'Yozgat Merkez',
    ],
    'Zonguldak': [
      'Alaplı', 'Çaycuma', 'Devrek', 'Ereğli', 'Gökçebey', 'Kilimli',
      'Kozlu', 'Zonguldak Merkez',
    ],
    'Ardahan': ['Çıldır', 'Damal', 'Göle', 'Hanak', 'Posof', 'Ardahan Merkez'],
  };
}
