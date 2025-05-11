# Machine Setup Script

Dette skriptet automatiserer installasjonen av flere programmer og verktøy på et Ubuntu-basert system.

## Instruksjoner

For å kjøre dette installasjonsskriptet, bruk følgende kommando i terminalen:

```bash
bash -c "$(wget -qO- https://raw.githubusercontent.com/bskjon/machinesetup/refs/heads/master/install.sh)"
```
Funksjoner
Skriptet inneholder følgende installasjoner:

Autentisering med sudo: Ber om brukerpassord for å utføre administrative kommandoer.

fzf: Et kommandolinjeverktøy for interaktiv fil- og tekstsøk.

Microsoft Edge: Laster ned og installerer den nyeste versjonen av Microsoft Edge.

Snap-pakker: Installerer snapd og en samling populære apper via Snap:

IntelliJ IDEA Community

Android Studio

Discord

Spotify

Steam: Laster ned Steam-installasjonsfilen direkte fra Valve og installerer den.

rEFInd: Installerer rEFInd boot manager.

CoolerControl: Laster ned og installerer den nyeste versjonen av CoolerControl fra GitLab.

Avhengigheter
Skriptet krever:

sudo-tilgang

wget for nedlastinger

jq for parsing av GitLab API

Sørg for at systemet ditt har internettilgang for å laste ned nødvendige pakker.

Bruk
Kjør scriptet ved å kopiere og lime inn kommandoen over i terminalen din. Etter installasjonen, kan du starte programmene som vanlig fra systemmenyen eller terminalen.

God installering!
