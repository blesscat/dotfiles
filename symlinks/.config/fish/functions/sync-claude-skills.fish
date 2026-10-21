function sync-claude-skills --description 'Symlink ~/.agents/skills into ~/.claude/skills'
    set -l src ~/.agents/skills
    set -l dest ~/.claude/skills
    mkdir -p $dest

    # Remove links whose source skill was deleted
    for link in $dest/*
        if test -L $link; and not test -e $link
            rm $link
            echo "removed: "(basename $link)
        end
    end

    for dir in $src/*/
        set -l name (basename $dir)
        test -f $dir/SKILL.md; or continue
        set -l target $dest/$name
        if test -e $target; and not test -L $target
            echo "skipped (not a symlink): $name"
            continue
        end
        if not test -L $target
            echo "linked: $name"
        end
        ln -sfn (string trim -r -c / $dir) $target
    end
end
