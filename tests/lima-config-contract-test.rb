#!/usr/bin/ruby

require "yaml"

repo_dir = File.expand_path("..", __dir__)
config = YAML.safe_load(File.read(File.join(repo_dir, "lima", "dev.yaml")))

def assert(condition, message)
  raise "FAIL: #{message}" unless condition
end

mounts = config.fetch("mounts")
assert(mounts == [{"location" => "~/.cider", "writable" => true}],
       "dev mounts only the writable host .cider directory at Lima's default path")

env = config.fetch("env", {})
assert(!env.key?("CODEX_HOME"), "dev does not override CODEX_HOME")
assert(!env.key?("TMPDIR"), "dev does not inject a cross-platform TMPDIR")

ssh = config.fetch("ssh")
assert(ssh.fetch("forwardAgent") == true,
       "dev forwards the macOS SSH agent without copying private keys into the guest")

provision_scripts = config.fetch("provision").map { |entry| entry.fetch("script") }
assert(provision_scripts.any? { |script| script.include?("/Users/blesscat/.cider/scripts/lima_guest_layout.sh") },
       "guest provisioning installs the guest-native layout through the mounted Cider repo")
assert(provision_scripts.none? { |script| script.include?("codex-lima-overlay") },
       "guest provisioning does not install the legacy shared Codex overlay")

puts "PASS: Lima configuration contract"
