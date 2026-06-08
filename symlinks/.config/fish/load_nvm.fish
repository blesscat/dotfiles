function load_nvm --on-variable PWD
    status is-interactive; or return
    type -q nvm; or return

    set -l current "$PWD"

    while test "$current" != /
        if test -f "$current/.nvmrc"
            read -l node_version <"$current/.nvmrc"
            nvm use --silent "$node_version"
            return
        else if test -f "$current/.node-version"
            read -l node_version <"$current/.node-version"
            nvm use --silent "$node_version"
            return
        end

        set current (dirname "$current")
    end

    if set -q nvm_default_version
        nvm use --silent default
    else if set -q nvm_current_version
        nvm use --silent system
    end
end

load_nvm
