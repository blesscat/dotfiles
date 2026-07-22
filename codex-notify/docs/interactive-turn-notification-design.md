# Codex macOS 完成與權限等待通知設計

日期：2026-07-14  
狀態：已核准；純 Ghostty 使用原生通知，Zellij 使用帶預設音效的 Terminal Notifier 精準路由

## 目標

Codex 完成工作後，透過 macOS Notification Center 顯示包含本回合完成摘要的通知。直接在 Ghostty terminal 執行時，使用綁定來源 terminal 的 Ghostty 原生 OSC 9 通知；在 Yazelix/Zellij 中執行時，使用 Terminal Notifier 並精準切回產生事件的 Ghostty terminal 與 Zellij pane。同一個完成事件也要繼續交給既有的 `SkyComputerUseClient`。互動式 TUI 等待權限核准時，`PermissionRequest` hook 透過同一個 wrapper 套用相同環境分流。

## 已核准行為

- Codex 送到 top-level `notify` 的完成事件一律處理，不特別判斷或排除 `codex exec`。
- 每個事件只交給 Sky 一次：top-level `notify` 先執行 `SkyComputerUseClient turn-ended`，再由 Sky 的 `--previous-notify` 呼叫 `codex-notify --native-only` 提交原生 macOS 通知。
- wrapper 以環境判斷通知後端：`TERM_PROGRAM=ghostty` 且 `ZELLIJ`、`ZELLIJ_SESSION_NAME`、`ZELLIJ_PANE_ID` 全部缺失時視為純 Ghostty；只要任一 Zellij 標記存在，就不得使用 OSC 9。
- 純 Ghostty 將既有動態本文寫成 `ESC ] 9 ; <message> BEL` 到來源 `/dev/tty`，讓 Ghostty 原生通知保留 terminal 關聯。OSC 寫入成功時不再呼叫 Terminal Notifier；`/dev/tty` 不存在、不可寫或提交失敗時退回 Terminal Notifier 的 `-activate Ghostty`。
- Zellij 仍由 Terminal Notifier 發送。若事件發生時可取得完整路由資料，點擊通知會先切換 Zellij session／pane，再聚焦對應的 Ghostty terminal；資料缺失、失效或路由失敗時退回只啟動 Ghostty。
- 完成通知與權限等待通知都透過 `codex-notify` 選擇後端，因此兩者套用同一套純 Ghostty／Zellij 規則；不為 `codex exec` 增加分流。
- 路由資料在通知建立當下擷取，包含 Ghostty terminal UUID、Zellij session name、pane ID、當下解析到的 Zellij 絕對路徑，以及尋找 Zellij socket 所需的環境值。不得在點擊時依賴互動式 shell、NVM 或一般 `PATH`。
- 路由資料以版本化 JSON 編碼成不含原始 shell 文字的 opaque token；Terminal Notifier 的 `-execute` 只呼叫固定 router 與該 token，不使用 `eval`，也不直接拼接 cwd、session name 或模型輸出。
- TUI 內建終端通知停用，避免 Yazelix/Zellij 攔截 OSC 9／BEL，也避免完成通知重複。
- `PermissionRequest` hook 匹配所有支援的工具權限請求，呼叫獨立 adapter；adapter 將 hook stdin JSON 轉為既有 completion-wrapper payload，再執行 `codex-notify --native-only`。
- 權限通知不送進 Sky，也不輸出 allow/deny decision；hook 無論通知後端是否成功都以 exit 0、空 stdout 結束，不改變原本權限核准流程。
- 權限通知本文優先顯示 `等待權限核准：<command>`；沒有 command 時使用 tool name，payload 無效或 parser 不可用時退回 `等待權限核准`。既有 wrapper 繼續負責空白正規化與 160 字元限制。
- Terminal Notifier 模式的標題固定為 `Codex`，payload 含 `cwd` 時以目錄名稱作為副標題；Ghostty OSC 9 模式只傳遞相同的動態本文，通知來源與 terminal 關聯由 Ghostty 提供。
- 每次呼叫 Terminal Notifier 都傳入 `-sound default`，讓 Zellij、權限等待與 OSC 寫入失敗的 fallback 跟隨 macOS 預設通知音效。純 Ghostty 不額外播放音效，繼續由 Ghostty 與其 macOS 通知設定管理。
- 通知本文使用 Codex payload 的 `last-assistant-message`。先將換行及連續空白合併成單一空格並移除頭尾空白，再限制為最多 160 個 Unicode 字元；超過限制時保留前 159 個字元並加上 `…`。
- `last-assistant-message` 缺失、不是字串、正規化後為空、payload 不是有效 JSON，或 JSON parser 不可用時，通知本文退回 `任務已完成`。
- 本文長度與退回文字分別可由 `CODEX_NOTIFY_MAX_MESSAGE_CHARS` 與 `CODEX_NOTIFY_FALLBACK_MESSAGE` 覆寫，保留後續調整彈性。長度必須是大於等於 2 的十進位整數，否則使用 160；退回文字在空白正規化後若為空，則使用 `任務已完成`。
- `--native-only` 模式不會再次呼叫 Sky，避免同一 completion event 重複進入 Computer Use。直接執行 wrapper 時仍保留「原生通知＋Sky」的相容模式。
- wrapper 最終回傳成功，並把它實際執行之後端錯誤記錄到 `~/.codex/log/codex-notify.log`。
- 使用者目錄中的 Terminal Notifier 副本必須通過 macOS code-sign 驗證；wrapper 等待它完成提交，避免父程序退出時通知子程序被清理。
- wrapper 的執行檔、Ghostty bundle ID、JSON parser 與 log 路徑都可由環境變數覆寫，以保留後續調整彈性。
- 純 Ghostty 的 tty 路徑預設為 `/dev/tty`，測試或特殊環境可由 `CODEX_NOTIFY_TTY` 覆寫。寫入 OSC 前必須移除本文中的 ESC 與 BEL，避免本文結束或注入另一個控制序列。
- 若 macOS Focus 正在運作，Terminal Notifier 與 Ghostty 必須依各自使用情境列在該 Focus 的允許 App 中，否則通知可能只進入通知中心而不顯示即時橫幅。

## 架構

```text
Codex notify event
        |
        v
SkyComputerUseClient turn-ended
        |
        | --previous-notify
        v
~/.local/bin/codex-notify --native-only
        |-- cwd -------------> project subtitle
        |-- last message ----> normalize -> truncate/fallback -> body
        |
        |-- plain Ghostty ----> /dev/tty OSC 9
        |                       sender: Ghostty
        |                       click: originating terminal
        |
        +-- Zellij/other -----> signed terminal-notifier（synchronous submit）
                                title: Codex
                                sender: Terminal Notifier
                                sound: macOS default
                                Zellij: execute route click <token>
                                fallback: activate Ghostty

Codex PermissionRequest hook
        |
        v
~/.local/bin/codex-permission-notify
        |-- hook stdin -------> command/tool fallback -> wrapper payload
        |
        +---------------------> codex-notify --native-only
                                |
                                +-> same environment-based backend selection
```

純 Ghostty 通知來源顯示為 Ghostty，並沿用 Ghostty 在 macOS 通知設定與 Focus 中的權限。`terminal-notifier` 只用於 Zellij 或 OSC 9 提交失敗的 fallback，並使用自己的 bundle ID 作為通知來源；有完整 Zellij 路由時使用 `-execute`，沒有完整路由時才使用 `com.mitchellh.ghostty` 作為 `-activate` click target。不得傳入 `-sender com.mitchellh.ghostty`：macOS 會拒絕讓 legacy Terminal Notifier 冒用已註冊為 modern notification client 的 Ghostty。Homebrew 2.0.0 bottle 的 app bundle signature 無效，因此 wrapper 使用已重新 ad-hoc 簽署並驗證的固定副本 `~/.local/share/codex-notify/terminal-notifier.app`。

通知內容只從 Codex 已提供的 JSON payload 取得，不額外呼叫模型，也不讀取工作階段紀錄。本文只使用 `last-assistant-message`，不混入 `input-messages`。`last-assistant-message` 的處理與 `cwd` 的處理彼此獨立；任何一個欄位無效都不影響另一個欄位或 Sky 後端。Codex 傳給 `SkyComputerUseClient`、以及 Sky 傳給 previous notifier 的 payload 都維持原字串，不以正規化或重建後的 JSON 取代。

## 精準點擊路由

`codex-notification-route build` 只在判斷為 Zellij 且下列條件都成立時產生 `-execute` command：`ZELLIJ_SESSION_NAME` 與數字型 `ZELLIJ_PANE_ID` 存在、可依序從顯式 `CODEX_ROUTE_ZELLIJ_BIN` override、Yazelix Nova 的 `YZX_ZELLIJ` 或當下 `PATH` 解析出可執行的 Zellij 絕對路徑、JSON parser 可用，而且 Ghostty AppleScript API 能依 `${session} |` terminal 標題找到穩定 UUID。若任一條件不成立，`codex-notify` 保留 `-activate com.mitchellh.ghostty` 行為。純 Ghostty 成功提交 OSC 9 時不執行 route build。

opaque token 的版本 1 欄位為：

- `terminal_id`：通知產生來源的 Ghostty terminal UUID。
- `session`：Zellij session name。
- `pane`：Zellij pane ID，編碼前與解碼後都必須驗證為十進位整數。
- `zellij`：事件當下解析到的 Zellij 絕對執行檔路徑。
- `tmpdir` 與 `socket_dir`：只用於重建 Zellij client 尋找既有 session 所需環境；不作為 shell 程式碼。

點擊後的 router 依序執行：

1. 解碼並驗證 token 版本、欄位型別、pane 格式與 Zellij 執行檔。
2. 以擷取到的 socket 環境執行 `zellij --session <session> action focus-pane-id <pane>`。
3. 透過 Ghostty AppleScript API 先依穩定 UUID 聚焦 terminal；UUID 已失效時，可再依唯一的 `${session} |` 前綴尋找目前 terminal。
4. 若 token 無效、Zellij session／pane 已關閉、Ghostty terminal 已關閉，或任一步驟失敗，記錄錯誤並以 `open -b com.mitchellh.ghostty` 作為非阻斷退路。

router 無論成功或失敗都以 exit 0 結束，避免點擊時顯示額外 shell 錯誤。Zellij 0.44.3 對已經聚焦的目標 pane 會回傳 exit 2；只有 stderr 精確符合 `Pane Terminal(<id>) is already focused` 時視為冪等成功，其他 exit 2（例如 pane 不存在）仍走退路。第一次透過 AppleScript 控制 Ghostty 時，macOS 可能要求 Automation 權限；拒絕時通知本身仍正常，點擊只會走啟動 Ghostty 的退路。

## 內容方案取捨

- 採用：正規化完整 `last-assistant-message` 後截短。它保留實際完成結果，又能讓橫幅長度可預期。
- 不採用：只取第一個非空白行。某些回覆的第一行可能只是泛用標題，會遺失真正結果。
- 不採用：完整傳入、不設長度限制。macOS 的截斷行為較難預期，也會在通知中心保留不必要的長內容。

## 音效方案取捨

- 採用：Terminal Notifier 固定傳入 `-sound default`。它跟隨 macOS 預設通知音效，不新增自訂設定，也不改變點擊路由。
- 不採用：固定指定某個系統音效名稱。它會覆蓋使用者的預設選擇，而且在不同 macOS 版本間較不穩定。
- 不採用：新增音效環境變數。現階段只有「開啟預設音效」需求，額外設定介面沒有必要；後續仍可在 wrapper 集中擴充。

## 修改範圍

### 執行時檔案

- 新增 `~/.local/bin/codex-notify`
- 新增 `~/.local/bin/codex-permission-notify`
- 新增 `~/.local/bin/codex-notification-route`
- 新增 `~/.local/share/codex-notify/terminal-notifier.app`
- 修改 `${CODEX_HOME:-$HOME/.codex}/config.toml`
- 修改 `${CODEX_HOME:-$HOME/.codex}/hooks.json`
- 安裝 Homebrew 套件 `terminal-notifier`

### 測試與文件

- 新增 repository 內的 `codex-notify/tests/codex-notify-test.zsh`
- 更新本設計與對應實作計畫

動態摘要本身只修改 wrapper 與既有測試；為配合 Sky 自動管理 top-level notifier，另在 `config.toml` 的 previous-notify argv 加入 `--native-only`。精準點擊新增獨立 router，並只修改 wrapper 產生 Terminal Notifier click argv 的部分；不修改 Terminal Notifier app bundle 或 `SkyComputerUseClient`。

純 Ghostty 原生通知只修改 wrapper 與既有行為測試。它不重新開啟 `[tui].notifications`，不修改 `config.toml`、`hooks.json`、permission adapter、route helper、Ghostty 或 Sky。

Terminal Notifier 音效只修改 wrapper 的共用通知參數與既有行為測試。完成、權限、Zellij 精準路由及 fallback 自動共用 `-sound default`；不修改其他執行時檔案或設定。

權限等待通知新增薄 adapter、更新 user-level `hooks.json`，並將 `[tui]` 通知關閉。它重用既有 wrapper 與 Terminal Notifier app bundle，不修改 `SkyComputerUseClient`。

### 不修改

- 不修改 Ghostty、Zellij、NVM 或 shell 啟動設定。
- 不修改 `SkyComputerUseClient` 本體。
- 不加入 `codex exec` 分流。
- 不修改 Ghostty 或 Zellij 的分頁標題格式；router 只讀取 Yazelix 已存在的 `${session} |` 標題。
- 不保證已被關閉或重新建立的 terminal／session／pane 仍可精準復原；這些情況一律走 Ghostty 啟動退路。

## 設定結果

Top-level notifier 由 Sky 管理，並明確把 native-only wrapper 保存為 previous notifier：

~~~toml
notify = ["<CODEX_HOME>/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient", "turn-ended", "--previous-notify", "[\"<HOME>/.local/bin/codex-notify\",\"--native-only\"]"]
~~~

TUI 內建終端通知停用：

```toml
[tui]
notifications = false
```

User-level hook 設定為：

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "<HOME>/.local/bin/codex-permission-notify",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

新增或變更的非 managed hook 必須在重新啟動 Codex 後透過 `/hooks` 審查並信任。完成通知仍由 top-level Sky chain 處理。

Sky 的 argv 仍是：

~~~text
SkyComputerUseClient turn-ended <Codex JSON payload>
~~~

Sky 接著執行：

~~~text
codex-notify --native-only <同一個 Codex JSON payload>
~~~

## 回復方式

1. 若只停用精準點擊，設定 `CODEX_NOTIFY_ROUTE_HELPER` 為不存在的路徑，或從 wrapper 移除 router build 呼叫；通知會自動回到 `-activate Ghostty`。
2. 若只停用純 Ghostty 原生通知，設定 `CODEX_NOTIFY_TTY` 為不可用路徑，或移除 wrapper 的 OSC 9 分支；純 Ghostty 會回到 Terminal Notifier `-activate Ghostty`。
3. 若只回復 native-only 修正，移除 previous-notify JSON argv 中的 `"--native-only"`，並回復 wrapper 的單一 payload 參數解析。
4. 若只停用權限等待通知，從 `~/.codex/hooks.json` 移除 `PermissionRequest` 群組；`[tui].notifications` 維持 `false`。
5. wrapper、router 與 `terminal-notifier` 可留著供未來使用，或另行移除。
6. 若只停用 Terminal Notifier 音效，從 wrapper 的共用通知參數移除 `-sound default`；Ghostty 原生音效與所有點擊行為不受影響。

## 驗收條件

- signed helper 驗證與 wrapper 行為測試先失敗、實作後通過，其中包含 wrapper 必須等待通知完成提交的回歸案例。
- 有效的 `last-assistant-message` 會成為通知本文；換行與連續空白會正規化。
- 最終本文最多 160 個 Unicode 字元；超長本文以 `…` 結尾且不產生無效字元。
- 缺失、空白、非字串或無效 JSON payload，以及不可用的 JSON parser，都會安全退回 `任務已完成`。
- `CODEX_NOTIFY_MAX_MESSAGE_CHARS` 與 `CODEX_NOTIFY_FALLBACK_MESSAGE` 的有效覆寫會生效，無效覆寫不會讓 wrapper 失敗。
- 原生通知與 Sky 任一失敗時，另一個仍會執行。
- Sky 收到未修改的 Codex JSON payload。
- Sky 的 previous notifier 收到 `--native-only` 與未修改的 payload；wrapper 不再產生第二次 Sky 呼叫。
- Codex 嚴格設定載入成功。
- 權限核准提示出現時，`PermissionRequest` hook 會呼叫同一 wrapper：純 Ghostty 使用原生 OSC 9，Zellij 使用 Terminal Notifier，不依賴 Zellij 對 OSC 9／BEL 的轉送。
- 有 command 時通知本文包含正規化後的 command；否則依序退回 tool name 與 `等待權限核准`。
- hook stdout 必須為空且 exit 0，不得自動核准、拒絕或中斷權限流程。
- 權限事件只執行 native-only wrapper，不送進 Sky；一般完成事件仍只沿用既有 Sky chain。
- 實機執行 wrapper 時 `terminal-notifier` 與 Sky 都回傳成功。
- macOS Focus 啟用時，實機測試通知仍顯示自動橫幅；系統紀錄的 Focus outcome 為 `allowed`。
- Zellij 路由資料完整時，完成通知與權限通知的 recorded Terminal Notifier argv 使用 `-execute` 而非 `-activate`，且 opaque token 不暴露 cwd、session 或通知本文。
- 點擊 router 會用 token 中的 Zellij 絕對路徑、session 與 pane ID 呼叫 Zellij，再依 Ghostty terminal UUID 聚焦；測試只檢查可觀察 argv、stdin、exit status 與 fallback，不檢查實作原始碼字串。
- 缺少 Zellij 環境、無法解析 Ghostty terminal、token 無效、Zellij／AppleScript 失敗時，通知或 router 都維持 exit 0，並退回 `-activate Ghostty` 或 `open -b Ghostty`。
- 真實 Codex 完成事件與真實權限等待事件的橫幅顯示既有動態內容；手動點擊可切回產生事件的 Ghostty terminal 與 Zellij pane。
- 純 Ghostty 的完成與權限 payload 會把精確動態本文以 OSC 9 寫入測試 tty，且不呼叫 Terminal Notifier；控制字元 ESC/BEL 不得出現在本文區段。
- `TERM_PROGRAM=ghostty` 但任一 Zellij 標記存在時不得寫 OSC 9，必須保留 Terminal Notifier 路徑。
- 純 Ghostty tty 寫入失敗時仍以 exit 0 結束，並透過 Terminal Notifier `-activate Ghostty` 提交通知。
- 真實純 Ghostty 完成通知顯示為 Ghostty，點擊返回來源 terminal；Zellij 完成與權限通知仍顯示為 Terminal Notifier 並保留精準 pane 路由。
- 所有實際呼叫 Terminal Notifier 的完成、權限、Zellij 與 fallback 路徑都包含 `-sound default`；純 Ghostty OSC 成功路徑仍不呼叫 Terminal Notifier。
