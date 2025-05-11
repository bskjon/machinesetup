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

# Funksjonen for å installere fzf og legge til init i .bashrc
install_fzf() {
    echo "Installerer fzf..."
    echo "$password" | sudo -S apt install -y fzf
    if ! grep -q 'fzf --bash' "$HOME/.bashrc"; then
        echo 'eval "$(fzf --bash)"' >> "$HOME/.bashrc"
    fi
}

# Funksjon for å installere Microsoft Edge
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

# Funksjon for å installere snapd (dersom ikke allerede installert)
install_snap() {
    echo "Installerer snapd (dersom ikke allerede installert)..."
    echo "$password" | sudo -S apt install -y snapd
}

# Funksjon for å installere apper via Snap
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

# Funksjon for å laste ned og installere Steam
install_steam() {
    echo "Laster ned Steam DEB-pakke fra Valve..."
    wget -O steam_latest.deb "https://steamcdn-a.akamaihd.net/client/installer/steam.deb"
    echo "Installerer Steam..."
    echo "$password" | sudo -S dpkg -i steam_latest.deb || echo "$password" | sudo -S apt install -f -y
}

# Funksjon for å installere rEFInd
install_refind() {
    echo "Installerer rEFInd..."
    echo "$password" | sudo -S apt-add-repository ppa:rodsmith/refind -y
    echo "$password" | sudo -S apt-get update
    echo "$password" | sudo -S apt-get install -y refind
    echo "rEFInd er nå installert!"
}

# Funksjon for å installere cooler control-pakker ved å hente nyeste utgave fra GitLab API
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
    done
    echo "Alle cooler control pakkene er lastet ned!"
}

# Funksjon for å pakke ut coolercontro.tar.gz til /etc/coolercontrol
extract_coolercontrol() {
    if [ -f "coolercontro.tar.gz" ]; then
         echo "Pakker ut coolercontro.tar.gz til /etc/coolercontrol..."
         echo "$password" | sudo -S mkdir -p /etc/coolercontrol
         echo "$password" | sudo -S tar -xzvf coolercontro.tar.gz -C /etc/coolercontrol
         echo "Pakking ferdig!"
    else
         echo "Filen coolercontro.tar.gz ikke funnet. Hoppet over utpakking."
    fi
}

# Hovedfunksjon: Kloner repoet (dersom ikke allerede klonet) og kjører installasjonsfunksjonene
main() {
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
    install_cooler_control
    extract_coolercontrol

    echo "Alle installasjoner er fullført!"
}

main
