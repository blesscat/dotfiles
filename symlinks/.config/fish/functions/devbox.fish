function devbox
    set dir $argv[1]

    if test -z "$dir"
        set dir .
    end

    open -na Ghostty --args \
        --theme="Dracula" \
        -e fish -lc "ssh -t codex-dev@orb 'cd ~/doc/$dir && exec \$SHELL -l'"
end
