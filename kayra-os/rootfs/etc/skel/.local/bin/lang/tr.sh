#!/bin/bash

declare -A i18n=(
  [WELCOME]="Hoşgeldiniz"
  [NOT_INSTALLED]="{BIN} kurulu değil"
  [OPERATION_CANCELLED]="İşlem iptal edildi"
  [SUCCESS]="Başarı"
  [ERROR]="Hata"
  [FAILED]="Başarısız"
  [REMOVE_CONFIRM]="%s Yazılımını kaldırmak istiyor musunuz?"
  [ACTION_REMOVE]="Kaldır"
)

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
  [DEVICES]="Aygıtlar"
  [SERVICES]="Servisler"
  [SETTINGS]="Ayarlar"
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
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHANGE_PASSWD=(
  [PROMPT_CURRENT]="Mevcut şifre: "
  [PROMPT_NEW]="Yeni şifre: "
  [PROMPT_NEW_REPEAT]="Yeni şifre (tekrar): "
  [NOTIFY_TITLE]="Şifre değiştirme"
  [MSG_NOT_INSTALLED]="{BIN} kurulu değil (xbps-install -S {BIN})"
  [MSG_CANCELLED]="İşlem iptal edildi"
  [MSG_MISMATCH]="Yeni şifreler birbiriyle eşleşmiyor."
  [MSG_SUCCESS]="Şifre başarıyla değiştirildi."
  [MSG_FAILED]="Şifre değiştirilemedi. Mevcut şifre hatalı olabilir."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
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
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_USER_INFO=(
  [LABEL_GROUPS]="Gruplar:"
  [LABEL_SUPERVISOR]="Yönetici"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_GROUP_MANAGEMENT=(
  [PROMPT_GROUP_NAME]="Grup adı: "
  [PROMPT_CONFIRM]="Emin misiniz?"
  [MSG_SUCCESS]="İşlem tamamlandı."
  [MSG_FAILED]="İşlem başarısız oldu."
  [MSG_GROUP_EXISTS]="Grup zaten mevcut."
  [MSG_GROUP_NOT_FOUND]="Grup bulunamadı."
  [MSG_USER_NOT_FOUND]="Kullanıcı bulunamadı."
  [TITLE]="Grup Yönetimi"
  [NO_GROUPS_AVAILABLE]="Eklenebilecek bir grup bulunamadı."
  [GROUP_ADDED]="{USER} kullanıcısı '{GROUP}' grubuna eklendi."
  [ADD_FAILED]="'{GROUP}' grubuna ekleme işlemi başarısız oldu."
  [NO_GROUPS_TO_REMOVE]="Çıkarılabilecek bir grup bulunamadı."
  [EXCEPTION_GROUP]="'{GROUP}' istisna grubudur, {USER} kullanıcısı bu gruptan çıkarılamaz."
  [GROUP_REMOVED]="{USER} kullanıcısı '{GROUP}' grubundan çıkarıldı."
  [REMOVE_FAILED]="'{GROUP}' grubundan çıkarma işlemi başarısız oldu."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_USER_MENU=(
  [PROMPT_SEARCH]="Ara: "
  [MSG_NO_ITEMS]="Öğe bulunamadı"
  [USAGE_ERROR]="Kullanım: {SCRIPT} <json-dosya> [fuzzel parametreleri...]"
  [FILE_NOT_FOUND]="Hata: Dosya bulunamadı -> {FILE}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
  [NOTIFY_TITLE]="Kullanıcı Menüsü"
  [MSG_SCRIPT_MISSING]="Menü komutu bulunamadı: {SCRIPT}"
)

declare -A i18n_CONNECTION_CHECK=(
  [MSG_ONLINE]="Çevrimiçi"
  [MSG_OFFLINE]="Çevrimdışı"
  [MSG_CHECKING]="Bağlantı kontrol ediliyor..."
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi aygıtı bulunamadı\nİnternet bağlantısı durumu: {CONNECTIVITY}\nTıkla: Ağ Yöneticisini aç"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_NET_MONITOR=(
  [USAGE_ERROR]="Kullanım: {SCRIPT} --ethernet <desen1,desen2,...> --other <desen1,desen2,...>"
  [UNKNOWN_PARAMETER]="Bilinmeyen parametre: {PARAM}"
  [LABEL_ETHERNET]="Ethernet:"
  [LABEL_OTHER]="Diğer:"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_WIFI_MONITOR=(
  [DEVICE_DISCONNECTED]=$'Aygıt: {DEVICE}\nDurum: Bağlı değil'
  [DEVICE_CONNECTED]=$'Aygıt: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSinyal: {SIGNAL}'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_MEMORY_MONITOR=(
  [MEMORY_AVAILABLE]=$'Kullanılabilir bellek: {RATIO}%'
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHECK_GROUPS=(
  [NOTIFY_TITLE]="Grup Kontrolü"
  [NOTIFY_MSG]="Grup üyeliği eksik"
  [NOTIFY_ACTION]="Grup ekle"
  [MISSING_GROUPS]="Üye olmadığınız gruplar: {GROUPS}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_FIX_GROUPS=(
  [NOTIFY_TITLE]="Grup Kontrolü"
  [TITLE_SUCCESS]="Gruplar eklendi"
  [MSG_SUCCESS]="Değişikliklerin etkili olması için çıkış yapıp tekrar giriş yapın."
  [TITLE_FAILED]="İşlem iptal edildi veya başarısız oldu"
  [MSG_FAILED]="Eksik gruplar eklenemedi."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SYSTEM_INFO=(
  [LABEL_SYSTEM]="Sistem"
  [LABEL_KERNEL]="Çekirdek"
  [LABEL_CPU]="İşlemci"
  [LABEL_GPU]="Grafik Kartı"
  [LABEL_RAM]="RAM"
  [LABEL_DISK]="Disk"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_APPEARANCE_MENU=(
  [MSG_NO_ITEMS]="Öğe bulunamadı"
  [NOTIFY_TITLE]="Görünüm Ayarları"
  [MSG_SCRIPT_MISSING]="Menü komutu bulunamadı: {SCRIPT}"
)

declare -A i18n_SETTINGS_MENU=(
  [MSG_NO_ITEMS]="Ayar bulunamadı"
  [LABEL_auto_theme]="Otomatik Tema Değişimi"
  [LABEL_auto_update]="Otomatik Güncelleme"
  [NOTIFY_TITLE]="Sistem Ayarları"
  [MSG_TOGGLED]="{LABEL}: {STATE}"
  [STATE_ON]="etkin"
  [STATE_OFF]="devre dışı"
  [ACTION_UNDO]="Geri al"
)

declare -A i18n_SYSTEM_MENU=(
  [MSG_NO_ITEMS]="Öğe bulunamadı"
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
  [MSG_USAGE]="Kullanım: show-device-mods.sh <aygıt>"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
  [MSG_NO_JQ]="jq kurulu değil"
)

declare -A i18n_SHOW_SERVICES=(
  [MSG_MESG]="Servisler"
  [PROMPT_SERVICE]="Servis: "
  [MSG_NO_SERVICES]="Servis bulunamadı"
  [LABEL_DISABLED]="devre dışı"
  [MSG_NO_FUZZEL]="fuzzel kurulu değil"
)

declare -A i18n_TOGGLE_SERVICE=(
  [NOTIFY_TITLE]="Servisler"
  [MSG_STARTED]="{SERVICE} servisi başlatıldı"
  [MSG_STOPPED]="{SERVICE} servisi durduruldu"
  [MSG_ENABLED]="{SERVICE} servisi etkinleştirildi ve başlatıldı"
  [MSG_PROTECTED]="{SERVICE} servisi durdurulamaz"
  [MSG_FAILED]="{SERVICE} servisi değiştirilemedi"
  [MSG_NOT_FOUND]="Servis bulunamadı: {SERVICE}"
  [MSG_USAGE]="Kullanım: toggle-service.sh <servis-adı>"
)

declare -A i18n_FONT_SETTINGS=(
  [PROMPT_SELECT]="Yazı tipi seç: "
  [NOTIFY_TITLE]="Yazı Tipi Ayarları"
  [MSG_FONT_CHANGED]="Yazı tipi {FONT} olarak değiştirildi"
  [MSG_FONT_UNCHANGED]="Yazı tipi {FONT} zaten seçili"
  [MSG_FONT_FAILED]="Yazı tipi {FONT} olarak değiştirilemedi"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_CHANGE_FONT_SIZE=(
  [USAGE_ERROR]="Kullanım: {SCRIPT} <boyut>"
  [ERROR_INVALID_SIZE]="Hata: Font büyüklüğü {MIN} ile {MAX} arasında olmalı"
  [ERROR_SETTINGS_NOT_FOUND]="Hata: Ayarlar dosyası bulunamadı: {FILE}"
  [MSG_SUCCESS]="Başarılı"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_SET_LANGUAGE=(
  [NOTIFY_TITLE]="Dil"
  [MSG_CHANGED]="Değiştirildi: {LANG}"
  [MSG_FAILED]="Dil değiştirilemedi: {LANG}"
  [MSG_NO_LANG_DATA]="{LANG} için dil verisi bulunamadı. Arayüz için İngilizce veriler kullanılıyor, sistem yereli {LOCALE} olarak ayarlandı."
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [MSG_NO_LANGUAGES]="No language files were found."
  [PROMPT_SELECT]="Seç: "
  [NOTIFY_TITLE]="Dil"
  [MSG_CHANGED]="Değiştirildi: {LANG}"
  [MSG_FAILED]="Dil değiştirilemedi: {LANG}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A i18n_KEYBOARD_SETTINGS=(
  [PROMPT_SELECT]="Klavye düzeni seç: "
  [NOTIFY_TITLE]="Klavye Düzeni"
  [MSG_CHANGED]="Klavye düzeni değiştirildi: {LAYOUT}"
  [MSG_VARIANT]="Varyant: {VARIANT}"
  [MSG_FAILED]="Klavye düzeni değiştirilemedi"
  [MSG_UNCHANGED]="Klavye düzeni zaten ayarlanmış"
  [ERROR_DATA_NOT_FOUND]="Klavye veri dosyaları bulunamadı. Lütfen generate-keyboard-data.sh betiğini çalıştırın"
  [ERROR_SELECTION_NOT_FOUND]="Seçim klavye veritabanında bulunamadı"
  [ERROR_CONFIG_NOT_FOUND]="Klavye yapılandırma dosyası bulunamadı"
  [ERROR_NO_SELECTION]="Klavye düzeni verilmedi"
)

declare -A I18N_REMOVABLE_STORAGE_MONITOR=(
  [NEW_STORAGE]="Yeni depolama birimi"
  [ACTION_OPEN]="Aç"
  [ACTION_MOUNT]="Bağla"
  [ACTION_DEFAULT]="Aç"
  [TOOLTIP_EMPTY]="Çıkarılabilir depolama aygıtı yok"
  [TOOLTIP_PRESENT]="Çıkarılabilir depolama aygıtları"
  [TOOLTIP_RIGHT_CLICK_INFO]="Sağ tık: Aygıtı çıkar"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A I18N_REMOVABLE_MENU=(
  [MENU_TITLE]="Depolava"
  [NO_PARTITIONS]="Çıkarılabilir bölüm yok"
  [MOUNT_FAILED]="Bağlama başarısız"
  [MOUNT_FAILED_MSG]="{DEVICE}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)

declare -A I18N_REMOVABLE_EJECT_MENU=(
  [NO_DEVICES]="Bağlı çıkarılabilir aygıt yok"
  [EJECT_TITLE]="Çıkar"
  [EJECT_SUCCESS]="{DEVICE} güvenle çıkarılabilir"
  [EJECT_PARTIAL]="{DEVICE} ayrıldı (power-off desteklenmiyor olabilir, çıkarmak güvenli)"
  [EJECT_FAILED]="Çıkarma başarısız"
  [EJECT_FAILED_MSG]="Ayrılamayan (meşgul olabilir): {DEVICES}"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
)



declare -A i18n_WAYBAR_CONFIG=(
  [LOCK_TOOLTIP]="Kilitle"
  [LOGOUT_TOOLTIP]="Oturumu Kapat"
  [REBOOT_TOOLTIP]="Yeniden Başlat"
  [SHUTDOWN_TOOLTIP]="Kapat"
  [APP_MENU_TOOLTIP]="Uygulama Menüsü\nSağ tık: Yazılımları kur/kaldır"
  [CLIPBOARD_TOOLTIP]="Sol tık: Pano Geçmişi\nSağ tık: Geçmişi Temizle"
  [BATTERY_TOOLTIP]="Kapasite: {capacity}% ({time})"
  [BATTERY_TOOLTIP_CHARGING]="Şarj Oluyor: {capacity}% (Dolmaya kalan: {time})"
  [BATTERY_EVENT_WARNING]="Düşük Pil"
  [BATTERY_EVENT_CRITICAL]="Çok Düşük Pil"
  [BATTERY_EVENT_FULL]="Pil Dolu!"
  [BATTERY_EVENT_DISCHARGING]="Güç Anahtarı Boşalıyor"
  [BATTERY_EVENT_CHARGING]="Güç Anahtarı Şarj Oluyor"
  [REMOVE_CONFIRM]="Remove %s software?"
  [ACTION_REMOVE]="Remove"
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
  [UPDATE_PKG_OK]="Paket başarıyla güncellendi"
  [UPDATE_PKG_FAIL]="Paket güncellenirken hata oluştu"
  [UPDATE_CONFIRM]="{COUNT} paket: indirme {DOWNLOAD}, kurulum {INSTALL}, boş {FREE}. Sistem güncellensin mi?"
  [UPDATE_CLEAN_CONFIRM]="Yeterli boş alan yok (gereken {INSTALL}, boş {FREE}). Paket önbelleği temizlenip devam edilsin mi?"
  [UPDATE_SYNC]="Yazılım depoları senkronize ediliyor."
  [UPDATE_DOWNLOAD]="Güncellemeler indiriliyor ve kuruluyor."
  [UPDATE_SOURCE]="Kaynak paketler derleniyor: {PACKAGES}"
  [UPDATE_OK]="Sistem güncellendi"
  [UPDATE_NONE]="Sistem güncel"
  [DISK_LOW]="Yeterli boş disk alanı yok."
  [CACHE_CLEAN]="Paket önbelleği temizleniyor."
  [CHECK_UPDATES]="Güncellemeleri Kontrol Et"
  [UPDATES_PROMPT]="Güncellemeler"
  [UPDATES_TITLE]="Kullanılabilir güncellemeler: {COUNT}"
  [UPDATES_SOURCE_TAG]="(kaynak)"
)

declare -A i18n_POWER_MENU=(
  [ITEM_SHUTDOWN]="Kapat"
  [ITEM_REBOOT]="Yeniden Başlat"
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
  [REMOVE_CONFIRM]="{PACKAGE} Yazılımını kaldırmak istiyor musunuz?"
  [ACTION_REMOVE]="Kaldır"
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
  [LABEL_CONNECTED]="bağlı"
  [REMOVE_CONFIRM]="{PACKAGE} Yazılımını kaldırmak istiyor musunuz?"
  [ACTION_REMOVE]="Kaldır"
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
