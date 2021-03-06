#!/bin/bash

# --- jss variables --- #

# indexed from 4

value=""

if [ "$4" != "" ] && [ "$value" == "" ]; then
	value=$4
fi

# --- function(s) --- #

function copyLogToDesktop() {

  if [ -z "$1" ]; then
    echo "copyLogToDesktop => [exit 1] no argument passed"; exit 1
  fi

  local log_file; log_file="$1"

  if [ ! -e "$log_file" ]; then
    echo "copyLogToDesktop => [exit 1] no file at $log_file"; exit 1
  fi

  local basename; basename=$(/usr/bin/basename "$log_file")

  if [ -z "$basename" ]; then
    echo "copyLogToDesktop => [exit 1] no valid basename"; exit 1
  fi

  local current_user; current_user=$(stat -f "%Su" /dev/console)
  local desktop_file; desktop_file="/Users/$current_user/Desktop/$basename"

  echo "copyLogToDesktop: copying '$log_file' to '$desktop_file'"
  /bin/cp "$log_file" "$desktop_file"

  if [ ! -e "$desktop_file" ]; then
    echo "copyLogToDesktop => [exit 1] copy failed, no copy at '$desktop_file'"; exit 1
  fi

  /usr/sbin/chown "$current_user" "$desktop_file"
  chmod 644 "$desktop_file"

  check_owner=$(stat -f "%Su" "$desktop_file")

  if [ "$check_owner" != "$current_user" ]; then
    echo "copyLogToDesktop [exit 1] '$desktop_file' owner == $check_owner"
  fi

  check_permission=$(stat -f "%A %a" "$desktop_file" | cut -d' ' -f1)

  if [ "$check_permission" != 644 ]; then
    echo "copyLogToDesktop [exit 1] '$desktop_file' permission == $check_permission"
  fi

  if [ -e "$desktop_file" ]; then
    echo "copyLogToDesktop: copied '$log_file' to '$desktop_file'"
  fi
}

# exit early if application is open
function exitIfOpen() {

  if [ -z "$1" ]; then
    echo "exitIfOpen => [return] no argument passed"; return
  fi

  local target; target="$1"
  local check; check=$(pgrep -f "$target")

  if [ "$check" != "" ]; then
    echo "exitIfOpen => [exit 1] $target is open."; exit 1
  fi
}

function defaultsWrite() {
  if [ -z "$1" ]; then
    echo "plistWrite => [exit 1] no plist argument passed"; exit 1
  fi

  if [ -z "$2" ]; then
    echo "plistWrite => [exit 1] no key argument passed"; exit 1
  fi

  if [ -z "$3" ]; then
    echo "plistWrite => [exit 1] no value argument passed"; exit 1
  fi

  local plist; plist="$1"
  local key; key="$2"
  local value; value="$3"

  echo "plistWrite: checking the initial value for '$key' in '$plist'"

  local defaults; defaults="/usr/bin/defaults"
  local pbuddy; pbuddy="/usr/libexec/PlistBuddy"

  local init_value; init_value=$($pbuddy -c print ":$key" "$plist")
  echo "plistWrite: initial value is '$init_value' for '$key' in '$plist'"; 

  echo "plistWrite: writing value '$value' for '$key' in '$plist'"; 
  $defaults write "$plist" "$key" "$value"

  local final_value; final_value=$($pbuddy -c print ":$key" "$plist")

  if [ "$value" == "$final_value" ]; then
    echo "plistWrite: confirmed '$value' for '$key' in '$plist'"; exit 1
  else
    echo "plistWrite => [exit 1] '$value' != '$final_value'"; exit 1
  fi
}

# remove an application from /Applications
function rmApp() {

  if [ -z "$1" ]; then
    echo "rmApp => [return] no argument passed"; return
  fi

  local app; app="$1"
  local path_to_app; path_to_app="/Applications/$app.app"

  if [ ! -d "$path_to_app" ]; then
    echo "rmApplication => [return] nothing at $path_to_app"; return
  fi

  echo "rmApplication: removing '$app' at '$path_to_app'"

  /bin/rm -rf "$path_to_app"

  if [ ! -d "$path_to_app" ]; then
    echo "rmApplication: removed '$1' from '$path_to_app'"
  else
    echo "rmApplication => [exit 1] '$path_to_app' shouldn't exist"; exit 1
  fi
}

# remove a directory
function rmDir() {

  if [ -z "$1" ]; then
    echo "rmDir => [return] no argument passed"; return
  fi

  local path_to_dir; path_to_dir="$1"

  if [ ! -d "$path_to_dir" ]; then
    echo "rmDir => [return] nothing at '$path_to_dir'"; return
  fi

  echo "rmDir: removing '$path_to_dir'"
  /bin/rm -rf "$path_to_dir"

  if [ ! -d "$path_to_dir" ]; then
    echo "rmDir: removed '$path_to_dir'"
  else
    echo "rmDir => [exit 1] '$path_to_dir' shouldn't exist"
  fi
}

# remove a file
function rmFile() {

  if [ -z "$1" ]; then
    echo "rmFile => [return] no argument passed"; return
  fi

  local path_to_file; path_to_file="$1"

  if [ ! -e "$path_to_file" ]; then
    echo "rmFile => [return] nothing at $path_to_file"; return
  fi

  if [ -d "$path_to_file" ]; then
    echo "rmFile => [return] expected file, found directory"; return
  fi

  echo "rmFile: removing '$path_to_file'"

  /bin/rm "$path_to_file"

  if [ ! -e "$path_to_file" ]; then
    echo "rmFile: removed '$path_to_file'"
  else
    echo "rmFile => [exit 1] '$path_to_file' shouldn't exist"; exit 1
  fi
}

# toggle load/unload with launchctl
function toggleLaunchctl() {

  if [ -z "$1" ]; then
    echo "toggleLaunchctl => [return] no argument passed"; return
  fi

  local target; target="$1"
  check=$(/bin/launchctl list | grep "$target")

  if [ "$check" != "" ]; then
    /bin/launchctl unload "$target"
  fi
  /bin/launchctl load "$target" 

  check=$(/bin/launchctl list | grep "$target")

  if [ "$check" != "" ]; then
    echo "toggleLaunchctl: toggled '$target'"
  fi
  echo "toggleLaunchctl => [exit 1] toggled '$target' - not active"; exit 1
}

# verify that an application is closed
function verifyClosed() {

  if [ -z "$1" ]; then
    echo "verifyClosed => [return] no argument passed"; return
  fi

  local target; target="$1"
  check=$(/usr/bin/pgrep -f "$target")

  if [ "$check" == "" ]; then
    echo "verifyClosed => [return] '$target' is not running"; return
  fi

  echo "verifyClosed: closing '$target'"

  /usr/bin/killall "$target"

  check=$(/usr/bin/pgrep -f "$target")

  if [ "$check" == "" ]; then
    echo "verifyClosed: closed '$target'"
  else
    echo "verifyClosed => [exit 1] can't close $target'"; exit 1
  fi
}

# verify org directories and their ownership/permissions
function verifyOrgDirs() {

  if [ -z "$1" ]; then
    echo "verifyClosed => [return] no argument passed"; return
  fi

  local org; org="$1"

  org_scripts="/usr/local/$org/scripts"
  org_logs="/usr/local/$org/logs"
  org_private="/usr/local/$org/private"

  if [ ! -d "$org_scripts" ]; then
    echo "verifyOrgDirs: creating '$org_scripts'"; mkdir -p "$org_scripts"
  fi

  if [ ! -d "$org_logs" ]; then
    echo "verifyOrgDirs: creating '$org_logs'"; mkdir -p "$org_logs"
  fi

  if [ ! -d "$org_private" ]; then
    echo "verifyOrgDirs: creating '$org_private'"; mkdir -p "$org_private"
  fi

  echo "verifyOrgDirs: verifying permissions and ownership for '/usr/local/$org'"
  /usr/sbin/chown root:wheel "/usr/local/$org"
  /bin/chmod 0444 "/usr/local/$org"

  check_owner=$(stat -f "%Su" "/usr/local/$org/")

  if [ "$check_owner" != "root" ]; then
    echo "verifyOrgDirs [exit 1] '/usr/local/$org' owner == $check_owner"
  fi

  check_permission=$(stat -f "%A %a" "/usr/local/$org" | cut -d' ' -f1)

  if [ "$check_permission" != 444 ]; then
    echo "verifyOrgDirs [exit 1] '/usr/local/$org' permission == $check_permission"
  fi

  echo "verifyOrgDirs: verified permissions and ownership for '/usr/local/$org'"
}

# --- command variables --- #

computer_name=$(scutil --get ComputerName)

current_user=$(stat -f "%Su" /dev/console)

scutil_dns=$(scutil --dns)

external_ip=$(dig +short myip.opendns.com @resolver1.opendns.com)

internal_ip=$(ipconfig getifaddr en0)

now=$(date +"%D %T")

serial_number=$(system_profiler SPHardwareDataType | grep 'Serial Number (system)' | awk '{print $NF}')

wifi_mac=$(ifconfig en0 | awk '/ether/{print $2}')

wireless_device=$(/usr/sbin/networksetup -listallhardwareports | /usr/bin/grep -E -A2 'Airport|Wi-Fi' | /usr/bin/awk '/Device/ { print $2 }')

# --- tests --- #

function echoVariables() {
  echo "computer name: $computer_name"
  echo "current user: $current_user"
  echo "scutil dns: $scutil_dns" 
  echo "external IP: $external_ip" 
  echo "internal IP: $internal_ip" 
  echo "now: $now" 
  echo "serial number: $serial_number" 
  echo "wifi MAC: $wifi_mac" 
  echo "wireless device: $wireless_device" 
}

function fileTests() {
  local org; org="jychri"
  local current_user; current_user=$(stat -f "%Su" /dev/console)
	local desktop; desktop="/Users/$current_user/Desktop"

  snippets_test_file="$desktop/snippets-test-file"
  snippets_test_dir="$desktop/snippets-test-dir"

  echo "fileTests: creating $snippets_test_file"
  /usr/bin/touch "$snippets_test_file"

  echo "fileTests: creating $snippets_test_dir"
  /bin/mkdir "$snippets_test_dir"

  rmFile "$snippets_test_file"
  rmDir "$snippets_test_dir"
}

function workspace() {
  verifyOrgDirs jychri
}

echo -e "1 => echo variables"
echo -e "2 => file tests"
echo -e "3 => workspace"
read -r user_input
case "$user_input" in

1)
  echoVariables
;;

2)
  fileTests
;;

3)
  workspace
;;

esac
