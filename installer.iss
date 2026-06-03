[Setup]
; Название вашего приложения
AppName=GCR APP
; Версия приложения
AppVersion=1.0.0
; Издатель
AppPublisher=arni30rus
; Папка установки по умолчанию
DefaultDirName={autopf}\GCR APP
; Название группы в меню Пуск
DefaultGroupName=GCR APP
; Имя итогового файла установщика
OutputBaseFilename=GCR_APP_1.0.0_Setup
; Папка, куда сохранится готовый установщик (создастся в папке проекта)
OutputDir=InstallerOutput
; Сжатие (lzma2/ultra64 дает минимальный размер файла)
Compression=lzma2/ultra64
SolidCompression=yes
; Указываем, что программа 64-битная
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Иконка установщика (укажите путь к вашей иконке .ico)
SetupIconFile=assets\logo.ico
; Запрос прав администратора (иногда нужно для записи в Program Files)
PrivilegesRequired=admin

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
; Предложим создать ярлык на рабочем столе
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные значки:"

[Files]
; БЕРЕМ ВСЕ ФАЙЛЫ ИЗ ПАПКИ RELEASE (включая подпапки, особенно папку data)
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Ярлык в меню Пуск
Name: "{group}\GCR APP"; Filename: "{app}\gcr_app.exe"
; Ярлык на рабочем столе (если пользователь поставил галочку)
Name: "{autodesktop}\GCR APP"; Filename: "{app}\gcr_app.exe"

[Run]
; Предложим запустить программу сразу после установки
Filename: "{app}\gcr_app.exe"; Description: "Запустить GCR APP"; Flags: nowait postinstall skipifsilent