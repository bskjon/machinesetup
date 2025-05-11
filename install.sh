#!/bin/bash
set -euo pipefail  # Avslutt scriptet ved feil, udefinerte variabler eller rør-feil

# Ikke-interaktiv installasjon
export DEBIAN_FRONTEND=noninteractive
APT_ARGS=("-y" "-qq" "-o" "Dpkg::Options::=--force-confdef" "-o" "Dpkg::Options::=--force-confold")

# Les inn sudo-passordet én gang
read -s -p "[sudo] password for $USER: " password
echo
until echo "$password" | sudo -S -v &>/dev/null; do
    echo "Ugyldig passord, prøv igjen."
    read -s -p "[sudo] password for $USER: " password
    echo
done

# Hjelpefunksjon for sudo-kommandoer med passord
sudo_pass() {
    echo "$password" | sudo -S "$@"
}

#############################
# INSTALLASJONSFUNKSJONER  #
#############################

install_dependencies() {
    echo "Oppdaterer pakkelister og oppgraderer installerte pakker..."
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get upgrade "${APT_ARGS[@]}"
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" git wget jq dconf-cli curl snapd p7zip-full tar kdeconnect
}

install_fzf() {
    echo "Installerer fzf..."
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" fzf
    grep -qxF 'eval "$(fzf --bash)"' "$HOME/.bashrc" || \
        echo 'eval "$(fzf --bash)"' >> "$HOME/.bashrc"
}

install_edge() {
    echo "Installerer Microsoft Edge..."
    local base="https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/"
    local latest=$(curl -s "$base" \
        | grep -oP 'microsoft-edge-stable_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-1_amd64.deb' \
        | sort -V | tail -n1)
    if [[ -n "$latest" ]]; then
        echo "Laster ned $latest..."
        wget -q "$base$latest"
        echo "Installerer $latest..."
        sudo_pass dpkg -i "$latest" || sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" -f
    else
        echo "Kunne ikke finne siste Edge-pakke."
    fi
}

install_snap() {
    echo "Installerer snapd hvis nødvendig..."
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" snapd
}

install_apps_from_app_center() {
    echo "Installerer Snap-applikasjoner..."
    sudo_pass snap install intellij-idea-community --classic
    sudo_pass snap install android-studio --classic
    sudo_pass snap install discord
    sudo_pass snap install spotify
}

install_steam() {
    echo "Installerer Steam..."
    wget -qO steam_latest.deb "https://steamcdn-a.akamaihd.net/client/installer/steam.deb"
    sudo_pass dpkg -i steam_latest.deb || sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" -f
}

install_wine() {
    echo "Installerer Wine..."
    if dpkg -l | grep -qw wine; then
        echo "Wine er allerede installert."
        return
    fi
    sudo_pass dpkg --add-architecture i386
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" wine64 wine32 winetricks
}

install_flatpak() {
    echo "Installerer Flatpak..."
    if command -v flatpak &>/dev/null; then
        echo "Flatpak allerede installert."
        return
    fi
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" flatpak
    sudo_pass flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
}

install_gear_lever() {
    echo "Installerer Gear Lever via Flatpak..."
    if ! command -v flatpak &>/dev/null; then
        echo "Flatpak ikke funnet. Avslutter Gear Lever-installasjon."
        return
    fi
    sudo_pass flatpak install -y flathub com.github.unrud.GearLever
}

install_refind() {
    echo "Installerer rEFInd..."
    sudo_pass add-apt-repository ppa:rodsmith/refind -y
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get update -qq
    sudo_pass env DEBIAN_FRONTEND=noninteractive apt-get install "${APT_ARGS[@]}" refind
}

install_cooler_control() {
    echo "Henter Cooler Control fra GitLab..."
    local api="https://gitlab.com/api/v4/projects/30707566/releases"
    local version=$(curl -s "$api" | jq -r '.[0].tag_name')
    if [[ -z "$version" ]]; then
        echo "Fant ikke nyeste versjon."
        exit 1
    fi
    echo "Versjon $version funnet. Laster ned pakker..."
    local base_url="https://gitlab.com/coolercontrol/coolercontrol/-/releases/$version/downloads/packages/"
    for f in coolercontrol_${version}_amd64_ubuntu.deb \
             coolercontrold_${version}_amd64_ubuntu.deb \
             coolercontrol-liqctld_${version}_amd64_ubuntu.deb; do
        wget -qO "$f" "$base_url$f"
    done
}

extract_coolercontrol() {
    if [[ -f "coolercontro.tar.gz" ]]; then
        echo "Pakk ut coolercontro.tar.gz..."
        sudo_pass mkdir -p /etc/coolercontrol
        sudo_pass tar -xzvf coolercontro.tar.gz -C /etc/coolercontrol
    else
        echo "coolercontro.tar.gz ikke funnet; hopper over."
    fi
}

configure_refind() {
    local cfg=/boot/efi/EFI/refind/refind.conf
    if [[ ! -f "$cfg" ]]; then echo "rEFInd ikke installert."; return; fi
    echo "Konfigurerer rEFInd-tema og resolution..."
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
    local f=gnome-settings.dconf
    [[ -f "$f" ]] && dconf load / < "$f"
}

configure_extensions() {
    local b=gnome-extensions-backup.tar.gz
    local d="$HOME/.local/share/gnome-shell/extensions"
    if [[ -f "$b" ]]; then
        mkdir -p "$d"
        tar -xzf "$b" -C "$d"
        dconf load /org/gnome/shell/extensions/ < gnome-extensions-settings.dconf
    fi
}

main() {
    install_dependencies
    if [[ ! -d machinesetup ]]; then
        git clone https://github.com/bskjon/machinesetup.git
    fi
    cd machinesetup

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

    echo "*** All installasjoner og konfigurasjoner fullført! ***"
}

main
