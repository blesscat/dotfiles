# Browser Tools MCP Commands

## `/browser-tools [description]`

**Purpose**: Intelligent browser analysis using natural language descriptions
**Usage**: `/browser-tools <natural language description>`
**Auto-Activates**: browser-tools-mcp only
**Description**: AI automatically selects appropriate browser tools based on description

### Examples

- `/browser-tools 截圖看頁面`
- `/browser-tools 檢查 console 錯誤`
- `/browser-tools 查看網路請求`
- `/browser-tools 頁面性能`
- `/browser-tools 無障礙檢測`
- `/browser-tools 檢查錯誤`
- `/browser-tools 清除日誌`
- `/browser-tools 選中元素`
- `/browser-tools 調試模式`

### AI Decision Logic

**Screenshot Keywords**: 截圖, screenshot, 頁面, 畫面, 顯示, show, capture
**Console Keywords**: 錯誤, error, console, 日誌, log, 調試, debug
**Network Keywords**: 網路, network, 請求, request, API, 連線
**Audit Keywords**: 性能, performance, 無障礙, accessibility, SEO, 檢測, audit
**Debug Keywords**: 調試, debug, 問題, issue, 故障
**Element Keywords**: 元素, element, 選中, selected, DOM
**Clean Keywords**: 清除, clean, 重置, reset, 清理

### Available Tools

- `mcp__browser-tools-mcp__takeScreenshot` - Visual capture
- `mcp__browser-tools-mcp__getConsoleLogs` - Console monitoring
- `mcp__browser-tools-mcp__getConsoleErrors` - Error detection
- `mcp__browser-tools-mcp__getNetworkLogs` - Network analysis
- `mcp__browser-tools-mcp__getNetworkErrors` - Network issues
- `mcp__browser-tools-mcp__runAccessibilityAudit` - A11y analysis
- `mcp__browser-tools-mcp__runPerformanceAudit` - Performance metrics
- `mcp__browser-tools-mcp__runSEOAudit` - SEO analysis
- `mcp__browser-tools-mcp__runBestPracticesAudit` - Best practices
- `mcp__browser-tools-mcp__runNextJSAudit` - Next.js specific
- `mcp__browser-tools-mcp__runDebuggerMode` - Debug activation
- `mcp__browser-tools-mcp__runAuditMode` - Comprehensive audit
- `mcp__browser-tools-mcp__getSelectedElement` - Element inspection
- `mcp__browser-tools-mcp__wipeLogs` - Log cleanup

### Implementation Rules

1. **Single Tool Focus**: Use ONLY browser-tools-mcp, no fallbacks
2. **Smart Selection**: AI chooses most appropriate tool(s) based on description
3. **Multi-Tool Support**: Can use multiple tools for comprehensive requests
4. **Context Awareness**: Consider current browser state and previous actions
5. **Language Agnostic**: Works with Chinese, English, or mixed descriptions
