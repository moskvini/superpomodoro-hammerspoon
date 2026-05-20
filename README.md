# Superpomodoro Hammerspoon

## Зачем это сделано

Помодоро хорошо работает только тогда, когда оно реально стартует. Проблема простая: открыл ноутбук, отвлекся, вернулся после паузы, забыл нажать Start — и вся система фокуса снова держится на силе воли.

Этот проект делает помодоро чуть более автоматическим: Mac проснулся или вы вернулись после idle — Flow сам запускает рабочий интервал. При этом конфиг старается не мешать, если вы в Zoom, смотрите видео или держите браузер в fullscreen.

Вся связка собирается на бесплатном софте и настраивается примерно за 10 минут с нуля: Hammerspoon бесплатный, базовой версии Flow достаточно, платные автоматизаторы не нужны.

## Что это

Небольшой Hammerspoon-конфиг, который автоматически запускает Flow-сессию после wake/unlock Mac и после возвращения к ноутбуку после idle.

## Что нужно поставить

1. macOS.
2. [Hammerspoon](https://www.hammerspoon.org/).
3. [Flow: Pomodoro & Study Timer](https://apps.apple.com/app/flow-pomodoro-study-timer/id1423210932) с AppleScript API и bundle id `design.yugen.Flow`.

Hammerspoon можно поставить через Homebrew:

```bash
brew install --cask hammerspoon
```

Flow нужно установить отдельно. Базовая версия бесплатная; Pro/In-App Purchases для этого конфига не обязательны. После установки можно проверить, что AppleScript API доступен:

```bash
osascript -e 'tell application "Flow" to getPhase'
osascript -e 'tell application "Flow" to getTime'
```

## Установка

```bash
git clone https://github.com/moskvini/superpomodoro-hammerspoon.git
cd superpomodoro-hammerspoon
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

Во время фазы `Break`/`Перерыв` конфиг следит за таймером Flow и, когда на break-таймере остается 3 минуты, переводит macOS на экран входа через `hs.caffeinate.fastUserSwitch()`. Это не эмуляция нажатия клавиш, а системный Hammerspoon API. Так перерыв не превращается в “еще пять минут за ноутбуком”.

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
breakLockEnabled = true
breakLockAtMinute = 3
```

`breakLockAtMinute = 3` означает “когда на break-таймере Flow остается 3 минуты”. Блокировка срабатывает один раз за break-фазу, когда таймер пересекает этот порог сверху вниз.

## Проверка

Быстро прогнать все безопасные проверки:

```bash
./scripts/verify.sh
```

Проверить вместе с реальной блокировкой экрана:

```bash
./scripts/verify.sh --lock
```

`--lock` реально переведет macOS на экран входа через `hs.caffeinate.fastUserSwitch()`.

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

Проверить, распознает ли конфиг break-фазу:

```bash
hs -n -t 4 -c 'return flowAutoStart.isBreakPhase("Break"), flowAutoStart.isBreakPhase("Перерыв")'
```

Осторожно: ручной вызов `flowAutoStart.enterBreakLockMode("manual test")` реально переведет macOS на экран входа.

## Важно

Если у вас уже есть свой `~/.hammerspoon/init.lua`, не копируйте файл вслепую: лучше перенесите нужные части конфига вручную или сохраните backup.

`install.sh` делает backup автоматически, но он всё равно заменяет текущий `init.lua`.
