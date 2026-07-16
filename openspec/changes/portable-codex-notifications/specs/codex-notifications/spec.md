## ADDED Requirements

### Requirement: Completion events retain the Sky and native notification chain
The system SHALL process every Codex completion event without filtering `codex exec`, SHALL pass the original payload to Sky exactly once, and SHALL invoke the native wrapper in `--native-only` mode without sending the event back to Sky.

#### Scenario: Interactive completion is delivered once
- **WHEN** Codex emits a completion payload through the configured user-level notifier
- **THEN** Sky receives `turn-ended` and the unchanged payload exactly once, and its previous notifier receives `codex-notify --native-only` with that payload

#### Scenario: Native-only invocation does not recurse
- **WHEN** `codex-notify --native-only` receives a completion payload
- **THEN** it submits the platform notification and does not invoke Sky

#### Scenario: One backend fails
- **WHEN** a direct wrapper invocation cannot submit to either Sky or the platform notification backend
- **THEN** it records that backend failure, continues the other backend, and exits successfully

### Requirement: Notification content is dynamic and bounded
The system SHALL derive the notification body only from `last-assistant-message`, collapse whitespace runs to one ASCII space, trim both ends, and limit the result to 160 Unicode characters by default. Missing, invalid, non-string, or blank content SHALL use `任務已完成`.

#### Scenario: Valid assistant summary
- **WHEN** `last-assistant-message` contains multiline or repeated whitespace content within the configured limit
- **THEN** the notification body contains the normalized summary without unrelated input messages

#### Scenario: Summary exceeds the limit
- **WHEN** the normalized summary exceeds the active character limit
- **THEN** the body contains the first limit-minus-one Unicode characters followed by `…`

#### Scenario: Summary is unusable
- **WHEN** the payload is malformed or its assistant summary is absent, non-string, or blank
- **THEN** the normalized fallback body is used and notification delivery remains successful

#### Scenario: Terminal Notifier has project context
- **WHEN** a valid payload includes a `cwd` and uses Terminal Notifier
- **THEN** the title is `Codex`, the message is the dynamic body, and the subtitle is the basename of `cwd`

### Requirement: Notification backend follows the terminal environment
The system SHALL use Ghostty OSC 9 only when `TERM_PROGRAM=ghostty` and `ZELLIJ`, `ZELLIJ_SESSION_NAME`, and `ZELLIJ_PANE_ID` are all empty. Any nonempty Zellij marker or any non-Ghostty environment SHALL use Terminal Notifier.

#### Scenario: Plain Ghostty submits a native notification
- **WHEN** a completion or permission event runs in plain Ghostty and the originating tty is writable
- **THEN** the system writes `ESC ] 9 ; <body> BEL` to that tty and does not invoke Terminal Notifier

#### Scenario: OSC body contains control delimiters
- **WHEN** a plain Ghostty body contains ESC or BEL characters
- **THEN** those characters are removed from the body while the outer OSC framing remains intact

#### Scenario: A partial Zellij environment is present
- **WHEN** any one of the three Zellij marker variables is nonempty
- **THEN** the system does not write OSC 9 and submits through Terminal Notifier

#### Scenario: Originating tty is unavailable
- **WHEN** a plain Ghostty OSC write fails
- **THEN** the system logs `ghostty-osc9`, falls back to a Terminal Notifier notification that activates Ghostty, and exits successfully

### Requirement: Terminal Notifier submissions are signed, audible, and synchronous
Every Terminal Notifier submission SHALL use the verified local app copy, request the macOS default sound, preserve the selected click action, and finish submitting before the wrapper exits.

#### Scenario: Zellij notification is submitted
- **WHEN** an event selects Terminal Notifier
- **THEN** its argv includes `-sound default` exactly once together with the dynamic title, message, optional subtitle, and either `-execute` or `-activate`

#### Scenario: Helper signature is invalid
- **WHEN** the installed Terminal Notifier app does not pass strict deep code-sign verification
- **THEN** installation or verification fails before that bundle is accepted as the active helper

#### Scenario: Submission takes time
- **WHEN** Terminal Notifier remains active while submitting the request
- **THEN** the wrapper waits for the notifier process to finish before returning

### Requirement: Permission waits notify without deciding
The `PermissionRequest` adapter SHALL derive a concise wait message, invoke the shared wrapper in native-only mode, emit no approval decision, keep stdout empty, and exit successfully regardless of notification failure.

#### Scenario: Requested tool includes a command
- **WHEN** a permission payload contains a string or argument-array command
- **THEN** the body is `等待權限核准：<normalized-command>` and the event does not invoke Sky

#### Scenario: Requested tool has no command
- **WHEN** a permission payload has a tool name but no usable command
- **THEN** the body is `等待權限核准：<tool-name>`

#### Scenario: Permission payload is unusable
- **WHEN** the permission payload or JSON parser is unavailable
- **THEN** the body is `等待權限核准`, stdout remains empty, and the adapter exits successfully

#### Scenario: Permission notification backend is selected
- **WHEN** the same permission request runs in plain Ghostty or Zellij
- **THEN** it uses the same environment-based backend and click behavior as a completion notification without allowing or denying the tool

### Requirement: Zellij notifications return to the originating pane
When complete route metadata is available, the system SHALL capture the Ghostty terminal UUID, Zellij session, numeric pane ID, absolute Zellij executable, and required socket environment in a versioned opaque token. Clicking SHALL focus the captured Zellij pane before focusing the Ghostty terminal.

#### Scenario: Complete route is available
- **WHEN** a Terminal Notifier event can resolve all required Zellij and Ghostty metadata
- **THEN** its click argv uses `-execute` with the fixed route helper, `click` subcommand, and an opaque token that does not expose raw session, cwd, message, or terminal identifiers

#### Scenario: User clicks a valid route
- **WHEN** the route helper receives a valid token for a live session, pane, and terminal
- **THEN** it invokes the captured absolute Zellij executable for that session and pane, focuses the captured Ghostty terminal, emits no stdout, and exits successfully

#### Scenario: Pane is already focused
- **WHEN** Zellij returns exit 2 with exactly `Pane Terminal(<id>) is already focused` for the captured pane
- **THEN** the route treats the pane step as idempotent success and still focuses the Ghostty terminal

#### Scenario: Route metadata is incomplete or stale
- **WHEN** route creation lacks required metadata or a click targets a closed or invalid session, pane, or terminal
- **THEN** notification creation uses Ghostty activation or click handling opens Ghostty as a non-blocking fallback without evaluating untrusted shell text
