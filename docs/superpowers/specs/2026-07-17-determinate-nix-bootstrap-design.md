# Interactive Determinate Nix Bootstrap Design

## Context

Yazelix requires Nix with flakes enabled. The current macOS bootstrap installs
Yazelix only when `nix` is already available and otherwise defers it. A new Mac
should offer to install Nix before Homebrew setup, while making the system-level
changes explicit and preserving a safe opt-out path.

## Approved behavior

`macos.sh` performs its repository preflight, then runs the Nix setup step
before Homebrew or any other installer.

- If `nix` is already available, setup reports its version and does not prompt
  or replace the existing installation.
- If `nix` is missing, setup explains that Determinate Nix creates `/nix`,
  installs a daemon, and requires administrator authorization. It prompts with
  `Install Determinate Nix now? [y/N]`.
- `y` and `yes`, case-insensitively, approve installation.
- `n`, `no`, or an empty response declines installation and allows the rest of
  `macos.sh` to continue. Yazelix remains deferred.
- Invalid interactive input is rejected and prompts again.
- End-of-file on standard input is treated as the default `no`, so unattended
  bootstrap does not hang or silently perform a privileged installation.
- If an approved download, signature check, package installation, environment
  activation, or Nix verification fails, `macos.sh` stops unsuccessfully.
- Yazelix installation remains non-interactive, and `yzx launch` remains an
  explicit command after the separate symlink workflow.

## Components and sequence

Add `scripts/nix_setup.sh` as the single owner of Nix detection, explanation,
confirmation, package verification, installation, and post-install checks.
`macos.sh` invokes it before sourcing `scripts/brew_setup.sh`, then refreshes
the parent shell's Nix environment when a new installation occurred.

The successful new-Mac sequence is:

1. Repository preflight.
2. Interactive Determinate Nix setup.
3. Homebrew setup and Brewfile installation.
4. Portable Codex notification installation.
5. Yazelix profile installation.
6. The user separately runs `./symlinks.sh` and `yzx launch`.

Because an executable child script cannot change its parent's environment,
`macos.sh` sources the standard Nix daemon profile if `nix` is still absent
after setup. It then requires `command -v nix` to succeed before continuing,
so the later Yazelix subprocess can discover Nix without a new terminal.

## Package provenance and installation

Use Determinate Systems' stable Universal macOS package endpoint:

`https://install.determinate.systems/determinate-pkg/stable/Universal`

Download the package to a private temporary directory with HTTPS-only curl
settings. Do not pipe a remote shell directly into an interpreter. Before any
privileged installation, use macOS package assessment to require the expected
Apple Developer Team ID `X3JQ4VPJZ6`. A missing, unparsable, or different Team
ID is fatal.

After validation, run macOS's system package installer through `sudo`. Always
remove the temporary package through a trap. Verify that the resulting `nix`
command is executable, prints a version, and exposes the flake command before
continuing.

## Failure and existing-state policy

An existing Nix installation is user-owned state. The bootstrap does not
migrate upstream Nix to Determinate Nix, reinstall Determinate Nix, or alter an
existing Nix configuration. Declining installation is also not an error.

Once the user approves installation, failures are not converted into a
deferred success: partial or unverifiable setup must be visible before the
Homebrew stage begins. The Determinate package owns rollback and uninstallation;
the dotfiles repository does not remove `/nix`, daemons, users, volumes, or
Keychain state.

## Testing

Add isolated behavior tests for:

- existing Nix skipping the explanation, prompt, download, and installation;
- missing Nix showing the approved explanation before any Homebrew step;
- yes responses accepting case-insensitive `y` and `yes`;
- empty, no, and EOF responses declining without failure or installation;
- invalid input prompting again;
- exact stable package URL and HTTPS-only download arguments;
- valid expected Team ID permitting installation;
- invalid or missing Team ID stopping before `sudo installer`;
- download, installer, environment activation, version, and flakes failures
  propagating before Homebrew;
- successful Nix installation occurring before Homebrew, notification, and
  Yazelix setup; and
- repeated bootstrap with Nix now present remaining prompt-free and
  idempotent.

Tests use command fixtures and isolated input streams. They assert observable
output, argv, ordering, exit status, and absence of privileged side effects;
they never invoke the live package installer or mutate the current `/nix`.

## Documentation

Update the root README and the active OpenSpec change to describe the initial
prompt, system changes, default-no behavior, failure semantics, and the final
manual `yzx launch` step. Document Determinate's uninstaller command for users
who later choose to remove Nix, without automating uninstallation.
