-- Flow auto-start for macOS via Hammerspoon

require("hs.ipc")
hs.menuIcon(true)
hs.autoLaunch(true)

local FlowAutoStart = {
  config = {
    idleThreshold = 5 * 60, -- считать "отошёл" после 5 минут без клавиатуры/мыши
    backThreshold = 5,     -- idle < 5 sec = вернулся к ноуту
    cooldown = 20,         -- не дергать Flow чаще раза в 20 секунд
    checkInterval = 5,
    startDelay = 2,
  },

  state = {
    lastStartCommandAt = 0,
    lastStartAt = nil,
    lastStartError = nil,
    lastStartReason = nil,
    lastStartResult = nil,
    pendingReason = nil,
    startScheduled = false,
    wasAway = false,
  },

  mediaBundleIDs = {
    ["com.apple.QuickTimePlayerX"] = true,
    ["com.apple.TV"] = true,
    ["org.videolan.vlc"] = true,
    ["com.colliderli.iina"] = true,
    ["com.plexapp.plex"] = true,
    ["com.plexapp.plexmediaplayer"] = true,
    ["tv.plex.desktop"] = true,
    ["com.firecore.infuse"] = true,
    ["org.xbmc.kodi"] = true,
  },

  mediaAppNames = {
    ["QuickTime Player"] = true,
    ["TV"] = true,
    ["VLC"] = true,
    ["IINA"] = true,
    ["Plex"] = true,
    ["Infuse"] = true,
    ["Kodi"] = true,
  },

  browserBundleIDs = {
    ["com.google.Chrome"] = true,
    ["com.apple.Safari"] = true,
    ["org.mozilla.firefox"] = true,
    ["com.brave.Browser"] = true,
    ["com.microsoft.edgemac"] = true,
    ["com.operasoftware.Opera"] = true,
  },

  zoomWindowTitleNeedles = {
    "zoom meeting",
    "meeting",
    "webinar",
    "sharing",
    "screen sharing",
  },
}

flowAutoStart = FlowAutoStart

local function now()
  return hs.timer.secondsSinceEpoch()
end

local function safeCall(fn, fallback)
  local ok, result = pcall(fn)
  if ok then return result end
  return fallback
end

local function tableHas(set, value)
  return value ~= nil and set[value] == true
end

local function eventEquals(event, constant)
  return constant ~= nil and event == constant
end

function FlowAutoStart.frontContext()
  local app = hs.application.frontmostApplication()
  local win = hs.window.frontmostWindow()

  return {
    appName = app and app:name() or nil,
    bundleID = app and app:bundleID() or nil,
    fullscreen = win ~= nil and safeCall(function() return win:isFullScreen() end, false) or false,
  }
end

function FlowAutoStart.hasZoomMeetingWindow()
  local zoomApps = hs.application.applicationsForBundleID("us.zoom.xos") or {}

  for _, app in ipairs(zoomApps) do
    local windows = safeCall(function() return app:allWindows() end, {}) or {}

    for _, win in ipairs(windows) do
      local title = string.lower(safeCall(function() return win:title() end, "") or "")

      for _, needle in ipairs(FlowAutoStart.zoomWindowTitleNeedles) do
        if title:find(needle, 1, true) then
          return true, title
        end
      end
    end
  end

  return false, nil
end

function FlowAutoStart.isBlockedContext(bundleID, appName, fullscreen, zoomMeetingActive)
  if bundleID == "us.zoom.xos" or appName == "zoom.us" or appName == "Zoom" then
    return true, "zoom-active"
  end

  if zoomMeetingActive then
    return true, "zoom-meeting-window"
  end

  if tableHas(FlowAutoStart.mediaBundleIDs, bundleID) or tableHas(FlowAutoStart.mediaAppNames, appName) then
    return true, "media-player"
  end

  if tableHas(FlowAutoStart.browserBundleIDs, bundleID) and fullscreen then
    return true, "fullscreen-browser"
  end

  return false, nil
end

function FlowAutoStart.shouldBlockAutoStart()
  local context = FlowAutoStart.frontContext()
  local zoomMeetingActive, zoomWindowTitle = FlowAutoStart.hasZoomMeetingWindow()
  local blocked, reason = FlowAutoStart.isBlockedContext(
    context.bundleID,
    context.appName,
    context.fullscreen,
    zoomMeetingActive
  )

  context.zoomMeetingActive = zoomMeetingActive
  context.zoomWindowTitle = zoomWindowTitle

  return blocked, reason, context
end

function FlowAutoStart.flowCommand(command)
  return hs.osascript.applescript('tell application "Flow" to ' .. command)
end

function FlowAutoStart.runFlowStartScript()
  return hs.osascript.applescript([[
    tell application "Flow"
      set currentPhase to getPhase
      if currentPhase is not "Flow" then skip
      start
    end tell
  ]])
end

function FlowAutoStart.recordStart(reason, result, err)
  FlowAutoStart.state.lastStartAt = now()
  FlowAutoStart.state.lastStartReason = reason
  FlowAutoStart.state.lastStartResult = result
  FlowAutoStart.state.lastStartError = err
end

function FlowAutoStart.notify(title, text)
  hs.notify.new({
    title = title,
    informativeText = text,
  }):send()
end

function FlowAutoStart.startFlow(reason)
  reason = reason or "manual"

  if FlowAutoStart.state.startScheduled then
    FlowAutoStart.recordStart(reason, nil, "already-scheduled")
    return false, "already-scheduled"
  end

  if now() - FlowAutoStart.state.lastStartCommandAt < FlowAutoStart.config.cooldown then
    FlowAutoStart.recordStart(reason, nil, "cooldown")
    return false, "cooldown"
  end

  FlowAutoStart.state.startScheduled = true
  FlowAutoStart.state.pendingReason = nil

  hs.timer.doAfter(FlowAutoStart.config.startDelay, function()
    FlowAutoStart.state.startScheduled = false

    local blocked, blockReason = FlowAutoStart.shouldBlockAutoStart()
    if blocked then
      FlowAutoStart.state.pendingReason = reason
      FlowAutoStart.recordStart(reason, nil, "blocked-before-start:" .. tostring(blockReason))
      return
    end

    FlowAutoStart.state.lastStartCommandAt = now()

    local ok, result = FlowAutoStart.runFlowStartScript()
    if not ok then
      FlowAutoStart.recordStart(reason, nil, tostring(result))
      FlowAutoStart.notify("Flow", "Start failed: " .. tostring(result))
      return
    end

    FlowAutoStart.recordStart(reason, tostring(result), nil)
    FlowAutoStart.notify("Flow", "Started " .. tostring(result) .. ": " .. reason)
  end)

  return true, "scheduled"
end

function FlowAutoStart.requestFlowStart(reason)
  reason = reason or "manual"

  local blocked, blockReason = FlowAutoStart.shouldBlockAutoStart()
  if blocked then
    FlowAutoStart.state.pendingReason = reason
    FlowAutoStart.recordStart(reason, nil, "blocked:" .. tostring(blockReason))
    return false, blockReason
  end

  return FlowAutoStart.startFlow(reason)
end

function FlowAutoStart.handleWakeEvent(event)
  if eventEquals(event, hs.caffeinate.watcher.systemDidWake)
    or eventEquals(event, hs.caffeinate.watcher.screensDidWake)
    or eventEquals(event, hs.caffeinate.watcher.screensDidUnlock)
    or eventEquals(event, hs.caffeinate.watcher.sessionDidBecomeActive) then
      FlowAutoStart.requestFlowStart("wake/unlock")
  end
end

function FlowAutoStart.handleIdleTick()
  local idle = hs.host.idleTime()

  if idle > FlowAutoStart.config.idleThreshold then
    FlowAutoStart.state.wasAway = true
  end

  if FlowAutoStart.state.wasAway and idle < FlowAutoStart.config.backThreshold then
    FlowAutoStart.state.wasAway = false
    FlowAutoStart.requestFlowStart("back from idle")
  end

  if FlowAutoStart.state.pendingReason ~= nil and idle < FlowAutoStart.config.backThreshold then
    local reason = FlowAutoStart.state.pendingReason

    local blocked, blockReason = FlowAutoStart.shouldBlockAutoStart()
    if blocked then
      FlowAutoStart.recordStart(reason, nil, "blocked:" .. tostring(blockReason))
      return
    end

    local accepted = FlowAutoStart.startFlow("pending: " .. reason)
    if accepted then
      FlowAutoStart.state.pendingReason = nil
    end
  end
end

function FlowAutoStart.status()
  local blocked, blockReason, context = FlowAutoStart.shouldBlockAutoStart()
  local phaseOK, phase = FlowAutoStart.flowCommand("getPhase")
  local timeOK, remainingTime = FlowAutoStart.flowCommand("getTime")

  return {
    blocked = blocked,
    blockReason = blockReason,
    context = context,
    flowAppleScriptOK = phaseOK and timeOK,
    flowPhase = phase,
    flowTime = remainingTime,
    idle = hs.host.idleTime(),
    idleTimerRunning = FlowAutoStart.idleTimer ~= nil and FlowAutoStart.idleTimer:running(),
    menuIcon = hs.menuIcon(),
    powerWatcherPresent = FlowAutoStart.powerWatcher ~= nil,
    state = FlowAutoStart.state,
  }
end

function FlowAutoStart.selfTest()
  local cases = {
    { "normal app", "com.openai.codex", "Codex", false, false, false },
    { "active Zoom", "us.zoom.xos", "zoom.us", false, false, true },
    { "Zoom meeting window", "com.openai.codex", "Codex", false, true, true },
    { "VLC bundle", "org.videolan.vlc", "VLC", false, false, true },
    { "IINA bundle", "com.colliderli.iina", "IINA", false, false, true },
    { "QuickTime name", "", "QuickTime Player", false, false, true },
    { "Plex name", "", "Plex", false, false, true },
    { "Chrome normal", "com.google.Chrome", "Google Chrome", false, false, false },
    { "Chrome fullscreen", "com.google.Chrome", "Google Chrome", true, false, true },
    { "Safari fullscreen", "com.apple.Safari", "Safari", true, false, true },
  }

  local failures = {}
  for _, test in ipairs(cases) do
    local blocked = FlowAutoStart.isBlockedContext(test[2], test[3], test[4], test[5])
    if blocked ~= test[6] then
      table.insert(failures, {
        name = test[1],
        expected = test[6],
        got = blocked,
      })
    end
  end

  return {
    cases = #cases,
    failures = failures,
    ok = #failures == 0,
  }
end

FlowAutoStart.powerWatcher = hs.caffeinate.watcher.new(function(event)
  FlowAutoStart.handleWakeEvent(event)
end)
FlowAutoStart.powerWatcher:start()

FlowAutoStart.idleTimer = hs.timer.doEvery(FlowAutoStart.config.checkInterval, function()
  FlowAutoStart.handleIdleTick()
end)
