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
	before klipper
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
echo $E3V3SE_display_klipper_VENV_PATH

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
command_user="root"
pidfile="/run/E3V3SE_display_klipper.pid"
depend() {
	before moonraker
}
EOF

sudo chmod +x /etc/init.d/E3V3SE_display_klipper
sudo rc-update add E3V3SE_display_klipper sysinit || true
sudo service E3V3SE_display_klipper start || true
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