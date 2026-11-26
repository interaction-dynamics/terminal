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

        _terminal_precmd() {
            builtin local exit_status=$?
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
            fi
        }

        _terminal_preexec() {
            _terminal_running=1
            builtin printf '\e]133;C\a'
        }

        builtin autoload -Uz add-zsh-hook
        add-zsh-hook precmd _terminal_precmd
        add-zsh-hook preexec _terminal_preexec
    fi
}
