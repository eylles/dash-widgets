#!/bin/sh
export LANG=C

# Signals to emit inside AwesomeWM

# sound::sink::volume
SIG_VOL_SINK="sound::sink::volume"
# sound::sink::mute
SIG_MUTE_SINK="sound::sink::mute"
# sound::sink::port
SIG_PORT_SINK="sound::sink::port"

# sound::source::volume
SIG_VOL_SOURCE="sound::source::volume"
# sound::source::mute
SIG_MUTE_SOURCE="sound::source::mute"
# sound::source::port
SIG_PORT_SOURCE="sound::source::port"

# State trackers to avoid redundant transmissions

SINK_VOL=""
SINK_MUTE=""
SINK_PORT=""
SOURCE_VOL=""
SOURCE_MUTE=""
SOURCE_PORT=""

STATE_DIR="${XDG_RUNTIME_DIR}/awesome/sound"
STATE_FILE="${STATE_DIR}/${XDG_SESSION_ID}.status"

myname="${0##*/}"

NOT_SILENT=""

CONF_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/awesome/signal-emitter-config/awesome-sound"
CONFIG="$CONF_DIR/config.rc"

if [ ! -d "$CONF_DIR" ]; then
    mkdir -p "$CONF_DIR"
fi

if [ ! -f "$CONFIG" ]; then
        cat << __HEREDOC__ > "$CONFIG"
# vim: ft=sh
# awesome-sound signal config file

# Writing any string to this option will make this signal emitter to output debug information into
# the awesome wm log file, the default is for the signal emitter to work in silent mode producing no
# output only emitting signals.
NOT_SILENT=""
__HEREDOC__
fi

if [ ! -d "$STATE_DIR" ]; then
    mkdir -p "$STATE_DIR"
fi

client_name="awesome-sound-id-${XDG_SESSION_ID}"

# kill other instances if they exist
pkill --full "pactl --client-name=$client_name subscribe" 2>/dev/null

# usage: lstrip "string" "pattern"
# description: remove patter from start of string
# return type: string
lstrip () {
    # we want these to match as patterns
    # shellcheck disable=SC2295
    printf '%s\n' "${1##$2}"
}

# usage: rstrip "string" "pattern"
# description: remove patter from end of string
# return type: string
rstrip () {
    # we want these to match as patterns
    # shellcheck disable=SC2295
    printf '%s\n' "${1%%$2}"
}

# usage: strip_pattern "string" "pattern"
# description: remove patter from Start and End of string
# return type: string
strip_pattern() {
    string="$1"
    pattern="$2"
    string=$(lstrip "${string}" "$pattern")
    string=$(rstrip "${string}" "$pattern")
    printf '%s\n' "$string"
}

# Usage: getval "KEY" file
# description: read a KEY=VALUE file and retrieve the VALUE of the passed KEY
# return type: stdout string
getval(){
    if [ -r "$2" ]; then
        # Setting 'IFS' tells 'read' where to split the string.
        while IFS='=' read -r key val; do
            # Skip over lines containing comments.
            # (Lines starting with '#').
            [ "${key##\#*}" ] || continue
            # '$key' stores the key.
            # '$val' stores the value.
            if [ "$key" = "$1" ]; then
                printf '%s\n' "$val"
            fi
        done < "$2"
    fi
}

# Usage: getval_stripped "KEY" file
# description: read a KEY=VALUE file, output the VALUE of the passed KEY stripped from any quotation
# return type: stdout string
getval_stripped() {
    val="$(getval "$1" "$2")"
    # strip double quotes
    val="$(strip_pattern "$val" "\"")"
    # strip single quotes
    val="$(strip_pattern "$val" "\'")"
    printf '%s\n' "$val"
}

# Usage: msgp "message"
# description: output a formatted message if not running on silent mode
# return type: stdout string
msgp() {
    if [ -n "$NOT_SILENT" ]; then
        printf '[%s] %s: %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "$myname" "$*"
    fi
}

# Usage: send_awesome_signal "SIGNAL" "value"
# description: emit a signal to awesome wm using awesome-client
# return type: stdout string
send_awesome_signal() {
    awesome-client "awesome.emit_signal('$1', '$2')" >/dev/null 2>&1
    msgp "emitting '$1' with value '$2'"
}

# Usage: get_def_dev "type"
# description: get the default device of given type ( sink | source )
# return type: stdout string
get_def_dev() {
    pactl "get-default-${1}"
}

cleanup() {
    if [ -r "$STATE_FILE" ]; then
        rm -f -- "$STATE_FILE"
    fi
}

# Usage: write_state_vars
# description: write current state vars to STATE_FILE
# return type: void
write_state_vars() {
    {
        printf '%s=%s\n' 'SINK_VOL'    "$SINK_VOL"
        printf '%s=%s\n' 'SINK_MUTE'   "$SINK_MUTE"
        printf '%s=%s\n' 'SINK_PORT'   "$SINK_PORT"
        printf '%s=%s\n' 'SOURCE_VOL'  "$SOURCE_VOL"
        printf '%s=%s\n' 'SOURCE_MUTE' "$SOURCE_MUTE"
        printf '%s=%s\n' 'SOURCE_PORT' "$SOURCE_PORT"
    } > "$STATE_FILE"
}

# Usage: load_state_vars
# description: load state vars from STATE_FILE
# return type: void
load_state_vars() {
    SINK_VOL="$(getval    'SINK_VOL'    "$STATE_FILE")"
    SINK_MUTE="$(getval   'SINK_MUTE'   "$STATE_FILE")"
    SINK_PORT="$(getval   'SINK_PORT'   "$STATE_FILE")"
    SOURCE_VOL="$(getval  'SOURCE_VOL'  "$STATE_FILE")"
    SOURCE_MUTE="$(getval 'SOURCE_MUTE' "$STATE_FILE")"
    SOURCE_PORT="$(getval 'SOURCE_PORT' "$STATE_FILE")"
}

# Usage: update_device_state "type"
# description: Queries and streams changes for a device type (sink | source)
# return type: stdout string
update_device_state() {
    type="$1"       # "sink" or "source"

    # Get current default device name
    def_dev=$(get_def_dev "$type")
    [ -z "$def_dev" ] && return

    # Parse specific device characteristics
    in_device=0
    cur_vol=""
    cur_mute=""
    cur_port=""

    pactl list "${type}s" | {
        changed=0
        while read -r line; do
            case "$line" in
                Name:*)
                    if [ "${line#*: }" = "$def_dev" ]; then
                        in_device=1
                    else
                        in_device=0
                    fi
                    ;;
            esac

            if [ "$in_device" -eq 1 ]; then
                case "$line" in
                    "Volume:"*)
                        # get values from Volume: key
                        vol=${line#*" "}
                        # trim text before volume percentage
                        vol=${vol#*/}
                        # trim text after percentage sign
                        vol=${vol%%\%*}
                        # trim all preceeding whitespace
                        vol=${vol##*" "}
                        cur_vol=$vol
                        ;;
                    "Mute:"*)
                        cur_mute=${line#*: }
                        ;;
                    "Active Port:"*)
                        cur_port=${line#*: }
                        ;;
                esac
            fi
        done

        load_state_vars
        # Conditionally emit changed values
        if [ "$type" = "sink" ]; then
            if [ "$cur_vol" != "$SINK_VOL" ] && [ -n "$cur_vol" ]; then
                send_awesome_signal "$SIG_VOL_SINK" "$cur_vol"
                SINK_VOL="$cur_vol"
                changed=1
            fi
            if [ "$cur_mute" != "$SINK_MUTE" ] && [ -n "$cur_mute" ]; then
                send_awesome_signal "$SIG_MUTE_SINK" "$cur_mute"
                SINK_MUTE="$cur_mute"
                changed=1
            fi
            if [ "$cur_port" != "$SINK_PORT" ] && [ -n "$cur_port" ]; then
                send_awesome_signal "$SIG_PORT_SINK" "$cur_port"
                SINK_PORT="$cur_port"
                changed=1
            fi
        elif [ "$type" = "source" ]; then
            if [ "$cur_vol" != "$SOURCE_VOL" ] && [ -n "$cur_vol" ]; then
                send_awesome_signal "$SIG_VOL_SOURCE" "$cur_vol"
                SOURCE_VOL="$cur_vol"
                changed=1
            fi
            if [ "$cur_mute" != "$SOURCE_MUTE" ] && [ -n "$cur_mute" ]; then
                send_awesome_signal "$SIG_MUTE_SOURCE" "$cur_mute"
                SOURCE_MUTE="$cur_mute"
                changed=1
            fi
            if [ "$cur_port" != "$SOURCE_PORT" ] && [ -n "$cur_port" ]; then
                send_awesome_signal "$SIG_PORT_SOURCE" "$cur_port"
                SOURCE_PORT="$cur_port"
                changed=1
            fi
        fi
        if [ "$changed" -eq 1 ]; then
            write_state_vars
        fi
    }
}

update_all() {
    update_device_state "sink"
    update_device_state "source"
}

main() {
    pactl --client-name="$client_name" subscribe 2>/dev/null | \
    grep --line-buffered --extended-regexp "Event 'change' on (sink|source) #" | \
    while read -r event; do
        msgp "updating on event $event"
        update_all
    done
}

trap cleanup EXIT INT TERM HUP

NOT_SILENT="$(getval 'NOT_SILENT' "$CONFIG")"

write_state_vars

# Run an initial bootstrap pass
update_all

main
