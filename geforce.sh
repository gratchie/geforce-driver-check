#!/bin/bash
# git@git.lowjax.com:user/geforce-driver-check.git
# Script for checking for newer Nvidia Display Driver than the one install (x64 win7-win8)

# cutomizable defaults
DOWNLOADDIR="/cygdrive/e/Downloads" #download into this directory
DLHOST="http://us.download.nvidia.com" #use this mirror

# binary dependency array
DEPS=('PnPutil' 'wget' 'awk' 'cut' 'head' 'sed' 'wc')

# clear vars *no edit
LINK=
FILEDATA=
FILENAME=
LATESTVER=
OLDOEMINF=
CURRENTVER=
DLURI=

# error func
error() { echo "Error: $1"; exit 1; }

# ask function
ask() {
	while true; do
		if [[ "${2:-}" = "Y" ]]; then prompt="Y/n"; default=Y
		elif [[ "${2:-}" = "N" ]]; then prompt="y/N"; default=N
		else prompt="y/n"; default=;
		fi
		if [[ "$1" = "-y" ]]; then REPLY=Y; default=Y #need debug
		else echo -ne "$1 "; read -p "[$prompt] " REPLY; [[ -z "$REPLY" ]] && REPLY=$default
		fi
		case "$REPLY" in
			Y*|y*) return 0 ;; N*|n*) return 1 ;;
		esac
	done
}

# check binary dependencies
for i in "${DEPS[@]}"; do
	hash $i 2>/dev/null || error "Dependency not found :: $i"
done

# check if DOWNLOADDIR exists
[[ -d "$DOWNLOADDIR" ]] || error "Directory not found \"$DOWNLOADDIR\""

# remove unused oem*.inf packages and set OLDOEMINF from in use
REMOEMS=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/Published/ {print $4}')
if [[ $(echo "$REMOEMS" | wc -l) -gt 1 ]]; then
	for REOEM in $REMOEMS; do
		[[ $REOEM == oem*.inf ]] || error "removing in unused oem*.inf file :: $REOEM"
		PnPutil -d $REOEM >/dev/null || OLDOEMINF="$REOEM"
	done
fi

# default nvidia starting link
LINK="http://www.nvidia.com/Download/processFind.aspx?psid=95&pfid=695&osid=19&lid=1&whql=&lang=en-us"

# file data query
FILEDATA=$(wget -qO- "$(wget -qO- "$LINK" | awk '/driverResults.aspx/ {print $4}' | cut -d "'" -f2 | head -n 1)" | awk '/url=/ {print $2}' | cut -d '=' -f3 | cut -d '&' -f1)
[[ $FILEDATA == *.exe ]] || error "Unexpected FILEDATA returned :: $FILEDATA"

# store file name only
FILENAME=$(echo "$FILEDATA" | cut -d '/' -f4)
[[ $FILENAME == *.exe ]] || error "Unexpected FILENAME returned :: $FILENAME"

# store latest version
LATESTVER=$(echo "$FILEDATA" | cut -d '/' -f3 | sed -e "s/\.//")
[[ $LATESTVER =~ ^[0-9]+$ ]] || error "LATESTVER not a number :: $LATESTVER"

# store current version
CURRENTVER=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | awk '/version/ {print $7}' | cut -d '.' -f3,4 | sed -e "s/\.//" | sed -r "s/^.{1}//")
[[ $CURRENTVER =~ ^[0-9]+$ ]] || error "CURRENTVER not a number or multistring :: $CURRENTVER"

# old oem*.inf file if not already detected
[[ -z $OLDOEMINF ]] && OLDOEMINF=$(PnPutil.exe -e | grep -C 2 "Display adapters" | grep -A 3 -B 1 "NVIDIA" | grep -B 3 "$(echo "$CURRENTVER" | sed 's/./.&/2')" | awk '/Published/ {print $4}')
[[ $OLDOEMINF == oem*.inf ]] || error "Old oem*.inf file :: $OLDOEMINF"

# store full uri
DLURI="${DLHOST}${FILEDATA}"

if [[ $LATESTVER -gt $CURRENTVER ]]; then
	echo "New version available!"
	echo "Current: $CURRENTVER"
	echo -e "Latest:  $LATESTVER"
	echo "Downloading latest version into \"$DOWNLOADDIR\"...."
	cd "$DOWNLOADDIR" || error "Changing to download directory \"$DOWNLOADDIR\""
	wget -N "$DLURI" || error "Downloading file \"$DLURI\""
	ask "Install new version ($LATESTVER) now?" && 
	cygstart -w "$FILENAME" || error "Installation failed or user interupted!"
	echo "Removing old driver package..."
	PnPutil -d $OLDOEMINF >/dev/null || error "Removing old oem*.inf package (maybe in use):: $OLDOEMINF"
	exit 0
else
	echo "Already latest version: $CURRENTVER"
	exit 0
fi