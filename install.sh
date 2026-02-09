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

: ${MOONRAKER_REPO:="https://github.com/Arksine/moonraker"}
: ${MOONRAKER_PATH:="$HOME/moonraker"}
: ${MOONRAKER_VENV_PATH:="$HOME/venv/moonraker"}

: ${E3V3SE_display_klipper_REPO:="https://github.com/jpcurti/E3V3SE_display_klipper"}
: ${E3V3SE_display_klipper_PATH:="$HOME/e3v3se_display_klipper"}
: ${E3V3SE_display_klipper_VENV_PATH:="$HOME/venv/e3v3se_display_klipper"}

: ${KLIPPERSCREEN_REPO:="https://github.com/KlipperScreen/KlipperScreen"}
: ${KLIPPERSCREEN_PATH:="$HOME/KlipperScreen"}
: ${KLIPPERSCREEN_VENV_PATH:="$HOME/venv/KlipperScreen"}

: ${CLIENTS_DIR:="$HOME"}
: ${CLIENT_PATH:="$CLIENTS_DIR/www"}

: ${FLUIDD_REPO:="fluidd-core/fluidd"}
: ${FLUIDD_PATH="$CLIENTS_DIR/fluidd"}

: ${MAINSAIL_REPO:="mainsail-crew/mainsail"}
: ${MAINSAIL_PATH="$CLIENTS_DIR/mainsail"}

: ${LASERWEB4_REPO:="https://github.com/ssendev/LaserWeb4"}
: ${LASERWEB4_PATH="$CLIENTS_DIR/laserweb4"}

: ${KAMP_REPO:="https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging"}
: ${KAMP_PATH:="$HOME/KAMP"}

if [ $(id -u) = 0 ]; then
	echo "This script must not run as root"
	exit 1
fi

command -v sudo >>/dev/null || { command -v doas >>/dev/null && alias sudo=doas; } || alias sudo=

################################################################################
# PRE
################################################################################

sudo apk add sudo git python3 build-base python3-dev libffi-dev freetype-dev fribidi-dev harfbuzz-dev jpeg-dev lcms2-dev openjpeg-dev tcl-dev tiff-dev tk-dev zlib-dev
#sudo sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
#sudo sh -c 'echo "permit nopass $USER as root cmd apk" >> /etc/doas.d/99-$USER-klipper.conf'
#sudo sh -c 'echo "permit nopass $USER as root cmd poweroff" >> /etc/doas.d/99-$USER-klipper.conf'
#sudo sh -c 'echo "permit nopass $USER as root cmd reboot" >> /etc/doas.d/99-$USER-klipper.conf'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/apk" >> /etc/sudoers.d/99-$USER'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/poweroff" >> /etc/sudoers.d/99-$USER'
sudo sh -c 'echo "klipper ALL=(ALL) NOPASSWD: /sbin/reboot" >> /etc/sudoers.d/99-$USER'

[ -e /etc/init.d ] || sudo mkdir -p /etc/init.d

################################################################################
# KLIPPER
################################################################################

[ -e "$CONFIG_PATH" ] || mkdir -p "$CONFIG_PATH"
[ -e "$GCODE_PATH" ] || ln -s /tmp "$GCODE_PATH"
[ -e "$COMMS_PATH" ] || ln -s /tmp "$COMMS_PATH"
[ -e "$LOGS_PATH" ] || ln -s /tmp "$LOGS_PATH"

test -d $KLIPPER_PATH || git clone --depth=1 $KLIPPER_REPO $KLIPPER_PATH

#echo 'choose printer config:'
#sleep 1
#selection="$(ls "$KLIPPER_PATH/config" | select_from_list)"
#cp -i "$KLIPPER_PATH/config/$selection" "$CONFIG_PATH/printer.cfg"

cp -i "$KLIPPER_PATH/config/sample-pwm-tool.cfg" "$CONFIG_PATH"
cp -i "$KLIPPER_PATH/config/sample-macros.cfg" "$CONFIG_PATH"

test -d $KLIPPY_VENV_PATH || python3 -m venv $KLIPPY_VENV_PATH
$KLIPPY_VENV_PATH/bin/python -m pip install --upgrade pip
$KLIPPY_VENV_PATH/bin/pip install -r $KLIPPER_PATH/scripts/klippy-requirements.txt

sudo tee /etc/init.d/klipper <<EOF
#!/sbin/openrc-run
command="$KLIPPY_VENV_PATH/bin/python"
command_args="$KLIPPER_PATH/klippy/klippy.py $CONFIG_PATH/printer.cfg -l /tmp/klippy.log -a /tmp/klippy_uds"
command_background=true
command_user="$USER"
pidfile="/run/klipper.pid"
EOF

sudo chmod +x /etc/init.d/klipper
sudo rc-update add klipper sysinit || true
sudo service klipper start || true

################################################################################
# MOONRAKER
################################################################################

sudo apk add libsodium iproute2 #curl-dev

test -d $MOONRAKER_PATH || git clone --depth=1 $MOONRAKER_REPO $MOONRAKER_PATH
test -d $MOONRAKER_VENV_PATH || python3 -m venv $MOONRAKER_VENV_PATH
$MOONRAKER_VENV_PATH/bin/python -m pip install --upgrade pip
$MOONRAKER_VENV_PATH/bin/pip install -r $MOONRAKER_PATH/scripts/moonraker-requirements.txt

sudo tee /etc/init.d/moonraker <<EOF
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

cat > $CONFIG_PATH/moonraker.conf <<EOF
[machine]
provider: none # since we are using alpine there is no systemd

[server]
#host: 127.0.0.1
host: all # needed for laserweb to work

[authorization]
trusted_clients:
	localhost
	127.0.0.1        # Standard localhost address
	127.0.0.0/8      # Local loopback range
	169.254.0.0/16   # Link-local
	FE80::/10        # IPv6 link-local
	::1/128          # IPv6 localhost
	$(ipcalc -n $(ip a s | awk '/scope global/ && /inet / {print $2; exit}') | cut -d= -f2)/$(ipcalc -p $(ip a s | awk '/scope global/ && /inet / {print $2; exit}') | cut -d= -f2)
cors_domains:
    * # This allows LaserWeb's web-based requests to pass

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
sudo service moonraker start || true

################################################################################
# KAMP
################################################################################

test -d "$KAMP_PATH" || git clone --depth=1 $KAMP_REPO "$KAMP_PATH"
ln -s "$KAMP_PATH/Configuration" "$CONFIG_PATH/KAMP"
cp -i "$KAMP_PATH/Configuration/KAMP_Settings.cfg" "$CONFIG_PATH/KAMP_Settings.cfg"

################################################################################
# MAINSAIL/FLUIDD/LaserWeb4
################################################################################

sudo apk add caddy

sudo tee /etc/caddy/Caddyfile <<EOF
:80

encode gzip

@moonraker {
	path /server/* /websocket /printer/* /access/* /api/* /machine/*
}

route @moonraker {
	reverse_proxy localhost:7125
}

route /webcam {
	reverse_proxy localhost:8081
}

handle_path /fluidd* {
    root * $FLUIDD_PATH
    file_server
}

handle_path /mainsail* {
    root * $MAINSAIL_PATH
    file_server
}

# Redirect /laserweb to /laserweb/ (no trailing slash to trailing slash)
redir /laserweb /laserweb/

handle_path /laserweb* {
    root * $LASERWEB4_PATH
    file_server
}

route {
	root * $CLIENT_PATH
	try_files {path} {path}/ /index.html
	file_server
}
EOF

# FLUIDD
mkdir -p "$FLUIDD_PATH" \
	&& CLIENT_RELEASE_URL=`wget -qO - https://api.github.com/repos/$FLUIDD_REPO/releases | awk '/browser_download_url/{print $2; exit;}' | tr -d '"'` || true \
	&& (cd "$FLUIDD_PATH" && wget -qO - $CLIENT_RELEASE_URL | unzip -q -)
# MAINSAIL
mkdir -p "$MAINSAIL_PATH" \
	&& CLIENT_RELEASE_URL=`wget -qO - https://api.github.com/repos/$MAINSAIL_REPO/releases | awk '/browser_download_url/{print $2; exit;}' | tr -d '"'` || true \
	&& (cd "$MAINSAIL_PATH" && wget -qO - $CLIENT_RELEASE_URL | unzip -q -)
# LASERWEB4
[ -e "$LASERWEB4_PATH" ] || git clone --depth=1 $LASERWEB4_REPO --branch build "$LASERWEB4_PATH"

# Select default client (FLUIDD/MAINSAIL)
echo "Select Default Client:"
selection="$(ls -d $FLUIDD_PATH $MAINSAIL_PATH | select_from_list)"
ln -snf "$selection" "$CLIENT_PATH"

sudo rc-update add caddy || true
service caddy start || true

################################################################################
# E3V3SE_display_klipper
################################################################################

echo -n "Install E3V3SE_display_klipper? (y/N):"
read -r REPLY
echo

if [ "$REPLY" = 'y' -o "$REPLY" = 'Y' ]; then
sudo apk add make linux-headers swig py3-setuptools
[ -e "$HOME/lgpio" ] || git clone --depth=1 https://github.com/joan2937/lg.git $HOME/lgpio
cd $HOME/lgpio
CFLAGS='-std=gnu11' make -j$(nproc)
sudo make install

[ -e "$E3V3SE_display_klipper_PATH" ] || git clone --depth=1 $E3V3SE_display_klipper_REPO "$E3V3SE_display_klipper_PATH"
[ -e "$E3V3SE_display_klipper_VENV_PATH" ] || python3 -m venv "$E3V3SE_display_klipper_VENV_PATH"
"$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install --upgrade pip
"$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install rpi-lgpio
sed -i 's/^python3-rpi.gpio$/#python3-rpi.gpio/' "$E3V3SE_display_klipper_PATH/src/e3v3se_display/requirements.txt"
"$E3V3SE_display_klipper_VENV_PATH/bin/python" -m pip install -r "$E3V3SE_display_klipper_PATH/src/e3v3se_display/requirements.txt"
cp -i "$E3V3SE_display_klipper_PATH/src/e3v3se_display/config-example.ini" "$CONFIG_PATH/e3v3se_display_klipper_config.ini"

sudo tee /etc/init.d/E3V3SE_display_klipper <<EOF
#!/sbin/openrc-run
command="$E3V3SE_display_klipper_VENV_PATH/bin/python"
command_args="\"$E3V3SE_display_klipper_PATH/run.py\" --config \"$CONFIG_PATH/config.ini\""
command_background=true
command_user="$USER"
pidfile="/run/E3V3SE_display_klipper.pid"
depend() {
	after moonraker
}
EOF

sudo chmod +x /etc/init.d/E3V3SE_display_klipper
sudo rc-update add E3V3SE_display_klipper sysinit || true
sudo service E3V3SE_display_klipper start || true
fi

################################################################################
# UI
################################################################################


echo -n "Install KlipperScreen UI? (y/N):"
read -r REPLY
echo

if [ "$REPLY" = 'y' -o "$REPLY" = 'Y' ]; then
# KlipperScreen
sudo apk add xwayland seatd sway build-base gobject-introspection-dev librsvg openjpeg
[ -e "$KLIPPERSCREEN_PATH" ] || git clone --depth=1 $KLIPPERSCREEN_REPO "$KLIPPERSCREEN_PATH"
[ -e "$KLIPPERSCREEN_VENV_PATH" ] || python3 -m venv "$KLIPPERSCREEN_VENV_PATH"
"$KLIPPERSCREEN_VENV_PATH/bin/python" -m pip install --upgrade pip
sed -i 's/^sdbus/#sdbus/' $KLIPPERSCREEN_PATH/scripts/KlipperScreen-requirements.txt
"$KLIPPERSCREEN_VENV_PATH/bin/python" -m pip install -r "$KLIPPERSCREEN_PATH/scripts/KlipperScreen-requirements.txt"

sudo tee /etc/init.d/KlipperScreen <<EOF
#!/sbin/openrc-run
export XDG_RUNTIME_DIR=/tmp
command="sway"
command_args="-c \$(echo "exec_always $HOME/venv/klipperscreen/bin/python $HOME/klipperscreen/screen.py" > /tmp/sway_ks; echo /tmp/sway_ks)"
command_background=true
command_user="$USER"
pidfile="/run/KlipperScreen.pid"
depend() {
	after moonraker
}
EOF

sudo chmod +x /etc/init.d/KlipperScreen
sudo rc-update add KlipperScreen || true
sudo service KlipperScreen start || true
elif echo -n "Install Wayland UI? (y/N):" && read -r REPLY && echo && [ "$REPLY" = 'y' -o "$REPLY" = 'Y' ]; then
# Wayland + Cage
sudo apk add seatd cage chromium dotool
sudo setup-devd udev

sudo addgroup $USER seat video input

sudo rc-update add seatd || true
sudo service seatd start || true

sudo sh -c 'echo uinput > /etc/modules-load.d/cage.conf'

sudo tee /etc/init.d/cage <<EOF
#!/sbin/openrc-run
export XDG_RUNTIME_DIR=/tmp
command="cage"
command_args="-ds sh -c \"sed -i 's/\\\"exited_cleanly\\\":false/\\\"exited_cleanly\\\":true/' ~/.config/chromium/'Local State'; sed -i 's/\\\"exited_cleanly\\\":false/\\\exited_cleanly\\\":true/; s/\\\"exit_type\\\":\\\"[^\\\"]\+\\\"/\\\"exit_type\\\":\\\"Normal\\\"/' ~/.config/chromium/Default/Preferences; chromium-browser --disable-infobrs --kiosk 'http://localhost' & sleep 1 && echo mouseto 1.0 1.0 | dotool; fg\""
command_background=true
command_user="$USER"
pidfile="/run/cage.pid"
output_log="/tmp/cage.log"
error_log="/tmp/cage.log"
supervisor="supervise-daemon"
depend() {
	need seatd
	after seatd moonraker
}
EOF
sudo chmod +x /etc/init.d/cage
sudo rc-update add cage || true
sudo service cage start || true

# Wayland + Sway
# sudo apk add seatd sway chromium
# sudo setup-devd udev

# sudo addgroup $USER seat video input

# sudo rc-update add seatd || true
# sudo service seatd start || true

# mkdir -p ~/.config/sway
# cat <<EOF > ~/.config/sway/config
# # Start Chromium in kiosk mode
# exec sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/chromium/'Local State'
# exec sed -i 's/"exited_cleanly":false/"exited_cleanly":true/; s/"exit_type":"[^"]\+"/"exit_type":"Normal"/' ~/.config/chromium/Default/Preferences
# exec_always sh -c 'while true; do chromium-browser --disable-infobars --kiosk 'http://localhost'; done'
# EOF

# cat <<EOF > /etc/local.d/sway.start
# #!/bin/sh
# export XDG_RUNTIME_DIR=/run/user/$(id -u $USER)
# [ ! -d "\$XDG_RUNTIME_DIR" ] && mkdir -p "\$XDG_RUNTIME_DIR"
# chown $USER:$USER "\$XDG_RUNTIME_DIR"
# chmod 700 "\$XDG_RUNTIME_DIR"
# su -l $USER -c "XDG_RUNTIME_DIR=\$XDG_RUNTIME_DIR dbus-run-session sway" > /tmp/sway.log 2>&1 &
# EOF
# sudo chmod +x /etc/local.d/sway.start
# sudo rc-update add local || true
# sudo service local start || true

# sudo tee /etc/init.d/sway <<EOF
# #!/sbin/openrc-run
# export XDG_RUNTIME_DIR=/tmp
# command="dbus-run-session"
# command_args="sway > /tmp/sway.log 2>&1"
# command_background=true
# command_user="$USER"
# pidfile="/run/sway.pid"
# depend() {
# 	need dbus seatd
# 	after dbus seatd moonraker
# }
# EOF
# sudo chmod +x /etc/init.d/sway
# sudo rc-update add sway || true
# sudo service sway start || true
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