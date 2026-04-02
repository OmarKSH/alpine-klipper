#!/usr/bin/env sh

# https://athemis.me/projects/klipper_guide

set -euo pipefail

select_from_list() {
	[ -x "$(command -v fzf)" ] && { fzf "$@" <&0; return $?; } \
	|| { local line i=0 REPLY
	{ [ ! -t 0 ] && while IFS= read -r line; do [ -z "$line" ] && continue; echo "$i) $line" >/dev/tty; eval "local line$i=\"$line\""; i=$((i+1)); done; true; }
	# { while IFS= read -r line; do [ -z "$line" ] && continue; echo "$i) $line" >/dev/tty; eval "local line$i=\"$line\""; i=$((i+1)); done <<- EOF
	# $(for i in "$@"; do echo "$i"; done)
	# EOF
	# }
	echo -n "Enter choice number: " >/dev/tty && read -r REPLY </dev/tty && eval "echo -n \"\${line$REPLY}\"" && echo >/dev/tty; }
}

: ${CONFIG_PATH:="$HOME/printer_data/config"}
: ${GCODE_PATH:="$HOME/printer_data/gcodes"}
: ${COMMS_PATH:="$HOME/printer_data/comms"}
: ${LOGS_PATH:="$HOME/printer_data/logs"}

: ${KLIPPER_REPO:="https://github.com/Klipper3d/klipper.git"}
: ${KLIPPER_PATH:="$HOME/klipper"}
: ${KLIPPY_VENV_PATH:="$HOME/venv/klippy"}

: ${KIAUH_REPO:="https://github.com/dw-0/kiauh"}
: ${KIAUH_PATH:="$HOME/kiauh"}

: ${KAMP_REPO:="https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging"}
: ${KAMP_PATH:="$HOME/KAMP"}

: ${MOONRAKER_REPO:="https://github.com/Arksine/moonraker"}
: ${MOONRAKER_PATH:="$HOME/moonraker"}
: ${MOONRAKER_VENV_PATH:="$HOME/venv/moonraker"}

: ${CLIENTS_DIR:="$HOME"}
: ${CLIENT_PATH:="$CLIENTS_DIR/www"}

: ${FLUIDD_REPO:="fluidd-core/fluidd"}
: ${FLUIDD_PATH="$CLIENTS_DIR/fluidd"}

: ${MAINSAIL_REPO:="mainsail-crew/mainsail"}
: ${MAINSAIL_PATH="$CLIENTS_DIR/mainsail"}

: ${LASERWEB4_REPO:="https://github.com/ssendev/LaserWeb4"}
: ${LASERWEB4_PATH="$CLIENTS_DIR/laserweb4"}

# : ${E3V3SE_display_klipper_REPO:="https://github.com/jpcurti/E3V3SE_display_klipper"}
# : ${E3V3SE_display_klipper_PATH:="$HOME/e3v3se_display_klipper"}
# : ${E3V3SE_display_klipper_VENV_PATH:="$HOME/venv/e3v3se_display_klipper"}

: ${KLIPPERSCREEN_REPO:="https://github.com/KlipperScreen/KlipperScreen"}
: ${KLIPPERSCREEN_PATH:="$HOME/KlipperScreen"}
: ${KLIPPERSCREEN_VENV_PATH:="$HOME/venv/KlipperScreen"}

[ ! -e /sbin/openrc -o -e /run/openrc/softlevel ] && VIRTUAL=true || VIRTUAL=false

if [ $(id -u) = 0 ]; then
	echo "This script must not run as root"
	$VIRTUAL || exit 1
	USER=root
fi

command -v sudo >>/dev/null || { command -v doas >>/dev/null && alias sudo=doas; } || alias sudo=

$VIRTUAL && sudo apk add openrc wayvnc && { sudo mkdir -p /run/openrc; sudo touch /run/openrc/softlevel; } #&& sudo openrc boot

################################################################################
# PRE
################################################################################

# [ -z "${INSTALL_E3V3SE_DISPLAY+x}" ] \
# 	&& echo -n "Install E3V3SE_display_klipper? (y/N): " \
# 	&& read -r INSTALL_E3V3SE_DISPLAY \
# 	&& echo

[ -z "${UI_CHOICE+x}" ] \
	&& echo "Select the UI to be installed:" \
	&& UI_CHOICE="$(printf "KlipperScreen\nSway\nCage\nNone\n" | select_from_list)"

[ -z "${INSTALL_ARM_COMPILER+x}" ] \
	&& echo -n "Install ARM GCC? (y/N): " \
	&& read -r REPLY \
	&& echo
	&& { [ "$REPLY" = 'y' -o "$REPLY" = 'Y' ] && sudo apk add make gcc-arm-none-eabi newlib-arm-none-eabi; }

[ -z "${INSTALL_AVR_COMPILER+x}" ] \
	&& echo -n "Install AVR GCC? (y/N): " \
	&& read -r REPLY \
	&& echo
	&& { [ "$REPLY" = 'y' -o "$REPLY" = 'Y' ] && sudo apk add make gcc-avr avr-libc; }

sudo apk add sudo git python3 build-base python3-dev #libffi-dev #freetype-dev fribidi-dev harfbuzz-dev jpeg-dev lcms2-dev openjpeg-dev tcl-dev tiff-dev tk-dev zlib-dev
#sudo sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
#sudo sh -c 'echo "permit nopass $USER as root cmd apk" >> /etc/doas.d/99-$USER-klipper.conf'
#sudo sh -c 'echo "permit nopass $USER as root cmd poweroff" >> /etc/doas.d/99-$USER-klipper.conf'
#sudo sh -c 'echo "permit nopass $USER as root cmd reboot" >> /etc/doas.d/99-$USER-klipper.conf'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/apk" >> /etc/sudoers.d/99-$USER'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/poweroff" >> /etc/sudoers.d/99-$USER'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/reboot" >> /etc/sudoers.d/99-$USER'

[ -d /etc/udev/rules.d ] && echo 'SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power", RUN+="/bin/chmod 664 /sys/class/backlight/%k/brightness /sys/class/backlight/%k/bl_power"' | sudo tee /etc/udev/rules.d/backlight-permissions.rules >/dev/null

[ -e /etc/mdev.conf ] \
	&& MDEV_BACKLIGHT_CMD='backlight[0-9]* 0:video 664 @/bin/chgrp video /sys/class/backlight/$MDEV/brightness /sys/class/backlight/$MDEV/bl_power && /bin/chmod 664 /sys/class/backlight/$MDEV/brightness /sys/class/backlight/$MDEV/bl_power' \
	&& ! grep -F "$MDEV_BACKLIGHT_CMD" /etc/mdev.conf >/dev/null \
	&& printf "\n#Backlight permissions for klipper\n$MDEV_BACKLIGHT_CMD\n" | sudo tee -a /etc/mdev.conf >/dev/null

[ -e /etc/init.d ] || sudo mkdir -p /etc/init.d

[ -e "$CONFIG_PATH" ] || mkdir -p "$CONFIG_PATH"
[ -e "$GCODE_PATH" ] || ln -s /tmp "$GCODE_PATH"
[ -e "$COMMS_PATH" ] || ln -s /tmp "$COMMS_PATH"
[ -e "$LOGS_PATH" ] || ln -s /tmp "$LOGS_PATH"

################################################################################
# KLIPPER
################################################################################

sudo apk add libffi-dev

test -d $KLIPPER_PATH || git clone --depth=1 $KLIPPER_REPO $KLIPPER_PATH

#echo 'choose printer config:'
#sleep 1
#selection="$(ls "$KLIPPER_PATH/config" | select_from_list)"
#cp -i "$KLIPPER_PATH/config/$selection" "$CONFIG_PATH/printer.cfg"
touch "$CONFIG_PATH/printer.cfg"

ln -s "$KLIPPER_PATH/config/sample-pwm-tool.cfg" "$CONFIG_PATH"
ln -s "$KLIPPER_PATH/config/sample-macros.cfg" "$CONFIG_PATH"

sudo tee >/dev/null "$CONFIG_PATH/backlight_control.cfg" <<'EOF'
[gcode_shell_command set_display_brightness]
command: sh -c "find -L /sys/class/backlight -maxdepth 2 -type f -name brightness -exec sh -c 'echo $2 > $1' _ {} $0 \;"
timeout: 2.
verbose: True

[gcode_shell_command set_display_backlight_power]
command: sh -c "find -L /sys/class/backlight -maxdepth 2 -type f -name bl_power -exec sh -c 'echo $2 > $1' _ {} $0 \;"
timeout: 2.
verbose: True

[gcode_macro SCREEN_BRIGHTNESS]
gcode:
	{% set BRIGHTNESS = params.BRIGHTNESS|default(127)|int %}
	RUN_SHELL_COMMAND CMD=set_display_brightness PARAMS={BRIGHTNESS}

[gcode_macro SCREEN_BRIGHTNESS_20]
gcode:
	RUN_SHELL_COMMAND CMD=set_display_brightness PARAMS=51

[gcode_macro SCREEN_BRIGHTNESS_40]
gcode:
	RUN_SHELL_COMMAND CMD=set_display_brightness PARAMS=102

[gcode_macro SCREEN_BRIGHTNESS_80]
gcode:
	RUN_SHELL_COMMAND CMD=set_display_brightness PARAMS=204

[gcode_macro SCREEN_BACKLIGHT_POWER]
gcode:
	{% set POWER = params.OFF|default(0)|int %}
	RUN_SHELL_COMMAND CMD=set_display_backlight_power PARAMS={POWER}

[gcode_macro SCREEN_OFF]
gcode:
	SCREEN_BRIGHTNESS BRIGHTNESS=0
	SCREEN_BACKLIGHT_POWER OFF=1

[gcode_macro SCREEN_ON]
gcode:
	SCREEN_BRIGHTNESS BRIGHTNESS=255
	SCREEN_BACKLIGHT_POWER OFF=0
EOF

test -d $KLIPPY_VENV_PATH || python3 -m venv $KLIPPY_VENV_PATH
$KLIPPY_VENV_PATH/bin/python -m pip install --upgrade pip
$KLIPPY_VENV_PATH/bin/pip install -r $KLIPPER_PATH/scripts/klippy-requirements.txt
[ -e ~/klippy-env ] || ln -s $KLIPPY_VENV_PATH ~/klippy-env

sudo tee >/dev/null /etc/init.d/klipper <<EOF
#!/sbin/openrc-run
command="$KLIPPY_VENV_PATH/bin/python"
command_args="$KLIPPER_PATH/klippy/klippy.py $CONFIG_PATH/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds"
command_background=true
command_user="$USER"
pidfile="/run/klipper.pid"
EOF

sudo chmod +x /etc/init.d/klipper
sudo rc-update add klipper sysinit || true
sudo service klipper restart || true

################################################################################
# KIAUH
################################################################################

test -d "$KIAUH_PATH" || git clone --depth=1 "$KIAUH_REPO" "$KIAUH_PATH"
find "$KIAUH_PATH/kiauh/extensions" -type f -name gcode_shell_command.py -exec ln -sf {} $KLIPPER_PATH/klippy/extras/ \;

################################################################################
# KAMP
################################################################################

test -d "$KAMP_PATH" || git clone --depth=1 $KAMP_REPO "$KAMP_PATH"
ln -sf "$KAMP_PATH/Configuration" "$CONFIG_PATH/KAMP"
cp -i "$KAMP_PATH/Configuration/KAMP_Settings.cfg" "$CONFIG_PATH/KAMP_Settings.cfg"

################################################################################
# MOONRAKER
################################################################################

sudo apk add libsodium iproute2 jpeg-dev zlib-dev #curl-dev

test -d $MOONRAKER_PATH || git clone --depth=1 $MOONRAKER_REPO $MOONRAKER_PATH
test -d $MOONRAKER_VENV_PATH || python3 -m venv $MOONRAKER_VENV_PATH
$MOONRAKER_VENV_PATH/bin/python -m pip install --upgrade pip
$MOONRAKER_VENV_PATH/bin/pip install -r $MOONRAKER_PATH/scripts/moonraker-requirements.txt

sudo tee >/dev/null /etc/init.d/moonraker <<EOF
#!/sbin/openrc-run
command="$MOONRAKER_VENV_PATH/bin/python"
command_args="$MOONRAKER_PATH/moonraker/moonraker.py"
command_background=true
command_user="$USER"
pidfile="/run/moonraker.pid"
depend() {
	after klipper
}
EOF

sudo chmod a+x /etc/init.d/moonraker

tee >/dev/null $CONFIG_PATH/moonraker.conf <<EOF
[machine]
provider: none # since we are using alpine there is no systemd

[server]
host: 127.0.0.1

[authorization]
trusted_clients:
	localhost
	127.0.0.1        # Standard localhost address
	127.0.0.0/8      # Local loopback range
	169.254.0.0/16   # Link-local
	FE80::/10        # IPv6 link-local
	::1/128          # IPv6 localhost
	$(ipcalc -n $(ip a s | awk '/scope global/ && /inet / {print $2; exit}') | cut -d= -f2)/$(ipcalc -p $(ip a s | awk '/scope global/ && /inet / {print $2; exit}') | cut -d= -f2)

[octoprint_compat]

[history]

[file_manager]
enable_object_processing: True

[update_manager]
enable_system_updates: False # since we are using alpine there is no systemd

[update_manager fluidd]
type: web
repo: $FLUIDD_REPO
path: $FLUIDD_PATH

[update_manager mainsail]
type: web
repo: $MAINSAIL_REPO
path: $MAINSAIL_PATH

[update_manager Laserweb4]
type: git_repo
origin: $LASERWEB4_REPO
primary_branch: build
path: $LASERWEB4_PATH
is_system_service: False

[update_manager Klipper-Adaptive-Meshing-Purging]
type: git_repo
origin: $KAMP_REPO
primary_branch: main
path: $KAMP_PATH
managed_services: klipper

[update_manager KlipperScreen]
type: git_repo
path: $KLIPPERSCREEN_PATH
origin: $KLIPPERSCREEN_REPO
virtualenv: $KLIPPERSCREEN_VENV_PATH
requirements: scripts/KlipperScreen-requirements.txt
system_dependencies: scripts/system-dependencies.json
managed_services: KlipperScreen
EOF

sudo rc-update add moonraker || true
sudo service moonraker restart || true

################################################################################
# MAINSAIL/FLUIDD/LaserWeb4
################################################################################

sudo apk add caddy

sudo tee >/dev/null /etc/caddy/Caddyfile <<EOF
:80

encode gzip

#header {
#	# Disable caching for HTML files so the UI switcher is instant
#	Cache-Control "no-cache, no-store, must-revalidate"
#	Pragma "no-cache"
#	Expires "0"
#}

# Only disable cache for the main entry points
@index_files path / /index.html
header @index_files Cache-Control "no-cache, no-store, must-revalidate"

@moonraker {
	path /server/* /websocket /printer/* /access/* /api/* /machine/* /history/* /database/*
}

handle @moonraker {
	reverse_proxy localhost:7125
}

handle /webcam* {
	reverse_proxy localhost:8081
}

# Cookie Setters (Triggered by GET parameters)
@set_mainsail query ui=mainsail
@set_fluidd   query ui=fluidd
@set_laserweb query ui=laserweb
@portal       query ui=

# Use redir to load the page at once without needing a refresh to see the new page
header @set_mainsail {
	Set-Cookie "ui_mode=mainsail; Path=/; Max-Age=3600"
	redir / /
}
header @set_fluidd   {
	Set-Cookie "ui_mode=fluidd; Path=/; Max-Age=3600"
	redir / /
}
header @set_laserweb {
	Set-Cookie "ui_mode=laserweb; Path=/; Max-Age=3600"
	redir / /
}
header @portal       {
	Set-Cookie "ui_mode=; Path=/; Max-Age=0"
	redir / /
}

# Root-Level UI Selection (Based on Cookie or Query)
@use_mainsail header Cookie *ui_mode=mainsail*
@use_fluidd   header Cookie *ui_mode=fluidd*
@use_laserweb header Cookie *ui_mode=laserweb*

# Mainsail
handle @use_mainsail {
	root * $MAINSAIL_PATH
	file_server
	try_files {path} {path}/ /index.html
}

# Fluidd
handle @use_fluidd {
	root * $FLUIDD_PATH
	file_server
	try_files {path} {path}/ /index.html
}

# LaserWeb
handle @use_laserweb {
	root * $LASERWEB4_PATH
	file_server
	try_files {path} {path}/ /index.html
}

# Redirect /fluidd to /fluidd/ (no trailing slash to trailing slash)
redir /fluidd /fluidd/

handle_path /fluidd/* {
	root * $FLUIDD_PATH
	file_server
	try_files {path} {path}/ /index.html
}

# Redirect /laserweb to /laserweb/ (no trailing slash to trailing slash)
redir /laserweb /laserweb/

handle_path /laserweb* {
	root * $LASERWEB4_PATH
	file_server
	try_files {path} {path}/ /index.html
}

# Default: Landing Page
handle {
	root * $CLIENT_PATH
	file_server
	try_files {path} {path}/ /index.html
}
EOF

# FLUIDD
rmdir "$FLUIDD_PATH" 2>/dev/null || true
mkdir -p "$FLUIDD_PATH" \
	&& CLIENT_RELEASE_URL=`wget -qO - https://api.github.com/repos/$FLUIDD_REPO/releases | awk '/browser_download_url/{print $2; exit;}' | tr -d '"' || true` \
	&& (cd "$FLUIDD_PATH" && wget -qO - $CLIENT_RELEASE_URL | unzip -q -)
# MAINSAIL
rmdir "$MAINSAIL_PATH" 2>/dev/null || true
mkdir -p "$MAINSAIL_PATH" \
	&& CLIENT_RELEASE_URL=`wget -qO - https://api.github.com/repos/$MAINSAIL_REPO/releases | awk '/browser_download_url/{print $2; exit;}' | tr -d '"' || true` \
	&& (cd "$MAINSAIL_PATH" && wget -qO - $CLIENT_RELEASE_URL | unzip -q -)
	echo $CLIENT_RELEASE_URL
# LASERWEB4
[ -e "$LASERWEB4_PATH" ] || git clone --depth=1 $LASERWEB4_REPO --branch build "$LASERWEB4_PATH"

# Select default client (FLUIDD/MAINSAIL)
# echo "Select Default Client:"
# selection="$(ls -d $FLUIDD_PATH $MAINSAIL_PATH | select_from_list)"
# [ -e "$selection" ] && ln -snf "$selection" "$CLIENT_PATH"

[ -e ~/www ] || mkdir ~/www
tee >/dev/null ~/www/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Printer UI Selection</title>
	<style>
		body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif; background: #0f111a; color: white; margin: 0; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
		.container { text-align: center; width: 90%; max-width: 800px; padding: 20px; }

		h1 { margin-bottom: 20px; font-weight: 300; letter-spacing: 2px; color: #00adb5; margin-top: 0; }

		.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 10px; margin-bottom: 20px; }
		a { text-decoration: none; color: #eeeeee; border: 1px solid #393e46; padding: 12px; border-radius: 8px; transition: all 0.2s; background: #1a1d29; font-weight: bold; font-size: 0.8rem; }
		a:hover { background: #00adb5; color: #121212; }
	</style>
</head>
<body>
	<div class="container">
		<h1>PRINTER UI SELECTION</h1>

		<div class="grid">
			<a href="/?ui=mainsail">MAINSAIL</a>
			<a href="/fluidd/">FLUIDD</a>
			<a href="/laserweb/">LASERWEB</a>
		</div>
	</div>
</body>
</html>
EOF

sudo rc-update add caddy || true
sudo service caddy restart || true

################################################################################
# E3V3SE_display_klipper
################################################################################

# if [ "$INSTALL_E3V3SE_DISPLAY" = 'y' -o "$INSTALL_E3V3SE_DISPLAY" = 'Y' ]; then
# sudo apk add make linux-headers swig py3-setuptools
# [ -e "$HOME/lgpio" ] || git clone --depth=1 https://github.com/joan2937/lg.git $HOME/lgpio
# cd $HOME/lgpio
# CFLAGS='-std=gnu11' make -j$(nproc)
# sudo make install

# [ -e "$E3V3SE_display_klipper_PATH" ] || git clone --depth=1 $E3V3SE_display_klipper_REPO "$E3V3SE_display_klipper_PATH"
# [ -e "$E3V3SE_display_klipper_VENV_PATH" ] || python3 -m venv "$E3V3SE_display_klipper_VENV_PATH"
# "$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install --upgrade pip
# "$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install rpi-lgpio
# sed -i 's/^python3-rpi.gpio$/#python3-rpi.gpio/' "$E3V3SE_display_klipper_PATH/src/e3v3se_display/requirements.txt"
# "$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install -r "$E3V3SE_display_klipper_PATH/src/e3v3se_display/requirements.txt"
# cp -i "$E3V3SE_display_klipper_PATH/src/e3v3se_display/config-example.ini" "$CONFIG_PATH/e3v3se_display_klipper_config.ini"

# sudo tee >/dev/null /etc/init.d/E3V3SE_display_klipper <<EOF
# #!/sbin/openrc-run
# command="$E3V3SE_display_klipper_VENV_PATH/bin/python"
# command_args="\"$E3V3SE_display_klipper_PATH/src/e3v3se_display/run.py\" --config \"$CONFIG_PATH/config.ini\""
# command_background=true
# command_user="$USER"
# pidfile="/run/E3V3SE_display_klipper.pid"
# output_log="/tmp/E3V3SE_display_klipper.log"
# error_log="/tmp/E3V3SE_display_klipper.err.log"
# supervisor="supervise-daemon"
# depend() {
# 	after moonraker
# }
# EOF

# sudo chmod +x /etc/init.d/E3V3SE_display_klipper
# sudo rc-update add E3V3SE_display_klipper sysinit || true
# sudo service E3V3SE_display_klipper restart || true
# fi

################################################################################
# UI
################################################################################

if [ "$UI_CHOICE" = 'KlipperScreen' ]; then
	# KlipperScreen + Wayland
	sudo apk add xwayland seatd sway swayidle build-base gobject-introspection-dev sdbus-cpp-dev librsvg openjpeg gtk+3.0 $($VIRTUAL && echo wayvnc)

	sudo addgroup $USER seat
	sudo addgroup $USER video
	sudo addgroup $USER input

	sudo rc-update add seatd || true
	sudo service seatd restart || true

	[ -e "$KLIPPERSCREEN_PATH" ] || git clone --depth=1 $KLIPPERSCREEN_REPO "$KLIPPERSCREEN_PATH"
	[ -e "$KLIPPERSCREEN_VENV_PATH" ] || python3 -m venv "$KLIPPERSCREEN_VENV_PATH"
	"$KLIPPERSCREEN_VENV_PATH/bin/python" -m pip install --upgrade pip
	# sed -i 's/^sdbus/#sdbus/' $KLIPPERSCREEN_PATH/scripts/KlipperScreen-requirements.txt
	"$KLIPPERSCREEN_VENV_PATH/bin/python" -m pip install -r "$KLIPPERSCREEN_PATH/scripts/KlipperScreen-requirements.txt"

	sudo tee >/dev/null /etc/init.d/KlipperScreen <<-EOF
	#!/sbin/openrc-run
	export XDG_RUNTIME_DIR=/tmp
	$($VIRTUAL && echo export WLR_LIBINPUT_NO_DEVICES=1)
	command="sway"
	command_args="-c \$(printf "$($VIRTUAL && echo exec wayvnc -pr 0.0.0.0 5901)\ndefault_border none\nexec swayidle -w timeout 60 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"'\nexec $KLIPPERSCREEN_VENV_PATH/bin/python $KLIPPERSCREEN_PATH/screen.py || pkill sway && pkill sway\n" > /tmp/sway_ks; echo /tmp/sway_ks)"
	command_background=true
	command_user="$USER"
	pidfile="/run/KlipperScreen.pid"
	output_log="/tmp/KlipperScreen.log"
	error_log="/tmp/KlipperScreen.err.log"
	supervisor="supervise-daemon"
	depend() {
		need seatd
		after seatd moonraker
	}
EOF

	sudo chmod +x /etc/init.d/KlipperScreen
	sudo rc-update add KlipperScreen || true
	sudo service KlipperScreen restart || true
elif [ "$UI_CHOICE" = 'Sway' ]; then
	# Sway
	sudo apk add seatd sway swayidle chromium $($VIRTUAL && echo wayvnc)
	sudo setup-devd udev || true

	sudo addgroup $USER seat
	sudo addgroup $USER video
	sudo addgroup $USER input

	sudo rc-update add seatd || true
	sudo service seatd restart || true

	sudo tee >/dev/null /etc/init.d/KlipperScreen <<-EOF
	#!/sbin/openrc-run
	export XDG_RUNTIME_DIR=/tmp
	$($VIRTUAL && echo export WLR_LIBINPUT_NO_DEVICES=1)
	command="sway"
	command_args="-c \$(printf "$($VIRTUAL && echo exec wayvnc -pr 0.0.0.0 5901)\ndefault_border none\nexec swayidle -w timeout 60 'swaymsg \"output * dpms off\"' resume 'swaymsg \"output * dpms on\"'\nexec chromium-browser $(test "$USER" = root && echo --no-sandbox) --no-first-run --disable-infobrs --kiosk 'http://localhost/?ui=' || pkill sway && pkill sway\n" > /tmp/sway_ks; echo /tmp/sway_ks)"
	command_background=true
	command_user="$USER"
	pidfile="/run/KlipperScreen.pid"
	output_log="/tmp/KlipperScreen.log"
	error_log="/tmp/KlipperScreen.err.log"
	supervisor="supervise-daemon"
	depend() {
		need seatd
		after seatd moonraker
	}
EOF

	sudo chmod +x /etc/init.d/KlipperScreen
	sudo rc-update add KlipperScreen || true
	sudo service KlipperScreen restart || true
elif [ "$UI_CHOICE" = 'Cage' ]; then
	# Cage
	sudo apk add seatd cage wlopm swayidle chromium dotool $($VIRTUAL && echo wayvnc)
	sudo setup-devd udev || true

	sudo addgroup $USER seat
	sudo addgroup $USER video
	sudo addgroup $USER input

	sudo rc-update add seatd || true
	sudo service seatd restart || true

	sudo sh -c 'echo uinput > /etc/modules-load.d/dotool.conf'

	sudo tee >/dev/null /etc/init.d/KlipperScreen <<-EOF
	#!/sbin/openrc-run
	export XDG_RUNTIME_DIR=/tmp
	$($VIRTUAL && echo export WLR_LIBINPUT_NO_DEVICES=1)
	command="cage"
	command_args="-ds sh -c \"$($VIRTUAL && echo wayvnc -pr 0.0.0.0 5901 '&')swayidle -w timeout 60 'wlopm --off \"*\"' resume 'wlopm --on \"*\"'&{ chromium-browser $(test "$USER" = root && echo --no-sandbox) --no-first-run --disable-infobrs --kiosk 'http://localhost/?ui='; pkill cage; } & sleep 1 && echo mouseto 1.0 1.0 | dotool\""
	command_background=true
	command_user="$USER"
	pidfile="/run/KlipperScreen.pid"
	output_log="/tmp/KlipperScreen.log"
	error_log="/tmp/KlipperScreen.err.log"
	supervisor="supervise-daemon"
	depend() {
		need seatd
		after seatd moonraker
	}
EOF

	sudo chmod +x /etc/init.d/KlipperScreen
	sudo rc-update add KlipperScreen || true
	sudo service KlipperScreen restart || true
fi

################################################################################
# DONE
################################################################################

echo "Check $KLIPPER_PATH/config folder for printer config files and copy the one you want to use to $CONFIG_PATH/printer.cfg"
echo "Add '[exclude_object]' '[include KAMP_Settings.cfg]' '[include sample-pwm-tool.cfg]' '[include sample-macros.cfg]' to your $CONFIG_PATH/printer.cfg"
echo "Edit $CONFIG_PATH/sample-macros.cfg"
echo "Edit $CONFIG_PATH/sample-pwm-tool.cfg to configure your laser"
echo "Edit $CONFIG_PATH/KAMP_Settings.cfg and enable the feature that you want"
echo "Make sure to go to your slicer and enable the “Label Objects” option"