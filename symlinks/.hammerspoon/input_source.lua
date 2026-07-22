-- Temporarily use the ABC input source for keyboard shortcuts.
-- The original input source is restored after Command, Control, and Option
-- are all released.

local inputSource = {}

local englishSource = "com.apple.keylayout.ABC"
local previousSource = nil
local shortcutInputSourceTap = nil

local function hasShortcutModifier(flags)
  return flags.cmd or flags.ctrl or flags.alt
end

local function switchToEnglishSource()
  if hs.keycodes.currentSourceID() == englishSource then
    return true
  end

  if hs.keycodes.currentSourceID(englishSource) then
    return true
  end

  hs.alert.show("無法切換至 ABC 輸入方式")
  return false
end

local function isEnglishLetterKey(event)
  local keyName = hs.keycodes.map[event:getKeyCode()]

  return type(keyName) == "string" and keyName:match("^[a-z]$") ~= nil
end

local function isShiftOnlyEnglishLetter(event, flags)
  return flags.shift
    and not flags.cmd
    and not flags.ctrl
    and not flags.alt
    and isEnglishLetterKey(event)
end

local function handleInputSourceEvent(event)
  local eventType = event:getType()
  local flags = event:getFlags()

  if eventType == hs.eventtap.event.types.keyDown then
    if isShiftOnlyEnglishLetter(event, flags) then
      local currentSource = hs.keycodes.currentSourceID()

      if currentSource ~= englishSource then
        local keyName = hs.keycodes.map[event:getKeyCode()]
        event:setUnicodeString(keyName)
      end
    elseif hasShortcutModifier(flags) and previousSource == nil then
      local currentSource = hs.keycodes.currentSourceID()

      if currentSource ~= englishSource then
        previousSource = currentSource

        if not switchToEnglishSource() then
          previousSource = nil
        end
      end
    end
  elseif previousSource ~= nil and not hasShortcutModifier(flags) then
    local sourceToRestore = previousSource
    previousSource = nil

    if not hs.keycodes.currentSourceID(sourceToRestore) then
      hs.alert.show("無法恢復原本的輸入方式")
    end
  end

  return false
end

function inputSource.start()
  if shortcutInputSourceTap ~= nil then
    shortcutInputSourceTap:stop()
  end

  shortcutInputSourceTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.flagsChanged,
  }, function(event)
    return handleInputSourceEvent(event)
  end):start()
end

function inputSource.keepEnglish()
  -- A persistent rule takes priority over a temporary shortcut restore.
  previousSource = nil
  return switchToEnglishSource()
end

function inputSource.use(sourceID)
  previousSource = nil

  if hs.keycodes.currentSourceID() == sourceID then
    return true
  end

  if sourceID ~= nil and hs.keycodes.currentSourceID(sourceID) then
    return true
  end

  hs.alert.show("無法恢復先前的輸入方式")
  return false
end

function inputSource.sourceToPreserve()
  return previousSource or hs.keycodes.currentSourceID()
end

return inputSource
