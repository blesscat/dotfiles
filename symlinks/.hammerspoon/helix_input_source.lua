-- Keep ABC active in the Yazelix sidebar and in Helix normal/select mode.
-- Each Helix session remembers and restores the input source last used in
-- insert mode.

local helixInputSource = {}

local yazelixTerminalBundleIDs = {
  ["com.mitchellh.ghostty"] = true,
  ["com.raphaelamorim.rio"] = true,
}

local queryTask = nil
local pollTimer = nil
local refreshTimer = nil
local inputEventTap = nil
local applicationWatcher = nil
local refreshPending = false
local stateRevision = 0
local suppressInsert = nil
local pendingInsertRestore = nil
local windowSessions = {}
local sessionStates = {}
local activeContext = nil
local keepEnglish = nil
local useInputSource = nil
local sourceToPreserve = nil

local function stateForSession(sessionID)
  sessionStates[sessionID] = sessionStates[sessionID] or {}
  return sessionStates[sessionID]
end

local function rememberActiveInsertSource()
  if activeContext == nil
    or activeContext.focus ~= "editor"
    or activeContext.mode ~= "insert" then
    return
  end

  local source = sourceToPreserve()
  stateForSession(activeContext.sessionID).insertSource = source
end

local function deactivateActiveContext()
  rememberActiveInsertSource()
  activeContext = nil
  pendingInsertRestore = nil
end

local function applyState(state)
  if suppressInsert ~= nil and suppressInsert.sessionID == state.session_id then
    local suppressesStaleInsert = state.focus == "editor"
      and state.mode == "insert"
      and hs.timer.secondsSinceEpoch() < suppressInsert.untilTime

    if suppressesStaleInsert then
      return
    end

    suppressInsert = nil
  end

  if pendingInsertRestore ~= nil
    and hs.timer.secondsSinceEpoch() >= pendingInsertRestore.untilTime then
    pendingInsertRestore = nil
  end

  local previousContext = activeContext
  local continuesSameInsert = previousContext ~= nil
    and previousContext.sessionID == state.session_id
    and previousContext.focus == "editor"
    and previousContext.mode == "insert"
    and state.focus == "editor"
    and state.mode == "insert"

  if not continuesSameInsert then
    rememberActiveInsertSource()
  end

  local sessionState = stateForSession(state.session_id)
  activeContext = {
    sessionID = state.session_id,
    focus = state.focus,
    mode = state.mode,
  }

  if state.focus == "editor" and state.mode == "insert" then
    if sessionState.insertSource == nil then
      sessionState.insertSource = sourceToPreserve()
    else
      local returnsToInsertContext = previousContext == nil
        or previousContext.sessionID ~= state.session_id
        or previousContext.focus ~= "editor"
      local confirmedInsertCommand = pendingInsertRestore ~= nil
        and pendingInsertRestore.sessionID == state.session_id
      local shouldRestore = not continuesSameInsert
        and (returnsToInsertContext or confirmedInsertCommand)

      if shouldRestore then
        useInputSource(sessionState.insertSource)
      end
    end

    if pendingInsertRestore ~= nil
      and pendingInsertRestore.sessionID == state.session_id then
      pendingInsertRestore = nil
    end
  elseif state.focus == "editor"
    and (state.mode == "normal" or state.mode == "select") then
    if sessionState.insertSource == nil then
      sessionState.insertSource = sourceToPreserve()
    end
    keepEnglish()
  elseif state.focus == "sidebar" then
    keepEnglish()
  end
end

local function selectedTabTitle(element, depth)
  if element == nil or depth > 6 then
    return nil
  end

  if element:attributeValue("AXSubrole") == "AXTabButton"
    and element:attributeValue("AXValue") == true then
    return element:attributeValue("AXTitle")
  end

  for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
    local title = selectedTabTitle(child, depth + 1)

    if title ~= nil then
      return title
    end
  end

  return nil
end

local function frontmostYazelixTerminal()
  local application = hs.application.frontmostApplication()

  if application == nil
    or yazelixTerminalBundleIDs[application:bundleID()] ~= true then
    return nil
  end

  local window = application:focusedWindow()

  if window == nil then
    return nil
  end

  local activeTabTitle = selectedTabTitle(
    hs.axuielement.windowElement(window),
    0
  ) or window:title() or ""

  return {
    bundleID = application:bundleID(),
    tabKey = tostring(window:id()) .. ":" .. activeTabTitle,
    activeTabTitle = activeTabTitle,
    title = window:title() or "",
  }
end

local function refresh()
  local terminal = frontmostYazelixTerminal()

  if terminal == nil then
    deactivateActiveContext()
    return
  end

  if queryTask ~= nil then
    refreshPending = true
    return
  end

  local queryScript = hs.configdir .. "/yazelix_input_source_context.py"
  local preferredSession = windowSessions[terminal.tabKey] or ""
  local queryRevision = stateRevision

  queryTask = hs.task.new("/usr/bin/python3", function(exitCode, stdOut)
    queryTask = nil

    local currentTerminal = frontmostYazelixTerminal()

    if queryRevision ~= stateRevision then
      -- A keyboard, mouse, application, or tab change made this result stale.
    elseif currentTerminal == nil or currentTerminal.tabKey ~= terminal.tabKey then
      deactivateActiveContext()
    elseif exitCode == 0 then
      local ok, state = pcall(hs.json.decode, stdOut)

      if ok and type(state) == "table" and state.status == "ok" then
        windowSessions[terminal.tabKey] = state.session_id
        applyState(state)
      else
        deactivateActiveContext()
      end
    else
      deactivateActiveContext()
    end

    if refreshPending then
      refreshPending = false
      refresh()
    end
  end, {
    "-B",
    queryScript,
    terminal.bundleID,
    terminal.title,
    terminal.activeTabTitle,
    preferredSession,
  })

  queryTask:start()
end

local function scheduleRefresh(delay)
  if refreshTimer ~= nil then
    refreshTimer:stop()
  end

  refreshTimer = hs.timer.doAfter(delay or 0.05, refresh)
end

local function handleImmediateInsertExit(event)
  if activeContext == nil or activeContext.focus ~= "editor" then
    return
  end

  local flags = event:getFlags()
  local keyName = hs.keycodes.map[event:getKeyCode()]

  if suppressInsert ~= nil then
    suppressInsert = nil
  end

  local leavesInsert = activeContext.mode == "insert"
    and (keyName == "escape"
      or (keyName == "[" and flags.ctrl and not flags.cmd and not flags.alt))
  local entersInsert = (activeContext.mode == "normal" or activeContext.mode == "select")
    and (keyName == "i" or keyName == "a" or keyName == "o" or keyName == "c")
    and not flags.cmd
    and not flags.ctrl
    and not flags.alt

  if leavesInsert then
    rememberActiveInsertSource()
    suppressInsert = {
      sessionID = activeContext.sessionID,
      untilTime = hs.timer.secondsSinceEpoch() + 1.5,
    }
    pendingInsertRestore = nil
    activeContext.mode = "normal"
    keepEnglish()
  elseif entersInsert then
    pendingInsertRestore = {
      sessionID = activeContext.sessionID,
      untilTime = hs.timer.secondsSinceEpoch() + 2,
    }
  end
end

function helixInputSource.start(options)
  options = options or {}
  keepEnglish = assert(options.keepEnglish, "keepEnglish callback is required")
  useInputSource = assert(options.useInputSource, "useInputSource callback is required")
  sourceToPreserve = assert(options.sourceToPreserve, "sourceToPreserve callback is required")

  if pollTimer ~= nil then
    pollTimer:stop()
  end
  if inputEventTap ~= nil then
    inputEventTap:stop()
  end
  if applicationWatcher ~= nil then
    applicationWatcher:stop()
  end

  pollTimer = hs.timer.doEvery(0.75, refresh)
  inputEventTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
  }, function(event)
    stateRevision = stateRevision + 1

    if event:getType() == hs.eventtap.event.types.keyDown then
      handleImmediateInsertExit(event)
    end
    scheduleRefresh()
    return false
  end):start()
  applicationWatcher = hs.application.watcher.new(function(_, eventType)
    if eventType == hs.application.watcher.activated then
      stateRevision = stateRevision + 1
      suppressInsert = nil
      scheduleRefresh()
    end
  end):start()
  hs.keycodes.inputSourceChanged(function()
    rememberActiveInsertSource()
  end)

  refresh()
end

return helixInputSource
