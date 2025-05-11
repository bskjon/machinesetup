#!/bin/bash

# Oppdatert skript: Kan kjøres flere ganger, logger feilede steg og fortsetter

# Ikke-interaktivt
export DEBIAN_FRONTEND=noninteractive
APT_ARGS=("-y" "-qq")

# Fjern automatisk exit på feil, vi håndterer det selv
set -uo pipefail

# Les sudo-passordet én gang
default_prompt() { echo "[sudo] password for $USER: "; }

read -s -p "$(default_prompt)" password
echo
until echo "$password" | sudo -S -v &>/dev/null; do
    echo "Ugyldig passord, prøv igjen."
    read -s -p "$(default_prompt)" password
    echo
done

# Hjelpefunksjon for sudo med passord
sudo_pass() {
    echo "$password" | sudo -S "$@"
}

# Array for logging av funksjoner som feilet av funksjoner som feilet
declare -a FAILURES=()

# Sjekk om funksjon feiler, legg til i FAILURES
def run_step() {
    local fn="$1"
    echo "=== Kjører: $fn ==="
    if ! $fn; then
        echo "*** Feilet: $fn ***"
        FAILURES+=("$fn")
    fi
}

# Funksjoner
install_dependencies() {
    sudo_pass apt-get update "${APT_ARGS[@]}"
    sudo_pass apt-get upgrade "${APT_ARGS[@]}"
    for pkg in git wget jq dconf-cli curl snapd p7zip-full tar kdeconnect; do
        if ! dpkg -l | grep -qw "$pkg"; then
            sudo_pass apt-get install "${APT_ARGS[@]}" "$pkg" || return 1
        fi
    done
}

install_fzf() {
    if ! command -v fzf &>/dev/null; then
        sudo_pass apt-get install "${APT_ARGS[@]}" fzf || return 1
        echo 'eval "$(fzf --bash)"' >> "$HOME/.bashrc"
    fi
}

install_edge() {
    local base="https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/"
    local latest=$(curl -s "$base" \
        | grep -oP 'microsoft-edge-stable_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-1_amd64.deb' \
        | sort -V | tail -n1)
    if [[ -z "$latest" ]]; then return 1; fi
    wget -q "$base$latest"
    sudo_pass dpkg -i "$latest" || sudo_pass apt-get install -f "${APT_ARGS[@]}"
}

install_snap() {
    sudo_pass apt-get install "${APT_ARGS[@]}" snapd || return 1
}

install_apps_from_app_center() {
    sudo_pass snap install intellij-idea-community --classic || return 1
    sudo_pass snap install android-studio --classic || return 1
    sudo_pass snap install discord || return 1
    sudo_pass snap install spotify || return 1
}

install_steam() {
    wget -qO steam_latest.deb "https://steamcdn-a.akamaihd.net/client/installer/steam.deb"
    sudo_pass dpkg -i steam_latest.deb || sudo_pass apt-get install -f "${APT_ARGS[@]}"
}

install_wine() {
    if ! dpkg -l | grep -qw wine; then
        sudo_pass dpkg --add-architecture i386
        sudo_pass apt-get update "${APT_ARGS[@]}"
        sudo_pass apt-get install "${APT_ARGS[@]}" wine64 wine32 winetricks || return 1
    fi
}

install_flatpak() {
    if ! command -v flatpak &>/dev/null; then
        sudo_pass apt-get install "${APT_ARGS[@]}" flatpak || return 1
        sudo_pass flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

install_gear_lever() {
    if ! command -v flatpak &>/dev/null; then return 1; fi
    sudo_pass flatpak install -y flathub it.mijorus.gearlever || return 1
}

install_refind() {
    sudo_pass add-apt-repository ppa:rodsmith/refind -y
    sudo_pass apt-get update "${APT_ARGS[@]}"
    sudo_pass apt-get install "${APT_ARGS[@]}" refind || return 1
}

install_cooler_control() {
    local api="https://gitlab.com/api/v4/projects/30707566/releases"
    local version=$(curl -s "$api" | jq -r '.[0].tag_name')
    if [[ -z "$version" ]]; then return 1; fi
    for f in coolercontrol_${version}_amd64_ubuntu.deb \
             coolercontrold_${version}_amd64_ubuntu.deb \
             coolercontrol-liqctld_${version}_amd64_ubuntu.deb; do
        wget -qO "$f" "https://gitlab.com/coolercontrol/coolercontrol/-/releases/$version/downloads/packages/$f" || return 1
    done
}

extract_coolercontrol() {
    if [[ -f "coolercontro.tar.gz" ]]; then
        sudo_pass mkdir -p /etc/coolercontrol
        sudo_pass tar -xzvf coolercontro.tar.gz -C /etc/coolercontrol || return 1
    fi
}

configure_refind() {
    local cfg=/boot/efi/EFI/refind/refind.conf
    [[ -f "$cfg" ]] || return 1
    sudo_pass mkdir -p /boot/efi/EFI/refind/themes/ambience
    [[ -f ambience.tar.gz ]] && sudo_pass tar -xzvf ambience.tar.gz -C /boot/efi/EFI/refind/themes/ambience
    sudo_pass grep -qxF 'include themes/ambience/theme.conf' "$cfg" || \
        echo 'include themes/ambience/theme.conf' | sudo_pass tee -a "$cfg" >/dev/null
    mapfile -t lines < <(grep -n '^[[:space:]]*resolution' "$cfg" | grep -v '^[[:space:]]*#' | cut -d: -f1)
    if (( ${#lines[@]} )); then
        for ((i=0; i<${#lines[@]}-1; i++)); do
            sudo_pass sed -i "${lines[i]}s/^/# /" "$cfg"
        done
        sudo_pass sed -i "${lines[-1]}a resolution max" "$cfg"
    else
        echo 'resolution max' | sudo_pass tee -a "$cfg" >/dev/null
    fi
}

configure_theme() {
    [[ -f gnome-settings.dconf ]] && dconf load / < gnome-settings.dconf || return 1
}

configure_extensions() {
    if [[ -f gnome-extensions-backup.tar.gz ]]; then
        mkdir -p "$HOME/.local/share/gnome-shell/extensions"
        tar -xzf gnome-extensions-backup.tar.gz -C "$HOME/.local/share/gnome-shell/extensions" || return 1
        dconf load /org/gnome/shell/extensions/ < gnome-extensions-settings.dconf
    fi
}

main() {
    local steps=(
        install_dependencies
        install_fzf
        install_edge
        install_snap
        install_apps_from_app_center
        install_steam
        install_refind
        install_wine
        install_flatpak
        install_gear_lever
        configure_refind
        install_cooler_control
        extract_coolercontrol
        configure_theme
        configure_extensions
    )
    for step in "${steps[@]}"; do
        run_step "$step"
    done

    if (( ${#FAILURES[@]} )); then
        echo -e "\nOppsummering: Noen steg feilet:\n"
        for f in "${FAILURES[@]}"; do echo " - $f"; done
        exit 1
    else
        echo -e "\nAlle steg fullført uten feil!"
    fi
}

main
