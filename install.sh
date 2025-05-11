#!/bin/bash
set -e  # Avslutt scriptet ved feil

# Les inn sudo-passordet én gang
read -s -p "[sudo] password for $USER: " password
echo
until echo "$password" | sudo -S -v &>/dev/null; do
    echo "Sorry, prøv igjen."
    read -s -p "[sudo] password for $USER: " password
    echo
done

# Ikke-interaktivt
export DEBIAN_FRONTEND=noninteractive

#############################
# INSTALLASJONSFUNKSJONER  #
#############################

install_dependencies() {
    echo "Installerer nødvendige avhengigheter..."
    echo "$password" | sudo -S apt update -y -qq
    echo "$password" | sudo -S apt upgrade -y -qq
    echo "$password" | sudo -S apt update -y -qq
    
    echo "$password" | sudo -S apt install -y -qq wget git jq dconf-cli tar curl snapd 7zip tar kdeconnect
}

# ... (de øvrige installasjons- og konfigurasjonsfunksjonene)

#############################
# INSTALLASJONSFUNKSJONER  #
#############################

# Installerer fzf og legger til initialisering i .bashrc
install_fzf() {
    echo "Installerer fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
}

# Installerer Microsoft Edge ved å hente den siste .deb-filen
install_edge() {
    echo "Installerer Microsoft Edge..."
    EDGE_URL="https://packages.microsoft.com/repos/edge/pool/main/m/microsoft-edge-stable/"
    LATEST_DEB=$(curl -s "$EDGE_URL" | grep -oP 'microsoft-edge-stable_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+-1_amd64\.deb' | sort -V | tail -n 1)
    if [ -n "$LATEST_DEB" ]; then
         echo "Laster ned $LATEST_DEB..."
         wget "$EDGE_URL$LATEST_DEB"
         echo "Installerer $LATEST_DEB..."
         echo "$password" | sudo -S dpkg -i "$LATEST_DEB"
         echo "$password" | sudo -S apt-get -f install -y
         echo "Microsoft Edge er nå installert!"
    else
         echo "Kunne ikke finne siste versjon av Microsoft Edge."
    fi
}

# Installerer snapd (dersom ikke allerede installert)
install_snap() {
    echo "Installerer snapd (dersom ikke allerede installert)..."
    echo "$password" | sudo -S apt install -y snapd
}

# Installerer apper via Snap
install_apps_from_app_center() {
    echo "Installerer apper via Snap:"
    echo " - IntelliJ IDEA Community..."
    echo "$password" | sudo -S snap install intellij-idea-community --classic
    echo " - Android Studio..."
    echo "$password" | sudo -S snap install android-studio --classic
    echo " - Discord..."
    echo "$password" | sudo -S snap install discord
    echo " - Spotify..."
    echo "$password" | sudo -S snap install spotify
}

# Laster ned og installerer Steam
install_steam() {
    echo "Laster ned Steam DEB-pakke fra Valve..."
    wget -O steam_latest.deb "https://steamcdn-a.akamaihd.net/client/installer/steam.deb"
    echo "Installerer Steam..."
    echo "$password" | sudo -S dpkg -i steam_latest.deb || echo "$password" | sudo -S apt install -f -y
}

install_wine() {
    echo "Installerer Wine..."

    # Sjekker om Wine allerede er installert
    if dpkg -l | grep -qw wine; then
        echo "Wine er allerede installert!"
        return
    fi

    # Legg til Wine PPA repository og oppdater pakker
    echo "$password" | sudo -S dpkg --add-architecture i386
    echo "$password" | sudo -S apt update
    echo "$password" | sudo -S apt install -y wine64 wine32 winetricks
    echo "Wine er nå installert!"
}

install_flatpak() {
    echo "Installerer Flatpak..."

    # Sjekk om Flatpak allerede er installert
    if command -v flatpak &> /dev/null; then
        echo "Flatpak er allerede installert!"
        return
    fi

    # Installer Flatpak via APT
    echo "$password" | sudo -S apt install -y flatpak

    # Legg til Flathub repo hvis det ikke allerede er lagt til
    echo "$password" | sudo -S flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Flatpak er nå installert!"
}

install_gear_lever() {
    echo "Installerer Gear Lever via Flatpak..."

    # Sjekk om Flatpak er installert
    if ! command -v flatpak &> /dev/null; then
        echo "Flatpak ble ikke funnet! Installering av Gear Lever kan ikke fortsette."
        return
    fi

    # Legg til Flathub repo hvis det ikke allerede er lagt til
    echo "$password" | sudo -S flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Installer Gear Lever
    echo "$password" | sudo -S flatpak install -y flathub it.mijorus.gearlever
}


# Installerer rEFInd
install_refind() {
    echo "Installerer rEFInd..."
    echo "$password" | sudo -S apt-add-repository ppa:rodsmith/refind -y
    echo "$password" | sudo -S apt-get update
    echo "$password" | sudo -S apt-get install -y refind
    echo "rEFInd er nå installert!"
}

# Henter cooler control-pakker fra GitLab API
install_cooler_control() {
    echo "Henter siste versjon fra GitLab API for coolercontrol..."
    GITLAB_API="https://gitlab.com/api/v4/projects/30707566/releases"
    LATEST_VERSION=$(curl -s "$GITLAB_API" | jq -r '.[0].tag_name')
    if [ -z "$LATEST_VERSION" ]; then
         echo "Kunne ikke finne den nyeste versjonen. Sjekk GitLab API manuelt: $GITLAB_API"
         exit 1
    fi
    echo "Nyeste versjon funnet: $LATEST_VERSION"
    BASE_URL="https://gitlab.com/coolercontrol/coolercontrol/-/releases/$LATEST_VERSION/downloads/packages"
    PACKAGES=( "coolercontrol_${LATEST_VERSION}_amd64_ubuntu.deb" "coolercontrold_${LATEST_VERSION}_amd64_ubuntu.deb" "coolercontrol-liqctld_${LATEST_VERSION}_amd64_ubuntu.deb" )

    for PACKAGE in "${PACKAGES[@]}"; do
         echo "Laster ned $PACKAGE..."
         wget -O "$PACKAGE" "$BASE_URL/$PACKAGE"

         echo "Installerer $PACKAGE..."
         # Forsøk å installere pakken 
         if ! echo "$password" | sudo -S dpkg -i "$PACKAGE"; then
             # Dersom installasjonen mislykkes pga. av manglende avhengigheter, fiks dem:
             echo "$password" | sudo -S apt-get -f install -y
         fi
    done
    echo "Alle cooler control pakkene er lastet ned og installert!"
}


# Pakker ut coolercontrol.tar.gz til /etc/coolercontrol
extract_coolercontrol() {
    if [ -f "coolercontrol.tar.gz" ]; then
         echo "Pakker ut coolercontrol.tar.gz til /etc/coolercontrol..."
         echo "$password" | sudo -S mkdir -p /etc/coolercontrol
         echo "$password" | sudo -S tar -xzvf coolercontrol.tar.gz -C /etc/coolercontrol
         echo "Pakking ferdig!"
    else
         echo "Filen coolercontrol.tar.gz ikke funnet. Hoppet over utpakking."
    fi
}

#########################################
# EKSTRA KONFIGURASJON FOR rEFInd        #
#########################################
# Denne funksjonen oppretter tema-mapper, pakker ut ambience.tar.gz,
# legger til include-erklæring for ambience-theme,
# og prosesserer linjene med "resolution" i /boot/efi/EFI/refind/refind.conf.
configure_refind() {
    CONFIG_DIR="/boot/efi/EFI/refind"
    CONFIG_FILE="$CONFIG_DIR/refind.conf"

    # Sjekk at rEFInd-mappen finnes
    if [ ! -d "$CONFIG_DIR" ]; then
         echo "Mappen $CONFIG_DIR finnes ikke. rEFInd ser ikke ut til å være installert."
         exit 1
    fi

    # Lag tema-mappen for ambience
    echo "Oppretter tema-mappen $CONFIG_DIR/themes/ambience..."
    echo "$password" | sudo -S mkdir -p "$CONFIG_DIR/themes/ambience"

    # Pakk ut ambience.tar.gz dersom den finnes i den nåværende mappen
    if [ -f "ambience.tar.gz" ]; then
         echo "Pakker ut ambience.tar.gz til $CONFIG_DIR/themes/ambience..."
         echo "$password" | sudo -S tar --no-same-owner -xzvf ambience.tar.gz -C "$CONFIG_DIR/themes/ambience"
    else
         echo "Filen ambience.tar.gz ikke funnet. Hoppet over opplasting av theme."
    fi

    # Legg til include-erklæringen for ambiance-theme til slutt i konfigurasjonsfilen, om den ikke allerede finnes
    if grep -q "include themes/ambience/theme.conf" "$CONFIG_FILE"; then
         echo "Include-erklæringen for ambience-theme finnes allerede i $CONFIG_FILE"
    else
         echo "Legger til include-erklæring for ambience-theme i $CONFIG_FILE"
         echo "$password" | sudo -S tee -a "$CONFIG_FILE" <<< "include themes/ambience/theme.conf" >/dev/null
    fi

    # Hent alle aktive (ikke-kommenterte) resolution-linjer
    active_lines=( $(grep -n '^[[:space:]]*resolution' "$CONFIG_FILE" | grep -v '^[[:space:]]*#' | cut -d: -f1) )

    if [ ${#active_lines[@]} -gt 0 ]; then
         echo "Behandler resolution-linjer i $CONFIG_FILE..."
         # Kommentar ut alle aktive resolution-linjer unntatt den siste
         for (( i=0; i<${#active_lines[@]}-1; i++ )); do
              line_num=${active_lines[$i]}
              echo "$password" | sudo -S sed -i "${line_num}s/^/# /" "$CONFIG_FILE"
         done
         # Oppdater siste aktive linje (den skal forbli aktiv) ved å sette inn "resolution max" rett etter
         last_line=${active_lines[-1]}
         echo "$password" | sudo -S sed -i "${last_line}a resolution max" "$CONFIG_FILE"
    else
         echo "Ingen aktive resolution-linjer funnet. Legger til \"resolution max\" på slutten av $CONFIG_FILE."
         echo "$password" | sudo -S tee -a "$CONFIG_FILE" <<< "resolution max" >/dev/null
    fi
}

configure_theme() {
    CONFIG_FILE="gnome-settings.dconf"
    if [ -f "$CONFIG_FILE" ]; then
        echo "Laster inn GNOME-innstillinger fra $CONFIG_FILE..."
        dconf load / < "$CONFIG_FILE"
    else
        echo "Feil: Filen $CONFIG_FILE ble ikke funnet."
    fi
}

configure_extensions() {
    BACKUP_FILE="gnome-extensions-backup.tar.gz"
    EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
    
    if [ -f "$BACKUP_FILE" ]; then
        echo "Oppretter mappen $EXT_DIR hvis den ikke finnes..."
        mkdir -p "$EXT_DIR"
        
        echo "Pakker ut GNOME-extensions fra $BACKUP_FILE..."
        tar -xvzf "$BACKUP_FILE" -C "$EXT_DIR"
        dconf load /org/gnome/shell/extensions/ < gnome-extensions-settings.dconf

    else
        echo "Feil: Filen $BACKUP_FILE ble ikke funnet."
    fi
}

#####################
# HOVEDFUNKSJONEN  #
#####################
main() {
    install_dependencies  # Installerer nødvendige pakker først

    # Kloner repository dersom den ikke allerede eksisterer, og bytt til mappen
    if [ ! -d "machinesetup" ]; then
         echo "Kloner repository..."
         git clone https://github.com/bskjon/machinesetup.git
         cd machinesetup
    else
         cd machinesetup
    fi

    install_fzf
    install_edge
    install_snap
    install_apps_from_app_center
    install_steam
    install_refind
    install_wine
    install_flatpak
    install_gear_lever
    # Konfigurer rEFInd med tema og resolution-oppdateringer
    configure_refind

    install_cooler_control
    extract_coolercontrol

    configure_theme
    configure_extensions

    echo "Alle installasjoner og konfigurasjoner er fullført!"
}

main
