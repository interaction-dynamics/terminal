# Terminal shell integration for zsh. Loaded because the app starts zsh with
# ZDOTDIR pointing at this folder. It puts the user's ZDOTDIR back, sources
# their .zshenv, then adds two hooks so the app knows the shell's state:
#
#   precmd  -> OSC 133;D;<exit> (command finished) and OSC 7 (folder),
#              which also tells the app a prompt is ready
#   preexec -> OSC 133;C (command started)
#
# With TERMINAL_SMART_INPUT=1 the shell's own prompt is emptied: the app draws
# its own prompt line and input box. Nothing changes outside this terminal.

if [[ -n "${TERMINAL_ZSH_ZDOTDIR+X}" ]]; then
    builtin export ZDOTDIR="$TERMINAL_ZSH_ZDOTDIR"
    builtin unset TERMINAL_ZSH_ZDOTDIR
else
    builtin unset ZDOTDIR
fi

{
    builtin typeset _terminal_file=${ZDOTDIR-$HOME}"/.zshenv"
    [[ ! -r "$_terminal_file" ]] || builtin source -- "$_terminal_file"
} always {
    builtin unset _terminal_file
    if [[ -o interactive ]]; then
        builtin typeset -g _terminal_running=0
        builtin typeset -g _terminal_first=1

        # Warp-style blocks (smart input only): a dim header with the folder
        # and git branch above each command, and a thin line after its output
        # with the exit status and duration. libghostty draws the output, so
        # the shell prints these lines itself.
        builtin zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null
        builtin typeset -g _terminal_started=''

        # Current git branch without starting a process (reads .git/HEAD).
        _terminal_branch() {
            REPLY=''
            builtin local dir=$PWD head='' gitdir
            while true; do
                if [[ -f $dir/.git/HEAD ]]; then
                    head=$(<$dir/.git/HEAD); break
                elif [[ -f $dir/.git ]]; then
                    gitdir=$(<$dir/.git); gitdir=${gitdir#gitdir: }
                    [[ $gitdir == /* ]] || gitdir=$dir/$gitdir
                    [[ -f $gitdir/HEAD ]] && head=$(<$gitdir/HEAD)
                    break
                fi
                [[ $dir == / || -z $dir ]] && break
                dir=${dir:h}
            done
            if [[ $head == 'ref: refs/heads/'* ]]; then REPLY=${head#ref: refs/heads/}
            elif [[ -n $head ]]; then REPLY=${head[1,7]}; fi
        }

        # Thin line closing the block, with ✗ status and duration on the right.
        _terminal_block_end() {
            builtin local exit_status=$1 info='' plain='' ms line=''
            if [[ -n $_terminal_started && -n $EPOCHREALTIME ]]; then
                ms=$(( (EPOCHREALTIME - _terminal_started) * 1000 ))
                if (( ms < 1000 )); then info=$(builtin printf '%.3fs' $(( ms / 1000.0 )))
                elif (( ms < 60000 )); then info=$(builtin printf '%.1fs' $(( ms / 1000.0 )))
                else info="$(( ${ms%.*} / 60000 ))m $(( ${ms%.*} % 60000 / 1000 ))s"; fi
            fi
            plain=" $info"
            if (( exit_status != 0 )); then plain=" ✗ $exit_status$plain"; fi
            builtin local n=$(( ${COLUMNS:-80} - ${#plain} - 1 ))
            (( n < 4 )) && n=4
            repeat $n line+='─'
            if (( exit_status != 0 )); then
                builtin printf '\e[2m%s\e[0m \e[31m✗ %s\e[0m\e[2m %s\e[0m\n' "$line" "$exit_status" "$info"
            else
                builtin printf '\e[2m%s %s\e[0m\n' "$line" "$info"
            fi
        }

        # Dim header for the next command: folder and branch.
        _terminal_block_header() {
            _terminal_branch
            builtin local where=${(%):-%~}
            [[ -n $REPLY ]] && where+=" git:($REPLY)"
            builtin printf '\e[2m%s\e[0m\n' "$where"
        }

        _terminal_precmd() {
            builtin local exit_status=$? ran=$_terminal_running first=$_terminal_first
            if (( _terminal_running )); then
                builtin printf '\e]133;D;%s\a' "$exit_status"
                _terminal_running=0
            fi
            # localhost: libghostty only accepts a local host, and macOS changes
            # the machine's hostname with the network.
            builtin printf '\e]7;kitty-shell-cwd://localhost%s\a' "${PWD}"

            if (( _terminal_first )); then
                _terminal_first=0
                # Run after every other precmd hook (themes set PROMPT in theirs).
                precmd_functions=(${precmd_functions:#_terminal_precmd} _terminal_precmd)
            fi
            if [[ "$TERMINAL_SMART_INPUT" == 1 ]]; then
                PROMPT='' RPROMPT='' PS2=''
                (( ran )) && _terminal_block_end $exit_status
                (( ran || first )) && _terminal_block_header
            fi
        }

        _terminal_preexec() {
            _terminal_running=1
            _terminal_started=$EPOCHREALTIME
            builtin printf '\e]133;C\a'
        }

        builtin autoload -Uz add-zsh-hook
        add-zsh-hook precmd _terminal_precmd
        add-zsh-hook preexec _terminal_preexec
    fi
}
