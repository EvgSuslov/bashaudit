#!/bin/bash
if [ "${SHELL##*/}" != "bash" ]; then
	return
fi
if [ "$AUDIT_INCLUDED" == "$$" ] || { [ -z "$SSH_ORIGINAL_COMMAND" ] && [ "$(cat /proc/$$/cmdline)" == 'bash-c"/etc/forcecommand.sh"' ]; }; then
	return
else
	declare -rx AUDIT_INCLUDED="$$"
fi

declare -rx HISTCONTROL=""
declare -rx HISTIGNORE=""
declare -rx HISTCMD
declare -rx AUDIT_LOGINUSER="$(who -mu | awk '{print $1}')"
declare -rx AUDIN_LOGINPID="$(who -mu | awk '{print $6}')"
declare -rx AUDIT_USER="$USER"
declare -rx AUDIT_PID="$$"
declare -rx AUDIT_TTY="$(who -mu | awk '{print $2}')"
declare -rx AUDIT_SSH="$([ -n "$SSH_CONNECTION" ] && echo "$SSH_CONNECTION" | awk '{print $1":"$2"->"$3":"$4}')"
declare -rx REMOTEIP=$(who am i | awk '{print $5}' | sed "s/[()]//g" )
if [ -n "$MC_SID" ]; then declare -rx MC_PID=$(ps -p `ps -p $MC_SID -o ppid=` -o ppid=)
fi
declare -rx AUDIT_STR="[Command Audit] [SR=$REMOTEIP] [SUSER=$AUDIT_LOGINUSER/$AUDIT_LIGINPID] [QUSER=$AUDIT_USER/$AUDIT_PID] [SUDO_USER=$SUDO_USER] [MC_PID=$MC_PID] [TTY=$AUDIT_TTY/$AUDIT_SSH]"
set +o functrace

shopt -s extglob
shopt -s histappend
shopt -s cmdhist
shopt -s histverify

if shopt -q login_shell && [ -t 0 ]; then
  stty -ixon
fi

function audit_DEBUG() {
  if [ -z "$AUDIT_LASTHISTLINE" ]; then
    local AUDIT_CMD="$(fc -l -1 -1)"
    AUDIT_LASTHISTLINE="${AUDIT_CMD%%+([^ 0-9])*}"
  else
    AUDIT_LASTHISTLINE="$AUDIT_HISTLINE"
  fi
  local AUDIT_CMD="$(history 1)"
  AUDIT_HISTLINE="${AUDIT_CMD%%+([^ 0-9]*}"
  if [ "${AUDIT_HISTLINE:-0}" -ne "${AUDIT_LASTHISTLINE:-0}" ] || [ "${AUDIT_HISTLINE:-0}" -eq "1" ]; then
    echo -ne "${_backnone}${_frontgrey}"
    if ! logger -p local3.debug -t "$AUDIT_STR "[COMMAND="$PWD" "${AUDIT_CMD##*( )?(+([0-9])[^0-9])*( )}""]"; then
      echo error "$AUDIT_STR "[COMMAND="$PWD" "${AUDIT_CMD##*( )?(+([0-9])[^0-9])*( )}""]"
    fi
  else
    return 1
  fi
}

function audit_EXIT() {
  local AUDIT_STATUS="$?"
  logger -p local3.debug -t "$AUDIT_STR" "#=== bash session ended. ==="
  exit "$AUDIT_STATUS"
}

declare -frx +t audit_DEBUG
declare -frx +t audit_EXIT

logger -p local3.debug -t "$AUDIT_STR" "#=== Nes bash session started. ==="
declare -x PROMPT_COMMAND="trap 'audit_DEBUG; trap DEBUG' DEBUG"
declare -rx BASH_COMMAND
declare -rx SELLOPT
trap audit_EXIT EXIT

