if not test -f /run/current-system/sw/bin/command-not-found
    set -l reset (set_color normal)
    set -l ns (status filename | path basename)
    # log --namespace $ns error "/run/current-system/sw/bin/command-not-found does not exist!"
    printf '%s%s%s %serror%s: /run/current-system/sw/bin/command-not-found does not exist!\n' (set_color --dim) $ns $reset (set_color red) $reset
    printf 'Are you sure you are running NixOS?\n'
    return
end

# TODO: is this assumption always true, what if nix is installed on MacOS, or as a standalone tool on another
# linux distro?
# Host is NixOS

# Redefine `fish_command_not_found` to make the output of `/run/current-system/sw/bin/command-not-found`
# more visually appealing.
# NOTE: The output of `command-not-found` is assumed to match the output of 
# https://github.com/NixOS/nixpkgs/blob/8291dd11ac3d35a0d72ab8fa06c05c264ffb512d/nixos/modules/programs/command-not-found/command-not-found.pl
# as seen in commit 363ef08. Newer commits are likely to work.
function fish_command_not_found
    # TODO: improvement ideas
    # check if ./flake.nix exist, and contains a `devShells` output attribute, and suggest the package be added
    # to `devShells.buildInputs` or `devShells.nativeBuildInputs`
    # check of ./devenv.nix exist
    # check if ./configuration.nix exist and $PWD is /etx/nixosa and suggest add to environment.systemPackages
    set -l pkgs
    /run/current-system/sw/bin/command-not-found $argv &| while read line
        # collect all suggested pkgs from nixpkgs that offers a binary named `$argv`
        if string match --regex --groups-only '^\s*nix-shell -p (\S+)' -- $line | read pkg
            set -a pkgs $pkg
        else if string match --quiet --regex "'[^']+'" -- $line
            # Highlight the name of the binary like `fish` would do it
            string replace --regex "'([^']+)'" "$(set_color $fish_color_command)\$1$(set_color normal)" -- $line
        else
            echo $line
        end
    end

    test (count $pkgs) -eq 0; and return

    # TODO: does this depend on 
    # experimental-features = ["nix-command" "flakes"];
    set -l reset (set_color normal)
    set -l yellow (set_color yellow)

    if set -q __nix_command_not_found_ephemeral_abbrs_created
        # Erase abbreviations from the previous time `fish_command_not_found` was called this shell session
        # reason: If the previous invocation generated 4 abbreviations, and the currrent generates 2, then
        # nsh{3,4} will "float around" and confusingly map to another program.
        for a in $__nix_command_not_found_ephemeral_abbrs_created
            abbr --erase $a
        end
    end
    set -g __nix_command_not_found_ephemeral_abbrs_created

    set -l i 1
    set -l width (math "floor(log $(count $pkgs)) + 1")
    set -l fmtstr (string join '' "\t[%s%$width" "d%s] ")
    for pkg in $pkgs
        # printf '\t[%s%d%s] ' $yellow $i $reset
        # TODO: color index differently if abbr already exist
        printf $fmtstr $yellow $i $reset
        set -l prompt "nix shell nixpkgs#$pkg"
        set -l a nsh$i
        if not abbr -q $a
            abbr -a $a $prompt
            set -a __nix_command_not_found_ephemeral_abbrs_created $a
        end
        echo $prompt | fish_indent --ansi
        set i (math "$i + 1")
    end

    # TODO: notify abbrs been created

    # function __nix_command_not_found_on_preexec --on-event fish_preexec
    #     for a in $__nix_command_not_found_ephemeral_abbrs_created
    #         abbr --erase $a
    #     end
    #     functions --erase (status function) # delete itself, to create a oneshot hook
    # end

    set -l reset (set_color normal)
    set -l bi (set_color --bold --italics)
    if command -q ,
        printf "\nor: (since you have %shttps://github.com/nix-community/comma%s installed)\n" $bi $reset
        printf '\t'
        echo ", $argv" | fish_indent --ansi
    end

    printf '\nread more about the suggested packages at:\n'
    # TODO: detect channel
    set -l channel unstable
    # TODO: detect if terminal emulator has support for OSC hyperlinks and use them if available
    set -l url "https://search.nixos.org/packages?channel=$channel&show=$pkgs[1]&from=0&size=50&sort=relevance&type=packages&query=$argv"
    printf '\t%s%s%s\n' $bi $url $reset

    if test -f ./flake.nix
        set -l jq_program
        if command -q jaq
            set jq_program jaq
        else if command -q jq
            set jq_program jq
        end

        # set -l arch
        # switch (command uname --machine)
        #     case x86_64
        # end

        set -l jq_query '.devShells'
        if string match --quiet null (nix flake info | $jq_program $jq_query)
            printf 'add to "devShells ... buildInputs = [%s]"\n' $pkgs[1]
        end
    end

    if test -f ./configuration.nix -a $PWD = /etc/nixos
    end

    if test -f ./devenv.nix; and command -q devenv
    end

    if command -q home-manager
        # home.packages
    end
end
