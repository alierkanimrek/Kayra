#!/bin/bash

# User menu labels (icons and commands are defined in user-menu.sh)
declare -A user_menu=(
  [ADD_TO_GROUP]="Gruba ekle"
  [REMOVE_FROM_GROUP]="Gruptan çıkar"
  [CHANGE_PASSWORD]="Şifreyi değiştir"
  [HOME_USAGE]="Ev Dizini Kullanımı"
)

# System menu labels (icons and commands are defined in system-menu.sh)
declare -A system_menu=(
  [APPEARANCE_THEME]="Görünüm ve Tema"
  [LANGUAGE]="Dil"
  [KEYBOARD]="Klavye"
  [DISPLAY]="Ekran"
  [DATETIME]="Tarih ve Saat"
  [PRINTING]="Yazıcıları Yönet"
  [POWER_MODE]="Güç Modu"
  [DEVICES]="Aygıtlar"
  [SERVICES]="Servisler"
  [SETTINGS]="Ayarlar"
  [STARTUP]="Açılış Komutları"
  [UPDATES]="Güncellemeleri Kontrol Et"
)

# Appearance menu labels (icons and commands are defined in appearance-settings.sh)
declare -A appearance_menu=(
  [FONT]="Yazı Tipi"
  [FONT_SIZE]="Yazı Tipi Büyüklüğü"
  [CHANGE_THEME]="Temayı değiştir"
  [WALLPAPER]="Duvar Kağıdı"
)

declare -A i18n_HOME_USAGE=(
  [NOTIFY_TITLE]="Ev dizini boyutu"
  [NOTIFY_MSG]="{HOME} Dizini {USAGE} yer kaplıyor."
  [NOTIFY_BUTTON]="Baobab'ı Aç"
)

declare -A i18n_CHANGE_PASSWD=(
  [WINDOW_TITLE]="Şifre değiştir"
  [NOTIFY_TITLE]="Şifre değiştirme"
  [MSG_NOT_INSTALLED]="{BIN} kurulu değil (xbps-install -S {BIN})"
  [MSG_TERMINAL_FAILED]="Terminal açılamadı. Şifre değiştirme başlatılmadı."
  [MSG_CANCELLED]="İşlem iptal edildi"
  [MSG_SUCCESS]="Şifre başarıyla değiştirildi."
  [MSG_FAILED]="Şifre değiştirilemedi. Mevcut şifre hatalı olabilir veya yeni şifre reddedilmiş olabilir."
)

declare -A i18n_WIFI_MENU=(
  [NOTIFY_TITLE]="Wi-Fi"
  [NOTIFY_DEVICE_NOT_FOUND]="Wi-Fi aygıtı bulunamadı"
  [NOTIFY_NO_NETWORKS]="Yakında ağ bulunamadı"
  [NOTIFY_COMMAND_NOT_FOUND]="Gerekli komut bulunamadı: {COMMAND}"
  [PROMPT_SELECT]="Bir Wi-Fi ağı seç"
  [PROMPT_PASSWORD]="Şifre: {SSID}"
  [PROMPT_LABEL]="wifi> "
  [PROMPT_PASSWORD_LABEL]="şifre> "
  [MSG_DISCONNECTED]="{SSID} bağlantısı kesildi"
  [MSG_DISCONNECT_FAILED]="{SSID} bağlantısı kesilemedi"
  [MSG_CONNECTED]="{SSID} ağına bağlanıldı"
  [MSG_CONNECT_FAILED]="{SSID} ağına bağlanılamadı (şifre yanlış olabilir)"
  [MSG_HIDDEN]="<Gizli Ağ>"
)

declare -A i18n_GROUP_MANAGEMENT=(
  [TITLE]="Grup Yönetimi"
  [NO_GROUPS_AVAILABLE]="Eklenebilecek bir grup bulunamadı."
  [GROUP_ADDED]="{USER} kullanıcısı '{GROUP}' grubuna eklendi."
  [ADD_FAILED]="'{GROUP}' grubuna ekleme işlemi başarısız oldu."
  [NO_GROUPS_TO_REMOVE]="Çıkarılabilecek bir grup bulunamadı."
  [GROUP_REMOVED]="{USER} kullanıcısı '{GROUP}' grubundan çıkarıldı."
  [REMOVE_FAILED]="'{GROUP}' grubundan çıkarma işlemi başarısız oldu."
  [MSG_MANAGER_UNAVAILABLE]="Grup servisi çalışmıyor."
)

declare -A i18n_USER_MENU=(
  [NOTIFY_TITLE]="Kullanıcı Menüsü"
  [MSG_SCRIPT_MISSING]="Menü komutu bulunamadı: {SCRIPT}"
)

declare -A i18n_CONNECTION_CHECK=(
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi aygıtı bulunamadı\nİnternet bağlantısı durumu: {CONNECTIVITY}\nTıkla: Ağ Yöneticisini aç"
)

declare -A i18n_NET_MONITOR=(
  [USAGE_ERROR]="Kullanım: {SCRIPT} --ethernet <desen1,desen2,...> --other <desen1,desen2,...>"
  [UNKNOWN_PARAMETER]="Bilinmeyen parametre: {PARAM}"
  [LABEL_ETHERNET]="Ethernet:"
  [LABEL_OTHER]="Diğer:"
)

declare -A i18n_WIFI_MONITOR=(
  [DEVICE_DISCONNECTED]=$'Aygıt: {DEVICE}\nDurum: Bağlı değil'
  [DEVICE_CONNECTED]=$'Aygıt: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSinyal: {SIGNAL}'
)

declare -A i18n_AIRPLANE_MONITOR=(
  [ON]="Uçak modu: Açık"
  [OFF]="Uçak modu: Kapalı"
)

declare -A i18n_MEMORY_MONITOR=(
  [MEMORY_AVAILABLE]=$'Kullanılabilir bellek: {RATIO}%'
  [TOP_PROCESSES]="En çok bellek kullanan süreçler:"
  [NOTIFY_TITLE]="Bellek azalıyor"
  [NOTIFY_LOW_MEMORY]=$'Kullanılabilir bellek %{RATIO} değerine düştü.'
)

declare -A i18n_TEMP_MONITOR=(
  [TEMP_ALERT]=$'CPU sıcaklığı: {TEMP}°C'
  [WARNING]=$'Uyarı: CPU sıcaklığı {WARN_TEMP}°C üzerinde'
  [NOTIFY_TITLE]="CPU aşırı ısınıyor"
  [NOTIFY_CRITICAL]=$'CPU sıcaklığı {SECONDS} saniyedir {CRIT}°C üzerinde. Lütfen soğutma sistemini kontrol edin.'
)

declare -A i18n_CUPS_MONITOR=(
  [JOBS_HEADER]="Bekleyen yazdırma işleri:"
  [JOB_LINE]="  {JOB}  {OWNER}  {SIZE}"
  [PRINTERS_HEADER]="Yazıcılar:"
  [PRINTER_LINE]="  {PRINTER}: {STATE}"
  [STATE_IDLE]="boşta"
  [STATE_PRINTING]="yazdırıyor"
  [STATE_DISABLED]="devre dışı"
  [STATE_UNAVAILABLE]="erişilemez"
  [DEFAULT_PRINTER]="Varsayılan yazıcı: {PRINTER}"
  [DEFAULT_NONE]="Varsayılan yazıcı yok"
  [NOTIFY_TITLE]="Yazdırma işi hatası"
  [NOTIFY_ERROR]="{PRINTER} yazıcısındaki {JOB} işi durdu: {STATE}"
)

declare -A i18n_CUPS_MENU=(
  [MENU_PROMPT]="Yazdırma kuyruğu"
  [CANCEL_TITLE]="Yazdırma işini iptal et"
  [CANCEL_CONFIRM]="{PRINTER} yazıcısındaki {JOB} işi iptal edilsin mi?"
  [CANCEL_YES]="İptal et"
  [CANCEL_NO]="Vazgeç"
  [CANCEL_FAIL_TITLE]="İptal başarısız"
  [CANCEL_FAIL]="{PRINTER} yazıcısındaki {JOB} işi iptal edilemedi."
)

declare -A i18n_APPEARANCE_MENU=(
  [MSG_NO_ITEMS]="Öğe bulunamadı"
  [NOTIFY_TITLE]="Görünüm Ayarları"
  [MSG_SCRIPT_MISSING]="Menü komutu bulunamadı: {SCRIPT}"
)

declare -A i18n_SETTINGS_MENU=(
  [MSG_NO_ITEMS]="Ayar bulunamadı"
  [LABEL_auto_theme]="Otomatik Tema Değişimi"
  [LABEL_auto_update]="Güncellemeleri Takip Et"
  [LABEL_plane_mode_icon]="Uçak Modu Simgesi"
  [NOTIFY_TITLE]="Sistem Ayarları"
  [MSG_TOGGLED]="{LABEL}: {STATE}"
  [STATE_ON]="etkin"
  [STATE_OFF]="devre dışı"
  [ACTION_UNDO]="Geri al"
)

declare -A i18n_SYSTEM_MENU=(
  [MSG_NO_ITEMS]="Öğe bulunamadı"
)

declare -A i18n_DATETIME_SETTINGS=(
  [NOTIFY_TITLE]="Tarih ve Saat"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_NO_JQ]="jq kurulu değil"
  [MSG_NO_ZONES]="Saat dilimi bulunamadı"
  [MSG_NO_ITEMS]="Öğe bulunamadı"
  [MSG_SERVICE_UNAVAILABLE]="Zaman servisi çalışmıyor"
  [MSG_TIMEZONE_FAILED]="Saat dilimi {ZONE} olarak ayarlanamadı"
  [MSG_TIMEZONE_CHANGED]="Saat dilimi {ZONE} olarak ayarlandı"
  [MSG_TIMEZONE_PARTIAL]="Saat dilimi {ZONE} olarak ayarlandı, ancak /etc/rc.conf içindeki TIMEZONE ayarı kaldırılamadı."
  [MSG_RC_CONF_OVERRIDE]="/etc/rc.conf içinde hâlâ TIMEZONE ayarı var; açılışta seçimi geçersiz kılar."
  [MSG_NTP_ENABLED]="Otomatik saat (NTP) etkinleştirildi"
  [MSG_NTP_DISABLED]="Otomatik saat (NTP) devre dışı bırakıldı"
  [MSG_NTP_FAILED]="NTP ayarı değiştirilemedi"
  [MSG_CHRONY_MISSING]="chronyc kurulu değil; NTP durumu okunamıyor"
  [MSG_NTP_UNAVAILABLE]="NTP durumu okunamıyor"
  [MSG_STATUS]="Geçerli saat: {TIME}  |  {ZONE}  |  NTP: {NTP}"
  [LABEL_TIMEZONE]="Saat dilimi: {ZONE}"
  [LABEL_NTP]="Otomatik saat (NTP): {STATE}"
  [LABEL_NTP_DETAILS]="NTP ayrıntıları"
  [STATE_ON_SYNCED]="açık, eşitlendi"
  [STATE_ON_NOT_SYNCED]="açık, eşitlenmedi"
  [STATE_ON_UNAVAILABLE]="açık, durum okunamıyor"
  [STATE_OFF]="kapalı"
  [ZONE_UNKNOWN]="bilinmiyor"
  [PROMPT_TIMEZONE]="Saat dilimi: "
  [MSG_NTP_DETAILS]=$'Başvuru: {REFERENCE}\nKatman: {STRATUM}\nSistem farkı: {OFFSET} s\nÇevrimiçi kaynak: {SOURCES}\nArtık saniye durumu: {LEAP}'
)

declare -A i18n_DISPLAY_SETTINGS=(
  [NOTIFY_TITLE]="Ekran Ayarları"
  [MSG_MISSING_CMD]="Gerekli komut bulunamadı: {CMD}"
  [MSG_NO_SWAY]="Ekran bilgisi okunamadı."
  [MSG_NO_OUTPUTS]="Ekran çıkışı bulunamadı."
  [MSG_OUTPUT_INFO]="{MODE} @{REFRESH}Hz  x{SCALE}"
  [RESOLUTION]="Çözünürlük"
  [SCALE]="Ölçek"
  [DISABLE]="Devre dışı bırak"
  [MSG_APPLIED]="Ekran güncellendi: {NAME}"
  [MSG_FAILED]="Ekran güncellenemedi: {NAME}"
)

declare -A i18n_SHOW_DEVICES=(
  [PROMPT_DEVICE]="Aygıt: "
  [MSG_NO_DEVICES]="Aygıt bulunamadı"
  [MSG_NO_DATA]="Aygıt verisi bulunamadı"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_NO_JQ]="jq kurulu değil"
)

declare -A i18n_SHOW_DEVICE_MODS=(
  [MSG_MESG]="Modüller"
  [PROMPT_MODULE]="Modül: "
  [MSG_NO_MODULES]="Bu aygıt için modül bulunamadı"
  [MSG_NO_DATA]="Aygıt verisi bulunamadı"
  [MSG_DEVICE_NOT_FOUND]="Aygıt bulunamadı: "
  [MSG_BAD_DEVICE]="Bilinmeyen aygıt: "
  [MSG_ALREADY_IN_USE]="{MODULE} modülü zaten kullanımda."
  [ITEM_NVIDIA_DETECT]="Uygun NVIDIA sürücüsünü algıla"
  [MSG_USAGE]="Kullanım: show-device-mods.sh <aygıt>"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_NO_JQ]="jq kurulu değil"
)

declare -A i18n_SHOW_SERVICES=(
  [NOTIFY_TITLE]="Servisler"
  [MSG_MESG]="Servisler"
  [PROMPT_SERVICE]="Servis: "
  [MSG_NO_SERVICES]="Servis bulunamadı"
  [LABEL_DISABLED]="devre dışı"
  [LABEL_FAILED]="başarısız"
  [LABEL_BOOT_OFF]="açılışta başlamaz"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_MANAGER_UNAVAILABLE]="Servis yöneticisi çalışmıyor"
)

declare -A i18n_TOGGLE_SERVICE=(
  [NOTIFY_TITLE]="Servisler"
  [MSG_STARTED]="{SERVICE} servisi başlatıldı"
  [MSG_STOPPED]="{SERVICE} servisi durduruldu; açılışta yine başlar"
  [MSG_STOPPED_MANUAL]="{SERVICE} servisi durduruldu; açılışta başlamaz"
  [MSG_RESTARTED]="{SERVICE} servisi yeniden başlatıldı"
  [MSG_ENABLED]="{SERVICE} servisi etkinleştirildi ve başlatıldı"
  [MSG_DISABLED]="{SERVICE} servisi devre dışı bırakıldı"
  [MSG_BOOT_OFF]="{SERVICE} servisi açılışta başlamayacak"
  [MSG_BOOT_ON]="{SERVICE} servisi açılışta başlayacak"
  [MSG_ONCE]="{SERVICE} servisi bir kez çalıştırıldı"
  [MSG_PROTECTED]="{SERVICE} servisi durdurulamaz"
  [MSG_FAILED]="{SERVICE} servisi değiştirilemedi"
  [MSG_NOT_FOUND]="Servis bulunamadı: {SERVICE}"
  [MSG_MANAGER_UNAVAILABLE]="Servis yöneticisi çalışmıyor"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_USAGE]="Kullanım: toggle-service.sh <servis-adı>"
  [MSG_DETAIL_TITLE]="Servis {SERVICE}"
  [MSG_NO_TERMINAL]="Terminal penceresi açılamadı"
  [ACTION_START]="Şimdi başlat"
  [ACTION_STOP]="Şimdi durdur"
  [ACTION_RESTART]="Yeniden başlat"
  [ACTION_ENABLE]="Etkinleştir ve başlat"
  [ACTION_DISABLE]="Servisi devre dışı bırak"
  [ACTION_BOOT_OFF]="Açılışta başlatmayı kapat"
  [ACTION_BOOT_ON]="Açılışta başlatmayı aç"
  [ACTION_DETAIL]="Ayrıntılar"
  [ACTION_ONCE]="Bir kez çalıştır"
  [ACTION_SHOW_LOGS]="Log kayıtlarını göster"
  [ACTION_CLOSE]="Kapat"
  [LABEL_STATE]="Durum"
  [LABEL_PID]="PID"
  [LABEL_BOOT]="Açılışta"
  [LABEL_CHECK]="Kontrol"
  [LABEL_PROTECTED]="korumalı"
  [STATE_RUNNING]="çalışıyor"
  [STATE_DOWN]="durdu"
  [STATE_DISABLED]="devre dışı"
  [STATE_FAILED]="başarısız"
  [STATE_UNKNOWN]="bilinmiyor"
  [BOOT_AUTO]="başlar"
  [BOOT_MANUAL]="başlamaz"
  [CHECK_OK]="hazır"
  [CHECK_FAILED]="hazır değil"
)

declare -A i18n_SHOW_SERVICE_LOGS=(
  [LABEL_SERVICE]="Servis"
  [MSG_FOLLOWING]="Son 20 log kaydı gösteriliyor ve yeni kayıtlar izleniyor. Kapatmak için Ctrl+C."
  [MSG_LOG_UNAVAILABLE]="Log servisi çalışmıyor"
  [MSG_NOT_FOUND]="Servis bulunamadı"
  [MSG_INVALID_SERVICE]="Geçersiz servis adı"
  [MSG_USAGE]="Kullanım: kayra-show-service-logs.sh <servis-adı>"
)

declare -A i18n_FONT_SETTINGS=(
  [NOTIFY_TITLE]="Yazı Tipi Ayarları"
  [MSG_FONT_CHANGED]="Yazı tipi {FONT} olarak değiştirildi"
  [MSG_FONT_UNCHANGED]="Yazı tipi {FONT} zaten seçili"
  [MSG_FONT_FAILED]="Yazı tipi {FONT} olarak değiştirilemedi"
)

declare -A i18n_SET_LANGUAGE=(
  [NOTIFY_TITLE]="Dil"
  [MSG_CHANGED]="{LANG} olarak değiştirildi. Tüm uygulamalara uygulanması için oturumu kapatıp yeniden açın."
  [MSG_FAILED]="Dil değiştirilemedi: {LANG}"
  [MSG_PREPARING]="{LANG} için dil verisi hazırlanıyor..."
  [MSG_NO_LOCALE_DATA]="Arayüz dili {LANG} olarak ayarlandı, ancak {LOCALE} sistem yerel verisi üretilmemiş. Bir yönetici üretebilir; biçimlendirme ve bazı uygulamalar sistem dilinde kalır. Değişikliğin uygulanması için oturumu kapatıp yeniden açın."
  [MSG_NO_UI_DATA]="Kayra arayüzü için {LANG} çevirisi yok. İngilizce arayüz kullanılıyor; sistem yereli {LOCALE} olarak ayarlandı. Değişikliğin uygulanması için oturumu kapatıp yeniden açın."
  [MSG_NO_UI_AND_LOCALE]="Kayra arayüzü için {LANG} çevirisi yok; İngilizce kullanılıyor. Ayrıca {LOCALE} sistem yerel verisi üretilmemiş; bir yönetici üretebilir. Değişikliğin uygulanması için oturumu kapatıp yeniden açın."
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [MSG_NO_LANGUAGES]="Dil veri dosyası bulunamadı."
  [NOTIFY_TITLE]="Dil"
  [MSG_FAILED]="Dil değiştirilemedi: {LANG}"
  [MSG_SYSTEM_DATA_MISSING]="sistem verisi üretilmemiş"
  [ADD_LANGUAGE]="Dil Ekle..."
  [SYSTEM_ONLY]="Kayra çevirisi yok"
  [MSG_ADD_UNAVAILABLE]="Dil ekleme yardımcısı bulunamadı."
)

declare -A i18n_LANGUAGE_ADD=(
  [NOTIFY_TITLE]="Dil Ekle"
  [PROMPT_SEARCH]="Ara: "
  [MSG_NO_LOCALES]="Eklenecek yeni UTF-8 yereli bulunamadı."
  [MSG_MISSING_TRANSLATION]="{CODE} için Kayra arayüz çevirisi yok. İngilizce arayüz kullanılacak. {LOCALE} dil menüsüne eklensin mi?"
  [BUTTON_ADD]="Ekle"
  [BUTTON_CANCEL]="Vazgeç"
  [MSG_ADDED]="{LOCALE} dil menüsüne eklendi."
  [MSG_EXISTS]="{LOCALE} zaten dil menüsünde."
  [MSG_FAILED]="{LOCALE} eklenemedi."
  [MSG_SERVICE_UNAVAILABLE]="Dil servisi kullanılamıyor."
  [MSG_INVALID_LOCALE]="Geçersiz yerel: {LOCALE}"
  [MSG_REGISTRY_MISSING]="Dil kayıt defteri bulunamadı."
  [MSG_LOCALE_DB_MISSING]="Yerel veritabanı bulunamadı."
)

declare -A i18n_KEYBOARD_SETTINGS=(
  [PROMPT_SELECT]="Klavye düzeni seç: "
  [NOTIFY_TITLE]="Klavye Düzeni"
  [MSG_CHANGED]="Klavye düzeni değiştirildi: {LAYOUT}"
  [MSG_VARIANT]="Varyant: {VARIANT}"
  [MSG_FAILED]="Klavye düzeni değiştirilemedi"
  [MSG_UNCHANGED]="Klavye düzeni zaten ayarlanmış"
  [ERROR_DATA_NOT_FOUND]="Klavye veri dosyaları bulunamadı. Lütfen kayra-generate-keyboard-data.sh betiğini çalıştırın"
  [ERROR_SELECTION_NOT_FOUND]="Seçim klavye veritabanında bulunamadı"
  [ERROR_CONFIG_NOT_FOUND]="Klavye yapılandırma dosyası bulunamadı"
  [ERROR_NO_SELECTION]="Klavye düzeni verilmedi"
)

declare -A I18N_REMOVABLE_STORAGE_MONITOR=(
  [NEW_STORAGE]="Yeni depolama birimi"
  [ACTION_OPEN]="Aç"
  [ACTION_MOUNT]="Bağla"
  [TOOLTIP_EMPTY]="Çıkarılabilir depolama aygıtı yok"
  [TOOLTIP_PRESENT]="Çıkarılabilir depolama aygıtları"
  [TOOLTIP_RIGHT_CLICK_INFO]="Sağ tık: Aygıtı çıkar"
)

declare -A I18N_REMOVABLE_MENU=(
  [MENU_TITLE]="Depolava"
  [NO_PARTITIONS]="Çıkarılabilir bölüm yok"
  [MOUNT_FAILED]="Bağlama başarısız"
  [MOUNT_FAILED_MSG]="{DEVICE}"
)

declare -A I18N_REMOVABLE_EJECT_MENU=(
  [NO_DEVICES]="Bağlı çıkarılabilir aygıt yok"
  [EJECT_TITLE]="Çıkar"
  [EJECT_SUCCESS]="{DEVICE} güvenle çıkarılabilir"
  [EJECT_PARTIAL]="{DEVICE} ayrıldı (power-off desteklenmiyor olabilir, çıkarmak güvenli)"
  [EJECT_FAILED]="Çıkarma başarısız"
  [EJECT_FAILED_MSG]="Ayrılamayan (meşgul olabilir): {DEVICES}"
)



declare -A i18n_WAYBAR_CONFIG=(
  [APP_MENU_TOOLTIP]="Uygulama Menüsü\nSağ tık: Yazılımları kur/kaldır"
  [APP_PINS_TOOLTIP]="Sabitlenen uygulamalar\nSol tık: Uygulama ekle\nSağ tık: Komut ekle"
  [CLIPBOARD_TOOLTIP]="Sol tık: Pano Geçmişi\nSağ tık: Geçmişi Temizle"
  [BATTERY_TOOLTIP]="Kapasite: {capacity}% ({time})"
  [BATTERY_TOOLTIP_CHARGING]="Şarj Oluyor: {capacity}% (Dolmaya kalan: {time})"
  [BATTERY_EVENT_WARNING]="Düşük Pil"
  [BATTERY_EVENT_CRITICAL]="Çok Düşük Pil"
  [BATTERY_EVENT_DISCHARGING]="Güç Anahtarı Boşalıyor"
  [BATTERY_EVENT_CHARGING]="Güç Anahtarı Şarj Oluyor"
)

declare -A i18n_XBPS_MANAGER=(
  [NO_DATA]="Yazılım verileri indirilmemiş"
  [ACTION_DOWNLOAD]="Verileri indir"
  [LOCK_MSG]="Devam eden yazılım işlemleri var, sonuçlanmasını bekleyin lütfen."
  [REMOVE_CONFIRM]="{PACKAGE} Yazılımını kaldırmak istiyor musunuz?"
  [ACTION_REMOVE]="Kaldır"
  [REMOVE_OK]="Paket başarıyla kaldırıldı"
  [REMOVE_FAIL]="Paket kaldırılırken hata oluştu"
  [INSTALL_CONFIRM]="{PACKAGE} Yazılımını kurmak istiyor musunuz?"
  [INSTALL_OK]="Paket başarıyla kuruldu"
  [INSTALL_FAIL]="Paket kurulurken hata oluştu"
  [ACTION_INSTALL]="Kur"
  [CD_ERR]="Yazılım deposu bulunamıyor."
  [APP_NAME]="Yazılım Deposu"
  [LOCK_DOWNLOAD]="Yazılım bilgileri indiriliyor."
  [LOCK_PREPARE]="Yazılım derleme ortamı hazırlanıyor."
  [LOCK_REMOVE]="Yazılım kaldırılıyor: {PACKAGE}"
  [LOCK_INSTALL]="Yazılım sisteme kuruluyor: {PACKAGE}"
  [LOCK_UPDATE]="Yazılım deposu güncelleniyor."
  [LOCK_UPDATE_INFO]="Yazılım deposu güncel paket bilgileri indiriliyor."
  [LOCK_BUILD]="Yazılım derleniyor: {PACKAGE}"
  [DOWNLOAD_OK]="Yazılım bilgileri indirildi, kurulum için hazır."
  [INSTALLED_CONFIRM]="{PACKAGE} kurulu ve bir güncelleme var. Ne yapmak istersiniz?"
  [ACTION_UPDATE]="Güncelle"
  [ACTION_SYS_UPDATE]="Sistemi güncelle"
  [ACTION_CANCEL]="İptal"
  [ACTION_CLEAN]="Temizle"
  [ACTION_DISK_USAGE]="Disk Kullanımını Göster"
  [ACTION_OK]="Tamam"
  [UPDATE_PKG_OK]="Paket başarıyla güncellendi"
  [UPDATE_PKG_FAIL]="Paket güncellenirken hata oluştu"
  [UPDATE_CONFIRM]="{COUNT} paket: indirme {DOWNLOAD}, kurulum {INSTALL}, boş {FREE}. Sistem güncellensin mi?"
  [UPDATE_CLEAN_CONFIRM]="Yeterli boş alan yok (gereken {INSTALL}, boş {FREE}). Paket önbelleği ve tüm indirme önbelleği temizlenip devam edilsin mi?"
  [UPDATE_DOWNLOAD]="Güncellemeler indiriliyor ve kuruluyor."
  [UPDATE_SOURCE]="Kaynak paketler derleniyor: {PACKAGES}"
  [UPDATE_OK]="Sistem güncellendi"
  [UPDATE_NONE]="Sistem güncel"
  [DISK_LOW]="Yeterli boş disk alanı yok."
  [CHECK_UPDATES]="Güncellemeleri Kontrol Et"
  [UPDATES_PROMPT]="Güncellemeler"
  [UPDATES_TITLE]="Kullanılabilir güncellemeler: {COUNT}"
  [UPDATES_SOURCE_TAG]="(kaynak)"
)

declare -A i18n_POWER_MENU=(
  [ITEM_SHUTDOWN]="Kapat"
  [ITEM_REBOOT]="Yeniden Başlat"
  [ITEM_SUSPEND]="Askıya Al"
  [ITEM_LOGOUT]="Oturumu Kapat"
  [ITEM_LOCK]="Kilitle"
  [NOTIFY_TITLE]="Güç Menüsü"
  [LOCK_MSG]="Yazılım değişikliklerinin tamamlanmasını bekleyin"
  [MSG_BLOCKED]="Bu işlem engellendi."
  [MSG_UNKNOWN_ACTION]="Bilinmeyen işlem seçildi."
)

declare -A i18n_BLUETOOTH_MONITOR=(
  [ADAPTER_OFF]="Bluetooth: Kapalı"
  [DISCONNECTED]=$'Bluetooth: Açık\nBağlı cihaz yok'
  [CONNECTED]=$'Bluetooth: Bağlı\n{DEVICES}'
)

declare -A i18n_BLUETOOTH_MENU=(
  [NOTIFY_TITLE]="Bluetooth"
  [NOTIFY_NO_DEVICE]="Bluetooth adaptörü bulunamadı"
  [NOTIFY_COMMAND_NOT_FOUND]="Gerekli komut bulunamadı: {COMMAND}"
  [PROMPT_SELECT]="Bir Bluetooth cihazı seç"
  [PROMPT_LABEL]="bt> "
  [ACTION_POWER_ON]="Bluetooth'u aç"
  [ACTION_POWER_OFF]="Bluetooth'u kapat"
  [ACTION_SCAN]="Cihazları tara"
  [MSG_POWER_ON]="Bluetooth açıldı"
  [MSG_POWER_OFF]="Bluetooth kapatıldı"
  [MSG_POWER_FAILED]="Bluetooth güç durumu değiştirilemedi"
  [MSG_CONNECTED]="{NAME} bağlandı"
  [MSG_DISCONNECTED]="{NAME} bağlantısı kesildi"
  [MSG_CONNECT_FAILED]="{NAME} cihazına bağlanılamadı"
  [MSG_DISCONNECT_FAILED]="{NAME} bağlantısı kesilemedi"
  [MSG_PAIRED]="{NAME} eşleştirildi ve bağlandı"
  [MSG_PAIR_FAILED]="{NAME} eşleştirilemedi"
  [MSG_SCAN_STARTED]="Cihazlar taranıyor..."
  [MSG_NO_DEVICES]="Cihaz bulunamadı"
)

# NVIDIA sürücü tespiti (nvidia-detect.sh)
declare -A i18n_NVIDIA_DETECT=(
  [APP_NAME]="NVIDIA Sürücü"
  [MISSING_CMD]="Gerekli komut bulunamadı: {COMMAND}"
  [NO_GPU]="Bu sistemde NVIDIA GPU bulunamadı."
  [REPO_EMPTY]="Depolarda NVIDIA sürücü paketi bulunamadı."
  [DOWNLOAD_FAIL]="NVIDIA'dan desteklenen GPU listesi indirilemedi. Ağ bağlantınızı kontrol edin."
  [UNSUPPORTED]="Depolardaki hiçbir sürücü paketi {GPU} kartını desteklemiyor. Açık kaynak nouveau sürücüsünü düşünün."
  [RECOMMEND]=$'Algılanan: {GPU}\nÖnerilen sürücü: {PACKAGE}'
  [INSTALL_CONFIRM]="{PACKAGE} sürücü paketi kurulsun mu?"
  [ACTION_INSTALL]="Kur"
  [ALREADY_OK]="Zaten kurulu ve güncel: {PACKAGE} ({VERSION})."
  [UPDATE_INFO]="Kurulu: {INSTALLED} - mevcut: {AVAILABLE}."
  [UPDATE_HINT]="Paket yöneticinizle güncelleyin."
  [CONFLICT]="Uyarı: başka bir NVIDIA sürücü dalı da kurulu: {PACKAGES}."
)

# Sabitlenen uygulama çubuğu (waybar-app-pins.sh, waybar-app-pins-slot.sh)
declare -A i18n_APP_PINS=(
  [NOTIFY_TITLE]="Uygulama Çubuğu"
  [MENU_PROMPT]="Uygulama ekle"
  [COMMAND_PROMPT]="Komut"
  [REMOVE_ACTION]="Kaldır"
  [MSG_ADDED]="{APP} çubuğa eklendi"
  [MSG_CMD_ADDED]="{CMD} komutu çubuğa eklendi"
  [MSG_REMOVED]="{APP} çubuktan kaldırıldı"
  [MSG_ALREADY]="{APP} zaten çubukta"
  [MSG_NO_APPS]="Uygulama bulunamadı"
  [MSG_FULL]="Tüm slotlar dolu. Slot eklemek için: waybar-app-pins-slot.sh add"
  [MSG_SLOT_COUNT]="Sabitlenen slotlar (kullanılan/toplam): {COUNT}"
  [MSG_SLOT_ADDED]="Slot {INDEX} eklendi"
  [MSG_SLOT_REMOVED]="Slot {INDEX} kaldırıldı"
  [MSG_SLOT_LAST_FULL]="{INDEX} numaralı slot kullanımda, kaldırılamaz"
  [MSG_NO_SLOTS]="Kaldırılacak slot yok"
  [MSG_FAILED]="İşlem başarısız"
)

declare -A i18n_POWER_MODE_MENU=(
  [PROFILE_PERFORMANCE]="Performans"
  [PROFILE_BALANCED]="Dengeli"
  [PROFILE_POWER_SAVER]="Güç Tasarrufu"
  [PROFILE_AUTO]="Otomatik"
  [NOTIFY_TITLE]="Güç Modu"
  [MSG_SET]="Güç modu {PROFILE} olarak ayarlandı"
  [MSG_AUTO_SET]="Otomatik güç profiline geçildi"
  [MSG_SET_FAILED]="Güç modu ayarlanamadı"
  [MSG_SERVICE_UNAVAILABLE]="Güç servisi çalışmıyor"
)

# Startup commands menu labels (icons and commands are defined in autostart.sh)
declare -A autostart_menu=(
  [ADD]="Açılış komutu ekle"
  [REMOVE]="Açılış komutunu kaldır"
  [TOGGLE]="Açılış komutunu aç/kapat"
  [EDIT]="Açılış listesini düzenle"
  [RUN]="Açılış komutlarını şimdi çalıştır"
)

declare -A i18n_AUTOSTART=(
  [NOTIFY_TITLE]="Açılış Komutları"
  [PROMPT_ADD]="Komut"
  [MSG_ADDED]="Açılış komutu eklendi: {CMD}"
  [MSG_ALREADY]="Listede zaten var: {CMD}"
  [MSG_INVALID]="Geçersiz komut. # veya off: ile başlamamalı"
  [MSG_REMOVED]="Açılış komutu kaldırıldı: {CMD}"
  [MSG_TOGGLED]="{CMD}: {STATE}"
  [STATE_ON]="etkin"
  [STATE_OFF]="devre dışı"
  [MSG_NO_COMMANDS]="Açılış komutu bulunamadı"
  [MSG_EDIT_OPENED]="Açılış listesi açıldı"
  [MSG_EDIT_FAILED]="Açılış listesi açılamadı"
  [MSG_RUNNING]="Açılış komutları başlatılıyor"
  [MSG_READ_FAILED]="Açılış listesi okunamadı"
)
