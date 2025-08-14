#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2025


######################################################################
####                   space weather alerts.sh                    ####
####            Script to get NOAA Space Weather Alerts           ####
####    Get NOAA Space Weather alerts straight to your desktop    ####
####                   Maintained by @tmiland                     ####
######################################################################

VERSION='1.0.2'

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2025 Tommy Miland
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#------------------------------------------------------------------------------#
# Symlink: ln -sfn ~/.scripts/space_weather_alerts.sh ~/.local/bin/space_weather_alerts
## For debugging purpose
if [[ $* =~ "debug" ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
# Get local timezone
timezone=$(< /etc/timezone)
date=$(TZ="$timezone" date)
# Default duration (1 minute) to wait for new alerts
duration=1
# Default message to retrieve (0 is last)
msg_num=0
# URL to json alerts file
swa_url=https://services.swpc.noaa.gov/products/alerts.json
# Default folder
swa_folder=$HOME/.space_weather_alerts
# Create folder if it doesn't exist
if [[ ! -d "$swa_folder" ]]
then
  mkdir -p "$swa_folder"
fi
# swa tmp file
swa_tmp=$swa_folder/space_weather_alerts_tmp.json
# swa alert file (json converted)
swa_alert=$swa_folder/space_weather_alerts_alert.json
# json function
json() {
  # Run curl to tmp file
  curl -s $swa_url 2>/dev/null > "$swa_tmp" &&
  jq -r '.['"$1"'] | "\(.'"$2"')- \(.'"$3"')- \(.'"$4"')"' "$swa_tmp"
}
# Alert function
alert() {
  json "$1" product_id issue_datetime message
}
# Calculate seconds to minutes
duration=$(( duration * 60 ))

# Auto run function
auto-run() {
  while true
  do
    # Alert variables used for comparison
    alert_serial_number=$(alert $msg_num | grep "Serial Number:" | sed "s|Serial Number: ||g")
    local_alert_serial_number=$(grep "Serial Number:" "$swa_alert" | sed "s|Serial Number: ||g")
    # If Issue Time is newer than local Issue Time
    if [[ "$local_alert_serial_number" != "$alert_serial_number" ]]
    then
      # Then run script
      alert $msg_num > "$swa_alert"
      # Get NOAA scale
      noaa_scale1=$(grep -Po "NOAA Scale: [A-z].*[0-9]" "$swa_alert" | grep -Po "[A-z][0-9]")
      noaa_scale2=$(grep -Po "WATCH: [A-z].*[0-9]" "$swa_alert" | grep -Po "[A-z][0-9]")
      noaa_k_index=$(grep -Po "K-index of .*[0-9]" "$swa_alert" | grep -Po "[0-9]")
      noaa_radio_emission=$(grep -Po "Type (I|II|III|IV|V|VI|VII|VIII|IX) Radio Emission" "$swa_alert")
      # Switch based on noaa scale
      if [[ -n $noaa_scale1 ]]
      then
        noaa_scale=$noaa_scale1
      elif [[ -n $noaa_scale2 ]]
      then
        noaa_scale=$noaa_scale2
      elif [[ -z $noaa_scale1 ]] || [[ -z $noaa_scale2 ]]
      then
        if [[ -n $noaa_k_index ]]
        then
          noaa_scale=$noaa_k_index
        fi
      fi
      # Case for noaa scale
      case $noaa_scale in
        G5|S5|R5)
          scale=Extreme
          ;;
        G4|S4|R4)
          scale=Severe
          ;;
        G3|S3|R3)
          scale=Strong
          ;;
        G2|S2|R2)
          scale=Moderate
          ;;
        G1|S1|R1)
          scale=Minor
          ;;
        1)
          scale=none
          noaa_scale=G
          ;;
        2)
          scale=none
          noaa_scale=G
          ;;
        3)
          scale=none
          noaa_scale=G
          ;;
        4)
          scale=none
          noaa_scale=G
          ;;
        5)
          scale=Minor
          noaa_scale=G1
          ;;
        6)
          scale=Moderate
          noaa_scale=G2
          ;;
        7)
          scale=Strong
          noaa_scale=G3
          ;;
        8|9-)
          scale=Severe
          noaa_scale=G4
          ;;
        9o)
          scale=Extreme
          noaa_scale=G5
          ;;
      esac
      # noaa radio emission
      if [[ $noaa_radio_emission =~ "Type I Radio Emission" ]]
      then
        noaa_scale=R1
      elif [[ $noaa_radio_emission =~ "Type II Radio Emission" ]]
      then
        noaa_scale=R2
      elif [[ $noaa_radio_emission =~ "Type III Radio Emission" ]]
      then
        noaa_scale=R3
      elif [[ $noaa_radio_emission =~ "Type IV Radio Emission" ]]
      then
        noaa_scale=R4
      elif [[ $noaa_radio_emission =~ "Type V Radio Emission" ]]
      then
        noaa_scale=R5
      fi
      if [[ $(command -v 'timedatectl') ]]
      then
        date=$(timedatectl | grep "Local time" | tr -s ' ')
      fi
      # Get time function
      get_time() {
        grep "$1" "$swa_alert"
      }
      # Get Valid From in pieces
      valid_from_month=$(get_time "Valid From" | cut -d ' ' -f4)
      valid_from_day=$(get_time "Valid From" | cut -d ' ' -f5)
      valid_from_year=$(get_time "Valid From" | cut -d ' ' -f3)
      valid_from_time=$(get_time "Valid From" | cut -d ' ' -f6)
      # Put Valid From pieces together
      valid_from=$(echo "$valid_from_month" "$valid_from_day", "$valid_from_year" "$valid_from_time")
      # Get Valid To in pieces
      valid_to_month=$(get_time "Valid To" | cut -d ' ' -f4)
      valid_to_day=$(get_time "Valid To" | cut -d ' ' -f5)
      valid_to_year=$(get_time "Valid To" | cut -d ' ' -f3)
      valid_to_time=$(get_time "Valid To" | cut -d ' ' -f6)
      # Put Valid To pieces together
      valid_to=$(echo "$valid_to_month" "$valid_to_day", "$valid_to_year" "$valid_to_time")
      # Get issue time in pieces
      issue_time_month=$(get_time "Issue Time" | cut -d ' ' -f4)
      issue_time_day=$(get_time "Issue Time" | cut -d ' ' -f5)
      issue_time_year=$(get_time "Issue Time" | cut -d ' ' -f3)
      issue_time_time=$(get_time "Issue Time" | cut -d ' ' -f6)
      # Put issue time pieces together
      issue_time=$(echo "$issue_time_month" "$issue_time_day", "$issue_time_year" "$issue_time_time")
      # Get Now Valid Until in pieces
      now_valid_until_month=$(get_time "Now Valid Until" | cut -d ' ' -f5)
      now_valid_until_day=$(get_time "Now Valid Until" | cut -d ' ' -f6)
      now_valid_until_year=$(get_time "Now Valid Until" | cut -d ' ' -f4)
      now_valid_until_time=$(get_time "Now Valid Until" | cut -d ' ' -f7)
      # Put Now Valid Until pieces together
      now_valid_until=$(echo "$now_valid_until_month" "$now_valid_until_day", "$now_valid_until_year" "$now_valid_until_time")
      # Get Threshold Reached in pieces
      threshold_reached_month=$(get_time "Threshold Reached" | sed 's/^ *//g' | cut -d ' ' -f4)
      threshold_reached_day=$(get_time "Threshold Reached" | sed 's/^ *//g' | cut -d ' ' -f5)
      threshold_reached_year=$(get_time "Threshold Reached" | sed 's/^ *//g' | cut -d ' ' -f3)
      threshold_reached_time=$(get_time "Threshold Reached" | sed 's/^ *//g' | cut -d ' ' -f6)
      # Put Threshold Reached pieces together
      threshold_reached=$(echo "$threshold_reached_month" "$threshold_reached_day", "$threshold_reached_year" "$threshold_reached_time")
      # Get Begin Time in pieces
      begin_time_month=$(get_time "Begin Time" | sed 's/^ *//g' | cut -d ' ' -f4)
      begin_time_day=$(get_time "Begin Time" | sed 's/^ *//g' | cut -d ' ' -f5)
      begin_time_year=$(get_time "Begin Time" | sed 's/^ *//g' | cut -d ' ' -f3)
      begin_time_time=$(get_time "Begin Time" | sed 's/^ *//g' | cut -d ' ' -f6)
      # Put Begin Time pieces together
      begin_time=$(echo "$begin_time_month" "$begin_time_day", "$begin_time_year" "$begin_time_time")
      # Get Maximum Time in pieces
      maximum_time_month=$(get_time "Maximum Time" | sed 's/^ *//g' | cut -d ' ' -f4)
      maximum_time_day=$(get_time "Maximum Time" | sed 's/^ *//g' | cut -d ' ' -f5)
      maximum_time_year=$(get_time "Maximum Time" | sed 's/^ *//g' | cut -d ' ' -f3)
      maximum_time_time=$(get_time "Maximum Time" | sed 's/^ *//g' | cut -d ' ' -f6)
      # Put Maximum Time pieces together
      maximum_time=$(echo "$maximum_time_month" "$maximum_time_day", "$maximum_time_year" "$maximum_time_time")
      # Get End Time in pieces
      end_time_month=$(get_time "End Time" | sed 's/^ *//g' | cut -d ' ' -f4)
      end_time_day=$(get_time "End Time" | sed 's/^ *//g' | cut -d ' ' -f5)
      end_time_year=$(get_time "End Time" | sed 's/^ *//g' | cut -d ' ' -f3)
      end_time_time=$(get_time "End Time" | sed 's/^ *//g' | cut -d ' ' -f6)
      # Put End Time pieces together
      end_time=$(echo "$end_time_month" "$end_time_day", "$end_time_year" "$end_time_time")
      # Convert times to local timezone
      if [[ -n "$valid_from_month" ]]
      then
        new_valid_from=$(TZ="$timezone" date -d "$valid_from" +"%Y %b %d %H%M %Z")
        sed -i "s|Valid From: .*|Valid From: $new_valid_from|g" "$swa_alert"
      fi
      if [[ -n "$valid_to_month" ]]
      then
        new_valid_to=$(TZ="$timezone" date -d "$valid_to" +"%Y %b %d %H%M %Z")
        sed -i "s|Valid To: .*|Valid To: $new_valid_to|g" "$swa_alert"
      fi
      if [[ -n "$issue_time_month" ]]
      then
        new_issue_time=$(TZ="$timezone" date -d "$issue_time" +"%Y %b %d %H%M %Z")
        sed -i "s|Issue Time: .*|Issue Time: $new_issue_time|g" "$swa_alert"
      fi
      if [[ -n "$now_valid_until_month" ]]
      then
        new_now_valid_until=$(TZ="$timezone" date -d "$now_valid_until" +"%Y %b %d %H%M %Z")
        sed -i "s|Now Valid Until: .*|Now Valid Until: $new_now_valid_until|g" "$swa_alert"
      fi
      if [[ -n "$threshold_reached_month" ]]
      then
        new_threshold_reached=$(TZ="$timezone" date -d "$threshold_reached" +"%Y %b %d %H%M %Z")
        sed -i "s|Threshold Reached: .*|Threshold Reached: $new_threshold_reached|g" "$swa_alert"
      fi
      if [[ -n "$begin_time_month" ]]
      then
        new_begin_time=$(TZ="$timezone" date -d "$begin_time" +"%Y %b %d %H%M %Z")
        sed -i "s|Begin Time: .*|Begin Time: $new_begin_time|g" "$swa_alert"
      fi
      if [[ -n "$maximum_time_month" ]]
      then
        new_maximum_time=$(TZ="$timezone" date -d "$maximum_time" +"%Y %b %d %H%M %Z")
        sed -i "s|Maximum Time: .*|Maximum Time: $new_maximum_time|g" "$swa_alert"
      fi
      if [[ -n "$end_time_month" ]]
      then
        new_end_time=$(TZ="$timezone" date -d "$end_time" +"%Y %b %d %H%M %Z")
        sed -i "s|End Time: .*|End Time: $new_end_time|g" "$swa_alert"
      fi
      # Add received time to msg
      sed -i "/Issue Time: /a Received $date" "$swa_alert"
      # Generate images used in notification
      noaa_scale_img="$swa_folder/assets/new/$noaa_scale.png"
      # Alert title
      alert_title=$(grep "WATCH:" "$swa_alert" | sed "s|WATCH: ||g")
      # Alert message
      alert_message=$(< "$swa_alert")
      # Print alert
      echo "$alert_title"
      printf "\n"
      echo "$alert_message"
      # Send notification to desktop
      notify-send --app-name="Space Weather Alert" --category=$scale --icon=$noaa_scale_img "Space Weather Alert" "$alert_message\n$alert_title"
    else
      echo "No new alerts. Waiting $duration seconds for new alerts..."
    fi
    sleep $duration # request alert once / minute.
  done # End of forever loop
}

install() {
  echo "Cloning files to $swa_folder..."
  if [[ $(command -v 'git') ]]; then
    git clone https://github.com/tmiland/space-weather-alerts.git "$swa_folder" >/dev/null 2>&1
  else
    echo -e "This script requires git.\nProcess aborted"
    exit 0
  fi
  chmod +x "$swa_folder"/space_weather_alerts.sh
  sudo ln -sfn "$swa_folder"/space_weather_alerts.sh /usr/local/bin/space_weather_alerts
  echo "Enabling systemd service"
  if ! [[ -d "$HOME"/.config/systemd/user ]]
  then
    mkdir -p "$HOME"/.config/systemd/user
  fi
  cp -rp  "$swa_folder"/space_weather_alerts.service "$HOME"/.config/systemd/user/space_weather_alerts.service
  systemctl --user enable space_weather_alerts.service >/dev/null 2>&1
  systemctl --user start space_weather_alerts.service
  systemctl --user status space_weather_alerts.service
  echo "Done."
}

uninstall() {
  if [ -d "$swa_folder" ]
  then
    echo "Removing files in $swa_folder..."
    rm -rf "$swa_folder"
    sudo rm /usr/local/bin/space_weather_alerts
    echo "Disabling systemd service"
    systemctl --user disable space_weather_alerts.service >/dev/null 2>&1
    systemctl --user stop space_weather_alerts.service
    rm "$HOME"/.config/systemd/user/space_weather_alerts.service
    echo "Done."
    exit 0
  fi
}

ARGS=()
while [[ $# -gt 0 ]]
do
  case $1 in
    --help | -h)
      usage
      exit 0
      ;;
    --alert | -a)
      alert
      shift
      ;;
    --auto-run | -ar)
      auto-run
      shift
      ;;
    --install | -i)
      install
      exit 0
      ;;
    --uninstall | -u)
      uninstall
      exit 0
      ;;
    -*|--*)
      printf "Unrecognized option: $1\\n\\n"
      usage
      exit 1
      ;;
    *)
      ARGS+=("$1")
      shift
      ;;
  esac
done

set -- "${ARGS[@]}"
