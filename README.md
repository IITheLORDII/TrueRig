# TrueRig — PC, Telefon ve Akıllı Saat Performans Uygulaması

Google Play, App Store ve **web sitesi** için tek Flutter kod tabanı.
**PC, telefon ve akıllı saat** ayrı ayrı seçilip analiz edilir.

- **Uyumluluk:** soket, BIOS, RAM tipi/slot/hız, kasa–anakart, GPU boyu, soğutucu (soket/TDP/yükseklik), PSU watt ve 12V-2x6 konnektörü, iGPU kontrolü
- **Darboğaz:** CPU'nun besleyebildiği ve GPU'nun çizebildiği FPS'ten darboğaz yüzdesi; çözünürlük/ayar seçimi
- **Performans:** 13 oyun (CS2, Valorant, RDR2, Cyberpunk, GTA V, GTA VI projeksiyonu…), 10 profesyonel uygulama (SolidWorks, AutoCAD, Blender…), 16 yerel LLM (Qwen3, Llama, DeepSeek, Gemma, gpt-oss… Ollama/LM Studio token/sn)
- **Darboğazı azalt:** uyumlu yükseltmeleri "100 $ başına FPS" ile sıralar + ücretsiz ipuçları
- **Fiyat / Nerede bulunur:** model, MPN (seri/parça no) veya barkodla arama; herkese açık sayfalardan satıcı bazlı fiyatlar + mağaza arama bağlantıları
- **Telefon:** ~105 iOS/Android model, 50+ SoC; darboğaz puanı, mobil oyun FPS'i (ilk/ısınınca, önerilen ayar), uygulama ve telefonda yapay zekâ; uygulama telefonun kendi modelini tanır
- **Akıllı saat:** ~35 model; telefonla uyumluluk (platform, OS sürümü, Samsung'a özel özellikler), akıcılık, pil, özellikler
- **Donanım algılama (web):** site açılınca izin istenir, tarayıcıdan ekran kartı + iş parçacığı + ekran okunur; Windows aracıyla işlemci, RAM ve anakart dahil tam algılama
- **Ürün görselleri:** seri numarası (MPN/GTIN) birebir eşleşen ürünün görseli; Kur, parça seçici ve fiyat ekranında

## Yapı

```
app/                      Flutter uygulaması (Riverpod 3, go_router)
packages/perf_engine/     Saf Dart hesap motoru + seed katalog (offline)
supabase/                 Postgres şeması (RLS) + price-search Edge Function
```

## Çalıştırma

> ⚠️ Proje yolunda `'` karakteri (ör. `KULLANICI'S PC`) Dart test derleyicisini ve
> Android Gradle'ı bozuyor. Komutları **`C:\src\darbogaz`** junction'ı
> üzerinden çalıştır (aynı klasörü gösterir) ya da projeyi apostrofsuz bir
> yola taşı.

```bash
cd C:/src/darbogaz/packages/perf_engine && dart test
cd C:/src/darbogaz/app && flutter test
cd C:/src/darbogaz/app && flutter run
```

Canlı fiyat ve görseller için (opsiyonel):

```bash
flutter run --dart-define=PRICE_API_URL=https://<proje>.supabase.co/functions/v1/price-search --dart-define=SUPABASE_URL=https://<proje>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
```

## Web sürümü ve donanım algılama

```bash
cd C:/src/darbogaz/app && flutter build web --release --pwa-strategy=none
```

`build/web` statik olarak herhangi bir yerde yayınlanabilir; site `#/detect`
ekranıyla açılır.

**Tarayıcının verdiği bilgiler (izin istenip okunur):** ekran kartı adı
(WebGL), mantıksal iş parçacığı sayısı, ekran çözünürlüğü. Tarayıcılar
işlemci modelini, RAM'i ve anakartı hiçbir izinle vermez. Bu yüzden işlemci,
thread sayısına uyan adaylardan seçtirilir. Dizüstülerde tarayıcı çoğunlukla
tümleşik GPU'yu raporlar; ekran bunu algılayıp uyarır.

**Tam algılama:** `web/detect.ps1` (sitede `/detect.ps1`) yalnızca WMI'dan
okur (Win32_Processor, Win32_VideoController, Win32_PhysicalMemory,
Win32_BaseBoard). Sonucu base64url koda çevirir ve siteyi
`#/detect?hw=<kod>` ile açar. `#` sonrası tarayıcıdan sunucuya gitmez.
`-Json` parametresiyle sadece JSON yazdırır, `-NoOpen` ile tarayıcıyı açmaz,
`-Site` ile adres değiştirilir.

## Backend (Supabase)

```bash
supabase db push
supabase functions deploy price-search
supabase secrets set BOT_INFO_URL=https://<site>/bot   # botu tanıtan sayfa
```

### Fiyat ve görsel toplama (ortaklık yok, herkese açık sayfalar)

`price-search` herkese açık mağaza sayfalarındaki **schema.org JSON-LD**
ürün verisini okur (fiyat, satıcı, stok, görsel). Kurallar:

- Her sitenin `robots.txt`'sine uyulur; robots.txt 401/403 dönen site botlara kapalı sayılır.
- Kendini `TrueRigBot/1.0 (+BOT_INFO_URL)` olarak tanıtır; tarayıcı taklidi, CAPTCHA/bot koruması aşma yoktur.
- Aynı siteye istekler arasında en az 2 sn (veya Crawl-delay), site başına saatte en fazla 60 istek; 403/429/503'te 6 saat geri çekilir.
- Sonuçlar 6 saat, görseller 30 gün önbelleğe alınır. Görsel dosyaları kopyalanmaz; yalnızca adresi saklanır.
- Görsel sadece MPN/SKU/GTIN birebir eşleşince bağlanır (ad benzerliğiyle değil).

8 Ekim 2026 kontrolü: Akakçe izin veriyor ve ürün sayfalarında satıcı bazlı
JSON-LD var. İtopya izin veriyor ama içerik JavaScript ile yükleniyor (veri
çıkmıyor). İncehesap arama sayfası bota 403 dönüyor. Cimri, Epey, Trendyol,
Vatan ve MediaMarkt robots.txt ile yasaklıyor; Hepsiburada, n11 ve Teknosa
robots.txt'yi bota hiç vermiyor (403). Yasak siteler için uygulama sadece
arama bağlantısı gösterir.

Katalog görsellerini önceden doldurmak için:

```bash
cd packages/perf_engine && dart run tool/export_mpns.dart > ../../mpns.txt
PRICE_API_URL=... SUPABASE_ANON_KEY=... node supabase/scripts/warm_images.mts mpns.txt
```

Testler: `node --test "supabase/functions/price-search/test/*.test.ts"`

## Tahmin modeli

Referans platform: Ryzen 7 7800X3D + RTX 4090, Ultra. Her oyun için
`cpuRefFps` ve çözünürlük başına `gpuRefFps` kalibre edilir; sistemin FPS'i
CPU ve GPU limitlerinin yumuşak minimumudur. Darboğaz % = `1 − min/max`.
LLM hızı = bellek bant genişliği / token başına okunan bayt (MoE'de aktif
parametre). Değerler tahmindir; arayüzde aralık ve güven düzeyiyle gösterilir.

## Yol haritası

- [x] Faz 0–3: iskelet, motor (TDD), Kur/Analiz/Performans ekranları, yükseltme önerileri
- [x] Faz 4 (kısmi): fiyat arama, barkod tarama, herkese açık sayfalardan fiyat + MPN eşleşmeli görsel
- [x] Web sürümü + tarayıcı / Windows aracı ile donanım algılama
- [x] v2: PC / Telefon / Saat, kompakt 4 sekmeli arayüz, genişletilmiş katalog (100+ CPU, 90+ GPU, genel anakart/RAM/PSU sınıfları)
- [ ] Katalog verisini Supabase'den senkronlama, fiyat geçmişi + fiyat alarmı
- [ ] Faz 5: Google/Apple ile giriş, build kaydet/paylaş, Pro (RevenueCat), AdMob
- [ ] Faz 6: ikon/splash, gizlilik politikası (KVKK), mağaza formları, TestFlight / Play iç test
