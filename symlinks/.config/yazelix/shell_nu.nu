# Yazelix-managed Nushell hook
# Add Nushell-only commands for Yazelix sessions here

# Keep pnpm global CLIs on Node 24, even inside an existing Zellij session.
$env.PNPM_HOME = ($env.HOME | path join "Library" "pnpm")
$env.PATH = (
  $env.PATH
  | prepend ($env.HOME | path join ".local" "share" "nvm" "v24.16.0" "bin")
  | prepend $env.PNPM_HOME
  | uniq
)
