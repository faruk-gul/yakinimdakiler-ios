# Yakinimdakiler iOS

Konuma dayali yakin yer bulma ve rota olusturma uygulamasi.

`Yakinimdakiler iOS`, kullanicinin mevcut konumunu alir, 5 km icindeki onemli noktalari listeler, harita uzerinde gosterir ve secilen yere Apple Maps ile yol tarifi baslatir.

## Ozellikler

- 5 km icindeki yakin yerleri listeleme
- Kategori bazli filtreleme
- Harita uzerinde secilen noktalari gosterme
- Secilen yere rota cizme
- Mesafe ve tahmini ulasim suresi gosterme
- Apple Maps ile navigasyon baslatma

## Desteklenen Kategoriler

- Hastane
- Benzin istasyonu
- Market
- Eczane
- Taksi duragi
- Polis merkezi

## Kullanilan Teknolojiler

- Swift
- SwiftUI
- MapKit
- CoreLocation
- Xcode

## Proje Yapisi

```text
yakinimdakiler-ios/
├── NearbyHospitalsApp.xcodeproj
└── NearbyHospitalsApp/
    ├── NearbyHospitalsApp.swift
    ├── ContentView.swift
    ├── HospitalFinderViewModel.swift
    ├── LocationManager.swift
    └── Assets.xcassets/
```

## Kurulum

1. Repoyu klonla:

```bash
git clone https://github.com/faruk-gul/yakinimdakiler-ios.git
```

2. Proje klasorune gir:

```bash
cd yakinimdakiler-ios
```

3. Xcode ile projeyi ac:

```bash
open NearbyHospitalsApp.xcodeproj
```

4. Xcode icinde:

- `Signing & Capabilities` altindan kendi `Team` secimini yap
- Gerekirse `Bundle Identifier` degerini benzersiz hale getir
- Gercek cihaz ya da simulator sec
- `Cmd + R` ile uygulamayi calistir

## Kullanim

1. Uygulamayi ac
2. Konum izni ver
3. Ustteki kategori butonlarindan birini sec
4. Liste veya harita uzerinden istedigin yeri sec
5. Navigasyon butonuyla Apple Maps uzerinden yol tarifini baslat

## Notlar

- En dogru sonuc icin gercek cihazda test edilmesi onerilir
- Simulator kullaniliyorsa konum manuel olarak secilmelidir
- Sonuclar `MapKit` arama sonuclarina gore degisebilir

## Gelistirme Fikirleri

- Yeni kategori turleri ekleme
- Kullanici favorileri
- Son aramalar
- Karanlik mod icin ozel tasarim iyilestirmeleri
- Coklu dil destegi

## Lisans

Bu proje ogrenme ve gelistirme amacli hazirlanmistir.
