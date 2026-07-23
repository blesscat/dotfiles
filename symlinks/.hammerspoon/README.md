# Hammerspoon 設定

這個目錄由 dotfiles repository 管理，`bootstrap.json` 會將它連結到
`~/.hammerspoon`。macOS bootstrap 會透過 repository 根目錄的 `Brewfile`
安裝 Hammerspoon app；`./symlinks.sh` 則負責套用這個設定連結。

## 檔案用途

| 檔案 | 用途 |
| --- | --- |
| `init.lua` | Hammerspoon 入口。啟用開機自動啟動，並載入一般輸入法與 Yazelix/Helix 輸入法模組。 |
| `input_source.lua` | 一般輸入法控制。快捷鍵按下 Command、Control 或 Option 時暫時使用 ABC，放開後恢復原本輸入法；也提供其他模組切換與保存輸入法的共用函式。 |
| `helix_input_source.lua` | Yazelix/Helix 輸入法狀態機。辨認目前的 macOS 視窗、Ghostty active tab、Zellij session、focused pane 與 Helix mode，並為每個 session 分別記住 insert mode 使用的輸入法。 |
| `yazelix_input_source_context.py` | 唯讀狀態 helper。讀取 Yazelix Helix bridge 的真實 mode；使用 Ghostty tab 標題快速辨認 session 與 insert mode，並在強制 ABC 前以 Zellij focused pane 排除上層 popup/panel。 |

## 輸入法規則

- Helix normal/select mode：使用 ABC。
- Helix insert mode：恢復該 Yazelix session 上次在 insert mode 使用的輸入法。
- 離開 insert mode：先保存當下輸入法，再切換到 ABC。
- Yazelix sidebar：使用 ABC。
- Agent、popup 與其他 pane：不強制切換輸入法。
- 即使底層是 editor/sidebar，只要上層 popup 或 floating panel 取得焦點，就視為其他 pane。
- 每個 Ghostty 視窗、tab 與 Yazelix session 分開辨認，不共用 insert mode 記憶。

## 狀態資料流

1. `helix_input_source.lua` 從 Ghostty Accessibility tree 取得 active window 與 active tab。
2. `yazelix_input_source_context.py` 以 tab 中的 Zellij session 名稱找到對應的 Helix bridge。
3. Helper 在可能強制 ABC 時再核對 Zellij focused pane，避免把覆蓋在 editor/sidebar 上的 panel 判錯。
4. Helper 回傳 focused pane 與 Helix 的 `normal`、`select` 或 `insert` mode。
5. `helix_input_source.lua` 依規則呼叫 `input_source.lua` 切換或恢復輸入法。

所有 runtime token 與 Unix socket 都從 Yazelix 的 runtime registry 動態讀取，不會存進
dotfiles。
