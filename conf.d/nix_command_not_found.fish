if not test -f /run/current-system/sw/bin/command-not-found
    set -l reset (set_color normal)
    set -l ns (status filename | path basename)
    # log --namespace $ns error "/run/current-system/sw/bin/command-not-found does not exist!"
    printf '%s%s%s %serror%s: /run/current-system/sw/bin/command-not-found does not exist!\n' (set_color --dim) $ns $reset (set_color red) $reset
    printf 'Are you sure you are running NixOS?\n'
    return
end


function get_close_matches -a word n cutoff
    argparse --min-args=3 --max-args=3 -- $argv; or return 2
    isatty stdin; and return 2

    # echo "n: $n, cutoff: $cutoff" >&2
    # string match --regex --quiet '^\s*$' -- $n
    # and set n 1
    # string match --regex --quiet '^\s*$' -- $cutoff
    # and set cutoff 0.5
    # test in [0.0, 1.0]
    # test $cutoff -ge 0.0 -a $cutoff -le 1.0; or return 2

    # echo "n: $n, cutoff: $cutoff" >&2

    set -l pyscript "
import difflib
import sys

command: str = sys.argv[1]
executables = sys.stdin.readlines()
n: int = int(sys.argv[2])
cutoff: float = float(sys.argv[3])

close_matches = difflib.get_close_matches(command, executables, n=n, cutoff=cutoff)
if close_matches is not None:
    for m in close_matches:
        print(m, file=sys.stdout, end='')
    "
    command cat | python (printf '%s\n' $pyscript | psub) $word $n $cutoff
end

# TODO: is this assumption always true, what if nix is installed on MacOS, or as a standalone tool on another
# linux distro?
# Host is NixOS

# Redefine `fish_command_not_found` to make the output of `/run/current-system/sw/bin/command-not-found`
# more visually appealing.
# NOTE: The output of `command-not-found` is assumed to match the output of 
# https://github.com/NixOS/nixpkgs/blob/8291dd11ac3d35a0d72ab8fa06c05c264ffb512d/nixos/modules/programs/command-not-found/command-not-found.pl
# as seen in commit 363ef08. Newer commits are likely to work.
function fish_command_not_found -a command_not_found
    # TODO: improvement ideas
    # check if ./flake.nix exist, and contains a `devShells` output attribute, and suggest the package be added
    # to `devShells.buildInputs` or `devShells.nativeBuildInputs` or `devShells.packages`
    # check of ./devenv.nix exist
    # check if ./configuration.nix exist and $PWD is /etx/nixos and suggest add to environment.systemPackages
    set -l pkgs
    set_color --dim
    set -l in_nixpkgs 1
    /run/current-system/sw/bin/command-not-found $argv &| while read line
        if string match --quiet "$command_not_found: command not found" -- $line
            set in_nixpkgs 0
            break
        end

        # collect all suggested pkgs from nixpkgs that offers a binary named `$argv`
        if string match --regex --groups-only '^\s*nix-shell -p (\S+)' -- $line | read pkg
            set -a pkgs $pkg
        else if string match --quiet --regex "'[^']+'" -- $line
            # Highlight the name of the binary like `fish` would do it
            # string replace --regex "'([^']+)(.+)(PATH)'" "$(set_color normal)$(set_color $fish_color_command)\$1$(set_color normal)$(set_color --dim)\$2$(set_color normal)$(set_color $fish_color_param)PATH$(set_color normal)$(set_color --dim)" -- $line
            string replace --regex "'([^']+)'(.+)(PATH)" "$(set_color normal)$(set_color $fish_color_command)\$1$(set_color normal)$(set_color --dim)\$2$(set_color normal)$(set_color $fish_color_param)PATH$(set_color normal)$(set_color --dim)" -- $line
            # else if string match --quiet --regex PATH -- $line
            #     string replace --regex "(PATH)" "$(set_color normal)$(set_color $fish_color_param)\$\$1$(set_color normal)$(set_color --dim)" -- $line
        else
            echo $line
        end
    end

    set_color normal

    set -l reset (set_color normal)
    set -l yellow (set_color yellow)
    set -l bi (set_color --bold --italics)
    set -l dim (set_color --dim)

    if test $in_nixpkgs -eq 0
        printf '%s%s%s: command not found in %s<nixpkgs>%s\n' (set_color red) $command_not_found $reset (set_color magenta) $reset
    else

        # test (count $pkgs) -eq 0; and return

        set -l experimental_features
        if test -r /etc/nix/nix.conf
            set -a experimental_features (string match --regex --groups-only '^experimental-features = (.+)' </etc/nix/nix.conf | string split ' ')
        end

        set -l nix_command_enabled 0
        contains -- nix-command $experimental_features
        and contains -- flakes $experimental_features
        and set nix_command_enabled 1

        # TODO: does this depend on 
        # experimental-features = ["nix-command" "flakes"];

        if set -q __nix_command_not_found_ephemeral_abbrs_created
            # Erase abbreviations from the previous time `fish_command_not_found` was called this shell session
            # reason: If the previous invocation generated 4 abbreviations, and the currrent generates 2, then
            # nsh{3,4} will "float around" and confusingly map to another program.
            for a in $__nix_command_not_found_ephemeral_abbrs_created
                abbr --erase $a
            end
        end
        set -g __nix_command_not_found_ephemeral_abbrs_created

        # set -l i 1
        # set -l width (math "floor(log $(count $pkgs)) + 1")
        # set -l fmtstr (string join '' "\t[%s%$width" "d%s] ")
        for pkg in $pkgs
            # printf '\t[%s%d%s] ' $yellow $i $reset
            # TODO: color index differently if abbr already exist
            # printf $fmtstr $yellow $i $reset



            # hyperlink in terminal standard: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
            set -l channel unstable
            set -l url "https://search.nixos.org/packages?channel=$channel&show=$pkg&from=0&size=1&type=packages&query=$pkg"
            printf '\t'

            set -l prompt
            if test $nix_command_enabled -eq 2
                printf "%snix%s %sshell%s " (set_color $fish_color_command) $reset (set_color $fish_color_param) $reset
                printf "\e]8;;"
                printf '%s' $url
                printf '\e\\'
                printf '%snixpkgs#%s%s' (set_color $fish_color_param) $pkg $reset
                printf '\e]8;;\e\\'
                printf '\n'
            else
                printf "%snix-shell%s %s-p%s " (set_color $fish_color_command) $reset (set_color $fish_color_option) $reset
                printf "\e]8;;"
                printf '%s' $url
                printf '\e\\'
                printf '%s%s%s' (set_color $fish_color_param) $pkg $reset
                printf '\e]8;;\e\\'
                printf '\n'
            end
            # set -l a nsh$i
            # if not abbr -q $a
            #     abbr -a $a $prompt
            #     set -a __nix_command_not_found_ephemeral_abbrs_created $a
            # end



            # printf '%s' $var
            # printf ' %s %s %s\n' $postfix_color $postfix $reset


            # echo $prompt | fish_indent --ansi
            # set i (math "$i + 1")
        end

        # TODO: notify abbrs been created

        # function __nix_command_not_found_on_preexec --on-event fish_preexec
        #     for a in $__nix_command_not_found_ephemeral_abbrs_created
        #         abbr --erase $a
        #     end
        #     functions --erase (status function) # delete itself, to create a oneshot hook
        # end


        if command -q ,
            printf "\n%sor: (since you have %shttps://github.com/nix-community/comma%s%s installed)%s\n" $dim $bi $reset $dim $reset
            printf '\t'
            echo ", $argv" | fish_indent --ansi
        end

        # printf '\n%sread more about the suggested packages at:%s\n' $dim $reset
        # # TODO: detect channel
        # set -l channel unstable
        # # TODO: detect if terminal emulator has support for OSC hyperlinks and use them if available
        # set -l url "https://search.nixos.org/packages?channel=$channel&show=$pkgs[1]&from=0&size=50&sort=relevance&type=packages&query=$argv"
        # printf '\t%s%s%s\n' $bi $url $reset

        begin
            # TODO: figure out if this is a useful idea

            # if test -f ./flake.nix
            #     set -l jq_program
            #     if command -q jaq
            #         set jq_program jaq
            #     else if command -q jq
            #         set jq_program jq
            #     end

            #     # set -l arch
            #     # switch (command uname --machine)
            #     #     case x86_64
            #     # end

            #     set -l jq_query '.devShells'
            #     if string match --quiet null (nix flake info | $jq_program $jq_query)
            #         printf 'add to "devShells ... buildInputs = [%s]"\n' $pkgs[1]
            #     end
            # end

            # if test -f ./configuration.nix -a $PWD = /etc/nixos
            # end

            # if test -f ./devenv.nix; and command -q devenv
            #     # https://devenv.sh/
            #     echo todo
            # end

            # if command -q home-manager
            #     # home.packages
            # end
        end

    end

    # set -l similar_executable_names
    # set -l all_executable_names (path filter -x $PATH/* | path basename)

    set -q nix_command_not_found_suggest_close_matches_n
    or set -U nix_command_not_found_suggest_close_matches_n 10
    set -q nix_command_not_found_suggest_close_matches_cutoff
    or set -U nix_command_not_found_suggest_close_matches_cutoff 0.2

    set -q nix_command_not_found_suggest_close_matches
    or set -U nix_command_not_found_suggest_close_matches 1
    if test $nix_command_not_found_suggest_close_matches -eq 1
        set -l close_matches (path filter -x $PATH/* | path basename | sort --unique | get_close_matches $command_not_found $nix_command_not_found_suggest_close_matches_n $nix_command_not_found_suggest_close_matches_cutoff)

        set -l n_close_matches (count $close_matches)
        # echo "n_close_matches : $n_close_matches "
        # printf '-%s\n' $close_matches

        if test $n_close_matches -gt 0
            echo
            if test $n_close_matches -eq 1
                printf '%sThere is %s%s%d%s%s other program in your %s%s$PATH%s%s with a similar name:%s\n' \ 
                $dim $reset \
                    (set_color $fish_color_command) $n_close_matches $reset \
                    $dim $reset (set_color $fish_color_param) $reset $dim $reset
            else
                # > 1
                printf '%sThere are %s%s%d%s%s other programs in your %s%s$PATH%s%s with a similar name:%s\n' \
                    $dim $reset \
                    (set_color $fish_color_command) $n_close_matches $reset \
                    $dim $reset (set_color $fish_color_param) $reset $dim $reset
            end
            # echo
        end

        for exe in $close_matches
            # find substring in match
            if string match --index --regex "$command_not_found" $exe | read -l start offset
                # echo "exe: $exe"
                # echo "start: $start, offset: $offset"
                # FIXME: case where is a prefix is wrong "git" "gitui" -> "giti"
                set -l before (string sub --start=1 --length=(math "$start - 1") -- $exe)
                set -l match (string sub --start=$start --length=$offset -- $exe)
                set -l after (string sub --start=(math "$start + $offset + 1") -- $exe)

                printf '\t%s%s%s%s%s%s%s%s%s' \
                    (set_color $fish_color_command --dim) $before $reset \
                    (set_color $fish_color_command --italics) $match $reset \
                    (set_color $fish_color_command --dim) $after $reset

            else
                printf '\t%s%s%s' (set_color $fish_color_command --dim) $exe $reset
            end

            printf '\t %s->%s ' $dim $reset
            if functions -q nix-store-highlight
                command --search $exe | path resolve | nix-store-highlight
            else
                command --search $exe | path resolve
            end
            # echo
        end
    end

    # set -l len_command_not_found (string length -- $command_not_found)


    # set -q nix_command_not_found_suggest_matching_prefix
    # or set -U nix_command_not_found_suggest_matching_prefix 1
    # if test $nix_command_not_found_suggest_matching_prefix -eq 1
    #     printf '%s\n' $all_executable_names | command grep --color=always "^$command_not_found" \
    #         | while read exe
    #         printf ' - %s\n' $exe
    #         # command --search $exe | path resolve | nix-store-highlight
    #     end

    #     # for exe in $all_executable_names
    #     #     if test $command_not_found = (string sub --length=$len_command_not_found -- $exe)
    #     #         set -l start (math "$len_command_not_found + 1")
    #     #         set -l rest (string sub --start=$start -- $exe)
    #     #         printf ' - %s%s%s%s\n' (set_color red) $command_not_found $reset $start
    #     #     end
    #     # end
    # end

    # set -q nix_command_not_found_suggest_matching_postfix
    # or set -U nix_command_not_found_suggest_matching_postfix 1
    # if test $nix_command_not_found_suggest_matching_postfix -eq 1
    #     printf '%s\n' $all_executable_names | command grep --color=always "$command_not_found\$" \
    #         | while read exe
    #         printf ' - %s\n' $exe
    #         # command --search $exe | path resolve | nix-store-highlight
    #     end

    #     # for exe in $all_executable_names
    #     #     if test $command_not_found = (string sub --length=$len_command_not_found -- $exe)
    #     #         set -l start (math "$len_command_not_found + 1")
    #     #         set -l rest (string sub --start=$start -- $exe)
    #     #         printf ' - %s%s%s%s\n' (set_color red) $command_not_found $reset $start
    #     #     end
    #     # end
    # end


    # TODO: also suggest matching `abbr --list` abbreviations
    set -q nix_command_not_found_suggest_close_functions_n
    or set -U nix_command_not_found_suggest_close_functions_n 5
    set -q nix_command_not_found_suggest_close_functions_cutoff
    or set -U nix_command_not_found_suggest_close_functions_cutoff 0.7

    set -q nix_command_not_found_suggest_close_functions
    or set -U nix_command_not_found_suggest_close_functions 1
    if test $nix_command_not_found_suggest_close_functions -eq 1

        set -l close_matches (functions --names --all | string split , | get_close_matches $command_not_found $nix_command_not_found_suggest_close_functions_n $nix_command_not_found_suggest_close_functions_cutoff)

        set -l n_close_matches (count $close_matches)
        if test $n_close_matches -gt 0
            echo
            if test $n_close_matches -eq 1
                printf '%sThere is %s%s%d%s%s other function in your %s%s$fish_function_path%s%s with a similar name:%s\n' $dim $reset (set_color $fish_color_command) $n_close_matches $reset $dim $reset (set_color $fish_color_param) $reset $dim $reset
            else
                # > 1
                printf '%sThere are %s%s%d%s%s other functions in your %s%s$fish_function_path%s%s with a similar name:%s\n' $dim $reset (set_color $fish_color_command) $n_close_matches $reset $dim $reset (set_color $fish_color_param) $reset $dim $reset
            end
        end

        for fn in $close_matches
            # echo $fn
            # find substring in match
            if string match --index --regex "$command_not_found" $fn | read -l start offset
                # echo "exe: $exe"
                # echo "start: $start, offset: $offset"
                # FIXME: case where is a prefix is wrong "git" "gitui" -> "giti"
                set -l before (string sub --start=1 --length=(math "$start - 1") -- $fn)
                set -l match (string sub --start=$start --length=$offset -- $fn)
                set -l after (string sub --start=(math "$start + $offset + 1") -- $fn)

                printf '\t%s%s%s%s%s%s%s%s%s' \
                    (set_color $fish_color_command --dim) $before $reset \
                    (set_color $fish_color_command --italics) $match $reset \
                    (set_color $fish_color_command --dim) $after $reset
            else
                printf '\t%s%s%s' (set_color $fish_color_command --dim) $fn $reset
            end
            printf '\t %s->%s %s%s\n' $dim $reset (functions --details $fn | string replace $HOME "~" | string replace --regex "(\.config/fish/functions)" "$(set_color blue --dim)\$1$(set_color normal)") $reset
        end
    end

    # TODO: look through $PWD/* for executables and check those names, and if close then suggest the relative path to it
end
