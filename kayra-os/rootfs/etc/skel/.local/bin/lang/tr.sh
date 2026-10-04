#!/bin/bash

declare -A i18n=(
  [WELCOME]="Hoşgeldiniz"
  [NOT_INSTALLED]="{BIN} kurulu değil"
  [OPERATION_CANCELLED]="İşlem iptal edildi"
  [SUCCESS]="Başarı"
  [ERROR]="Hata"
  [FAILED]="Başarısız"
)

declare -A user_menu=(
  ["Şifreyi değiştir"]="change-passwd.sh"
  ["Gruba ekle"]="group-add.sh --anchor=top-right"
  ["Gruptan çıkar"]="group-remove.sh --anchor=top-right"
  ["Ev Dizini Kullanımı"]="home-usage.sh"
)

declare -A settings_menu=(
  ["Görünüm ve Tema"]="appearance-settings.sh"
  ["Dil"]="language-settings.sh"
  ["Klavye"]="keyboard-settings.sh"
  ["Ekran"]="display-settings.sh"
)

declare -A appearance_menu=(
  ["Yazı Tipi"]="font-settings.sh"
  ["Yazı Tipi Büyüklüğü"]="font-size-settings.sh"
)

declare -A i18n_HOME_USAGE=(
  [NOTIFY_TITLE]="Ev dizini boyutu"
  [NOTIFY_MSG]="{HOME} Dizini {USAGE} yer kaplıyor."
  [NOTIFY_BUTTON]="Baobab'ı Aç"
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
)

declare -A i18n_WIFI_MENU=(
  [NOTIFY_DEVICE_NOT_FOUND]="Wifi aygıtı bulunamadı"
  [NOTIFY_NO_NETWORKS]="Yakında ağ bulunamadı"
  [PROMPT_SELECT]="Wifi ağı seç"
  [PROMPT_PASSWORD]="Şifre: {SSID}"
  [PROMPT_LABEL]="wifi> "
  [PROMPT_PASSWORD_LABEL]="şifre> "
  [MSG_DISCONNECTED]="Bağlantı kesildi"
  [MSG_DISCONNECT_FAILED]="Bağlantı kesilemedi"
  [MSG_CONNECTED]="Bağlandı"
  [MSG_CONNECT_FAILED]="Bağlantı başarısız (şifre yanlış olabilir)"
)

declare -A i18n_USER_INFO=(
  [LABEL_GROUPS]="Gruplar:"
  [LABEL_SUPERVISOR]="Yönetici"
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
)

declare -A i18n_USER_MENU=(
  [PROMPT_SEARCH]="Ara: "
  [MSG_NO_ITEMS]="Öğe bulunamadı"
  [USAGE_ERROR]="Kullanım: {SCRIPT} <json-dosya> [fuzzel parametreleri...]"
  [FILE_NOT_FOUND]="Hata: Dosya bulunamadı -> {FILE}"
  [PROMPT_ACTION]="Eylem: "
)

declare -A i18n_CONNECTION_CHECK=(
  [MSG_ONLINE]="Çevrimiçi"
  [MSG_OFFLINE]="Çevrimdışı"
  [MSG_CHECKING]="Bağlantı kontrol ediliyor..."
  [TOOLTIP_NO_WIFI_NO_INTERNET]="Wi-Fi aygıtı bulunamadı ve internet bağlantısı yok (connectivity: {CONNECTIVITY})\nTıkla: Ağ Yöneticisini aç"
)

declare -A i18n_SYSLOG_NOTIFY=(
  [TITLE_MULTIPLE]="Log kayıtları ({COUNT} kayıt)"
  [TITLE_SINGLE]="Yeni log kaydı"
  [BUTTON_OPEN_LOG]="Log Dosyasını Aç"
  [NOTIFY_APP]="syslog"
)

declare -A i18n_SYSLOG_BOOT_REPORT=(
  [TITLE_MULTIPLE]="Açılıştan Bu Yana Hatalar ({COUNT} kayıt)"
  [TITLE_SINGLE]="Açılıştan Bu Yana Hata"
  [BUTTON_OPEN_LOG]="Log Dosyasını Aç"
  [NOTIFY_APP]="syslog"
)

declare -A i18n_NET_MONITOR=(
  [USAGE_ERROR]="Kullanım: {SCRIPT} --ethernet <desen1,desen2,...> --other <desen1,desen2,...>"
  [UNKNOWN_PARAMETER]="Bilinmeyen parametre: {PARAM}"
  [LABEL_ETHERNET]="Ethernet:"
  [LABEL_OTHER]="Diğer:"
)

declare -A i18n_WIFI_MONITOR=(
  [DEVICE_DISCONNECTED]=$'Aygıt: {DEVICE}\nDurum: Bağlı değil'
  [DEVICE_CONNECTED]=$'Aygıt: {DEVICE}\nSSID: {SSID}\nIP: {IP}\nSinyal: %{SIGNAL}'
)

declare -A i18n_CHECK_GROUPS=(
  [NOTIFY_TITLE]="Grup Kontrolü"
  [NOTIFY_MSG]="Grup üyeliği eksik"
  [NOTIFY_ACTION]="Grup ekle"
  [MISSING_GROUPS]="Üye olmadığınız gruplar: {GROUPS}"
)

declare -A i18n_FIX_GROUPS=(
  [NOTIFY_TITLE]="Grup Kontrolü"
  [TITLE_SUCCESS]="Gruplar eklendi"
  [MSG_SUCCESS]="Değişikliklerin etkili olması için çıkış yapıp tekrar giriş yapın."
  [TITLE_FAILED]="İşlem iptal edildi veya başarısız oldu"
)

declare -A i18n_SYSTEM_INFO=(
  [LABEL_SYSTEM]="Sistem"
  [LABEL_KERNEL]="Çekirdek"
  [LABEL_CPU]="İşlemci"
  [LABEL_GPU]="Grafik Kartı"
  [LABEL_RAM]="RAM"
  [LABEL_DISK]="Disk"
)

declare -A i18n_SETTINGS_MENU=(
  [PROMPT_ACTION]="Eylem: "
  [MSG_NO_ITEMS]="Öğe bulunamadı"
)

declare -A i18n_FONT_SETTINGS=(
  [PROMPT_SELECT]="Yazı tipi seç: "
  [NOTIFY_TITLE]="Yazı Tipi Ayarları"
  [MSG_FONT_CHANGED]="Yazı tipi {FONT} olarak değiştirildi"
  [MSG_FONT_UNCHANGED]="Yazı tipi {FONT} zaten seçili"
  [MSG_FONT_FAILED]="Yazı tipi {FONT} olarak değiştirilemedi"
)

declare -A i18n_CHANGE_FONT_SIZE=(
  [USAGE_ERROR]="Kullanım: {SCRIPT} <boyut>"
  [ERROR_INVALID_SIZE]="Hata: Font büyüklüğü {MIN} ile {MAX} arasında olmalı"
  [ERROR_SETTINGS_NOT_FOUND]="Hata: Ayarlar dosyası bulunamadı: {FILE}"
  [MSG_SUCCESS]="Başarılı"
)

declare -A i18n_LANGUAGE_SETTINGS=(
  [PROMPT_SELECT]="Seç: "
  [NOTIFY_TITLE]="Dil"
  [MSG_CHANGED]="Değiştirildi: {LANG}"
  [MSG_FAILED]="Dil değiştirilemedi: {LANG}"
)

declare -A i18n_KEYBOARD_SETTINGS=(
  [PROMPT_SELECT]="Klavye düzeni seç: "
  [NOTIFY_TITLE]="Klavye Düzeni"
  [MSG_CHANGED]="Düzen: {LAYOUT}"
  [MSG_VARIANT]="Varyant: {VARIANT}"
  [MSG_FAILED]="Klavye düzeni değiştirilemedi"
  [MSG_UNCHANGED]="Klavye düzeni zaten ayarlanmış"
  [ERROR_DATA_NOT_FOUND]="Klavye veri dosyaları bulunamadı. Lütfen generate-keyboard-data.sh betiğini çalıştırın"
  [ERROR_SELECTION_NOT_FOUND]="Seçim klavye veritabanında bulunamadı"
  [ERROR_CONFIG_NOT_FOUND]="Klavye yapılandırma dosyası bulunamadı"
)

declare -A i18n_REMOVABLE_STORAGE_MONITOR=(
  [NOTIFY_TITLE]="Yeni depolama birimi"
  [NOTIFY_ACTION_OPEN]="Aç"
  [NOTIFY_ACTION_MOUNT]="Bağla"
  [NOTIFY_ACTION_DEFAULT]="Aç"
  [TOOLTIP_EMPTY]="Çıkarılabilir depolama aygıtı yok"
  [TOOLTIP_ITEM_FORMAT]="{type}  {label}  {fstype}  {size}  {mountpoints}"
)
