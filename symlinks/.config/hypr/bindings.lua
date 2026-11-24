-- Keep only your personal keybinding overrides here. Add new bindings with
-- o.bind or replace defaults with o.rebind.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding. o.rebind takes the same arguments as o.bind.
-- This example replaces the default file manager with Flea.
-- o.rebind("SUPER + SHIFT + F", "File manager", { launch = "flea" })

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, { panel = "omarchy.emojis" })

-- Zen: Alt+Shift+H/L switch spaces like Alt+Shift+Left/Right (Zen's own
-- shortcut, set in its customKeys.json; one Zen key holds only one binding).
-- Other windows get Alt+Shift+H/L unchanged. Down/up split as in Omarchy's
-- default/hypr/bindings/clipboard.lua, to avoid stuck synthetic keys.
local function send_key_once(mods, key)
  hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
  hl.timer(function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
  end, { timeout = 50, type = "oneshot" })
end

local function zen_space_key(zen_key, own_key)
  return function()
    local window = hl.get_active_window()
    if ((window and window.class) or ""):lower() == "zen" then
      send_key_once("ALT SHIFT", zen_key)
    else
      send_key_once("ALT SHIFT", own_key)
    end
  end
end

o.bind("ALT + SHIFT + H", "Zen previous space", zen_space_key("LEFT", "H"))
o.bind("ALT + SHIFT + L", "Zen next space", zen_space_key("RIGHT", "L"))
