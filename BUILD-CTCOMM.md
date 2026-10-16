# CTCOMM derleme ve kurulum

`ScreenCaptureRecorder.sln` içindeki `CTCOMM.Setup` projesini açın. Yapılandırma
seçiminden **Sürüm | x64** seçip Build çalıştırın. Tek çözüm hedefi hem Win32 hem
x64 görüntü/ses filtrelerini ve setup'ı üretir. **Release** imzasızdır.

Komut satırı karşılığı:

```powershell
powershell -NoProfile -File .\tools\Build-Release.ps1 -Configuration Sürüm
```

Çıktı: `artifacts\Sürüm\setup\CTCOMM-ScreenCaptureRecorder-0.13.3-Setup.exe`.
Görüntü ve ses DLL'leri aynı yapılandırmanın `Win32` ve `x64` klasörlerindedir.
İmzalama hatası derlemeyi durdurur; imzasız setup'a sessiz geçiş yapılmaz.

## Yeni PC / format sonrası

1. Depoyu alt modülleriyle alın: `git clone --recurse-submodules https://github.com/ugurmutlucan15/screen-capture-recorder.git`.
2. Visual Studio/Build Tools için C++ masaüstü geliştirme araçlarını (v145) ve
   Windows SDK'yı kurun. Visual Studio'ya yüklemek için `.vsconfig` kullanılabilir.
   Script, C++ araçları bulunan Visual Studio/Build Tools kurulumunu `vswhere` ile bulur.
3. Inno Setup 6.7.3 kurun. `ISCC.exe` standart kurulum konumunda değilse
   `-InnoPath 'C:\...\ISCC.exe'` verin. Geliştirme aracı için Inno Setup'ın ticari
   kullanım lisans koşullarını ayrıca karşılayın; bu depo lisans satın almaz.
4. `powershell -NoProfile -File .\tools\signing\Setup-Signing.ps1 -Install` çalıştırın.
   DigiCert ONE Clients uygulamasında kendi yetkili hesabınızla giriş/MFA yapın,
   SMCTL bileşenini kurun ve komutu tekrar çalıştırın. Sonra Visual Studio'yu açın.
5. Sürüm derlemesini çalıştırın. Aynı CTCOMM bulut HSM anahtarı kullanılır; yeni
   code-signing anahtarı veya sertifika üretilmez. Her geliştirici kendi yetkili
   oturumunu kullanır. PFX, API anahtarı, parola ve oturum dosyaları Git'e konmaz.

## Paket kapsamı ve çalışma

Setup iki mimaride `screen-capture-recorder` ve `virtual-audio-capturer`
DirectShow filtrelerini kurar. Inno `regserver` ile doğru 32/64 bit COM kaydını
yapar; kaldırma sırasında aynı kayıtları geri alır. Kurulum yönetici yetkisi ister.
Filtre CLSID'leri mevcut istemcilerle uyum için korunmuştur; bu nedenle mevcut
upstream filtre kaydı üzerine yazabilir. Önce ayrı bir test PC'sinde deneyin.

Bu paket eski Ruby/Java kayıt arayüzünü, FFmpeg'i veya benchmark uygulamasını
dağıtmaz; SimpleTouch/FFmpeg gibi DirectShow kullanan uygulamalar için filtre
paketidir. `/MT` ile üretilir; eski MSVC 2010 redistributable kurulmaz. Microsoft
ve upstream lisans/atıf metinleri korunur. Dijital imza dağıtım lisansı yerine geçmez.

## Doğrulama

```powershell
Invoke-Pester -Path .\tests
powershell -NoProfile -File .\tools\signing\Setup-Signing.ps1 -CheckOnly
Get-AuthenticodeSignature '.\artifacts\Sürüm\setup\CTCOMM-ScreenCaptureRecorder-0.13.3-Setup.exe'
```

`tools\Test-FilterRuntime.ps1 -Directory <tam DLL klasörü>` gerçek DirectShow
`IBaseFilter` nesnesi oluşturur; sisteme kayıt eklemez. Win32 için
`C:\Windows\SysWOW64\WindowsPowerShell\v1.0\powershell.exe`, x64 için
`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe` kullanın.

2026-10-16: Release setup imzasız; Sürüm dört DLL, setup ve kaldırıcı gerçek
KeyLocker imzasıyla üretildi. Dört DLL ve setup için CTCOMM + zaman damgası
doğrulandı; kaldırıcı Inno imzalama adımında SignTool ile doğrulandı.
İki mimaride dört gerçek filtre nesnesi testi geçti. Temiz PC kurulum/kaldırma
ve gerçek video/ses kayıt testi henüz yapılmadı. Mevcut upstream C++ uyarıları
korundu; uygulama algoritmasına müdahale edilmedi.
