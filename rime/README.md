# Shared Rime configuration

These user customizations are shared by Squirrel on macOS and Fcitx5 Rime on
Linux. They patch installed schemas without replacing package-managed schema
files.

Run bash scripts/rime_setup.sh from this repository on either system. The
script links the three tracked custom YAML files into the platform's Rime user
directory. If a destination already contains a regular file or a different
symlink, it is moved to a timestamped .pre-cider backup first.

On Linux, the script also runs rime_deployer using the installed Rime shared
data. On macOS, deploy from the Squirrel menu after running the script.

The schema list contains Daqian Bopomofo (bopomofo_tw) and Rime Ice full
Pinyin (rime_ice). Bopomofo candidates get tone-marked Pinyin comments using
the built-in terra_pinyin dictionary and Rime's spelling_hints; this only adds
candidate comments and does not alter candidate ordering. The Pinyin scheme
defaults to Taiwan Traditional conversion (s2tw.json).
