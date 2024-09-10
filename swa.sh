#!/usr/bin/env bash
# shellcheck disable=SC2004,SC2317,SC2053

## Author: Tommy Miland (@tmiland) - Copyright (c) 2024


######################################################################
####                           swa.sh                             ####
####            Script to get NOAA Space Weather Alerts           ####
####    Get NOAA Space Weather alerts straight to your desktop    ####
####                   Maintained by @tmiland                     ####
######################################################################

# VERSION='1.0.0' # Must stay on line 14 for updater to fetch the numbers

#------------------------------------------------------------------------------#
#
# MIT License
#
# Copyright (c) 2024 Tommy Miland
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
# Symlink: ln -sfn ~/.scripts/swa.sh ~/.local/bin/swa
## For debugging purpose
if [[ $* =~ "debug" ]]
then
  set -o errexit
  set -o pipefail
  set -o nounset
  set -o xtrace
fi
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
swa_tmp=$swa_folder/swa_tmp.json
# swa alert file (json converted)
swa_alert=$swa_folder/swa_alert.json

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
    alert_issue_time=$(alert $msg_num | grep "Issue Time:" | sed "s|Issue Time: ||g")
    local_alert_issue_time=$(cat "$swa_alert" | grep "Issue Time:" | sed "s|Issue Time: ||g")
    # If Issue Time is newer than local Issue Time
    if [[ "$local_alert_issue_time" != "$alert_issue_time" ]]
    then
      # Then run script
      alert $msg_num > "$swa_alert"
      # Get NOAA scale
      noaa_scale1=$(cat "$swa_alert"  | grep -Po "NOAA Scale: [A-z].*[0-9]" | grep -Po "[A-z][0-9]")
      noaa_scale2=$(cat "$swa_alert" | grep -Po "WATCH: [A-z].*[0-9]" | grep -Po "[A-z][0-9]")
      noaa_k_index=$(cat "$swa_alert" | grep -Po "K-index of .*[0-9]" | grep -Po "[0-9]")
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
      # Generate images used in notification
      noaa_scale_img="$swa_folder/assets/new/$noaa_scale.png"
      # Alert title
      alert_title=$(cat "$swa_alert" | grep "WATCH:" | sed "s|WATCH: ||g")
      # Alert message
      alert_message=$(cat "$swa_alert")
      # Print alert
      echo "$alert_title"
      printf "\n"
      echo "$alert_message"
      # Send notification to desktop
      notify-send --category=$scale --icon=$noaa_scale_img "Space Weather Alert" "$alert_message\n$alert_title"
    else
      echo "No new alerts. Waiting $duration seconds for new alerts..."
    fi
    sleep $duration # request alert once / minute.
  done # End of forever loop
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
