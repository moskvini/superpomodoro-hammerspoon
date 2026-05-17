# Hammerspoon Flow Autostart

Небольшой Hammerspoon-конфиг, который автоматически запускает Flow-сессию после wake/unlock Mac и после возвращения к ноутбуку после idle.

При этом Flow не стартует, если вы в Zoom, смотрите видео в медиаплеере или держите браузер в fullscreen.

## Что нужно поставить

1. macOS.
2. [Hammerspoon](https://www.hammerspoon.org/).
3. Flow.app с AppleScript API и bundle id `design.yugen.Flow`.

Hammerspoon можно поставить через Homebrew:

```bash
brew install --cask hammerspoon
```

Flow нужно установить отдельно. После установки можно проверить, что AppleScript API доступен:

```bash
osascript -e 'tell application "Flow" to getPhase'
osascript -e 'tell application "Flow" to getTime'
```

## Установка

```bash
git clone https://github.com/moskvini/hammerspoon-flow-autostart.git
cd hammerspoon-flow-autostart
./install.sh
```

Скрипт создаст `~/.hammerspoon`, сделает backup существующего `~/.hammerspoon/init.lua`, если он уже был, и скопирует новый конфиг.

После этого откройте Hammerspoon и выдайте разрешения, если macOS спросит:

- Accessibility: `System Settings -> Privacy & Security -> Accessibility -> Hammerspoon`
- Automation: разрешить Hammerspoon управлять Flow
- Notifications: чтобы видеть уведомление о старте Flow

## Что делает конфиг

Автостарт Flow происходит:

- после wake/unlock Mac;
- когда пользователь вернулся после idle, по умолчанию после 5 минут без клавиатуры/мыши.

Flow не стартует, если:

- активен Zoom;
- есть окно Zoom Meeting/Webinar/Sharing;
- активен VLC, IINA, QuickTime, TV, Plex, Infuse или Kodi;
- активен браузер в fullscreen.

Flow запускается через AppleScript. Если текущая фаза не `Flow`, конфиг сначала делает `skip`, затем `start`.

## Настройки

Основные значения находятся в начале `init.lua`:

```lua
idleThreshold = 5 * 60
backThreshold = 5
cooldown = 20
checkInterval = 5
startDelay = 2
```

## Проверка

Проверить, что Hammerspoon видит конфиг:

```bash
hs -n -t 4 -c 'return "pong"'
```

Проверить текущий статус:

```bash
hs -n -t 4 -c 'return hs.inspect(flowAutoStart.status())'
```

Прогнать встроенные тесты блокировок:

```bash
hs -n -t 4 -c 'return hs.inspect(flowAutoStart.selfTest())'
```

Вручную запустить тот же путь, который вызывается после wake/idle:

```bash
hs -n -t 4 -c 'return flowAutoStart.requestFlowStart("manual test")'
```

## Важно

Если у вас уже есть свой `~/.hammerspoon/init.lua`, не копируйте файл вслепую: лучше перенесите нужные части конфига вручную или сохраните backup.

`install.sh` делает backup автоматически, но он всё равно заменяет текущий `init.lua`.
