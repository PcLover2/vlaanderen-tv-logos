#!/bin/bash

# Functie om gelogde berichten te tonen met timestamp en logniveau
log() {
    local level="$1"
    shift
    local message="$*"
    echo "$(date +'%H:%M:%S') - $level: $message"
}

# Controleer of het juiste aantal argumenten is doorgegeven
if [[ $# -ne 2 && $# -ne 3 ]]; then
    log "ERROR" "Gebruik: $0 <breedte> <hoogte> [light|dark]"
    exit 1
fi

# Haal de afmetingen en de kleurinstelling uit de argumenten
breedte=$1
hoogte=$2
kleur=${3:-default}  # Standaard naar 'default' als geen kleur is opgegeven

# Controleer of het tekstbestand met iconen bestaat
if [[ ! -f "icons.txt" ]]; then
    log "ERROR" "Het bestand icons.txt bestaat niet in de huidige map."
    exit 1
fi

# Installeer benodigde tools als ze niet geïnstalleerd zijn
if ! command -v wget &> /dev/null; then
    log "INFO" "wget wordt geïnstalleerd..."
    sudo apt-get install wget
fi

if ! command -v convert &> /dev/null; then
    log "INFO" "ImageMagick wordt geïnstalleerd..."
    sudo apt-get install imagemagick
fi

if ! command -v rsvg-convert &> /dev/null; then
    log "INFO" "rsvg-convert wordt geïnstalleerd..."
    sudo apt-get install librsvg2-bin
fi

# Maak een map voor de gedownloade en geconverteerde afbeeldingen
mkdir -p icons

# Lees het tekstbestand en verwerk elke regel
while IFS= read -r icon_name || [[ -n "$icon_name" ]]; do
    downloaded=false

    # Probeer de kleurversie te downloaden
    for kleurversie in "$kleur" default; do
        icon_file="${icon_name}.${kleurversie}.svg"
        url="https://raw.githubusercontent.com/picons/picons/master/build-source/logos/${icon_file}"
        wget -q "$url" -O "icons/${icon_file}"

        if [[ $? -eq 0 ]]; then
            log "INFO" "Download geslaagd voor ${icon_file}"
            downloaded=true
            break
        else
            rm -f "icons/${icon_file}"

            # Probeer PNG als de SVG-download mislukt
            icon_file="${icon_name}.${kleurversie}.png"
            url="https://raw.githubusercontent.com/picons/picons/master/build-source/logos/${icon_file}"
            wget -q "$url" -O "icons/${icon_file}"

            if [[ $? -eq 0 ]]; then
                log "INFO" "Download geslaagd voor ${icon_file}"
                downloaded=true
                break
            else
                rm -f "icons/${icon_file}"
                log "WARNING" "Kleurversie '${kleurversie}' bestaat niet voor ${icon_name}"
            fi
        fi
    done

    # Als geen bestand is gedownload, sla deze iteratie over
    if [[ ! -f "icons/${icon_file}" ]]; then
        log "WARNING" "Geen geldige afbeelding gedownload voor ${icon_name}. Skipping."
        continue
    fi

    # Stap 1: Converteer SVG naar PNG met behoud van transparantie met rsvg-convert
    if [[ "${icon_file##*.}" == "svg" ]]; then
        rsvg-convert "icons/${icon_file}" -a -w 2000 -h 2000 -o "icons/${icon_name}_converted.png"
        
        # Controleer of de conversie geslaagd is
        if [[ $? -ne 0 ]]; then
            log "ERROR" "Conversie mislukt voor ${icon_file}"
            rm "icons/${icon_file}"
            continue
        fi
    else
        cp "icons/${icon_file}" "icons/${icon_name}_converted.png"
    fi

    # Verkrijg de afmetingen van de geconverteerde afbeelding
    dimensions=$(identify -format "%wx%h" "icons/${icon_name}_converted.png")
    orig_width=${dimensions%x*}
    orig_height=${dimensions#*x}

    # Bereken verhoudingen
    ratio_original_width=$(echo "scale=6; $orig_width / $orig_height" | bc)
    ratio_target_width=$(echo "scale=6; $breedte / $hoogte" | bc)
    ratio_target_height=$(echo "scale=6; $hoogte / $breedte" | bc)

    if (( $(echo "$ratio_original_width < $ratio_target_width" | bc -l) )); then
        # Schaal op basis van de opgegeven hoogte
        scale_height=$hoogte
        scale_width=$(echo "scale=0; $orig_width * $hoogte / $orig_height" | bc)
    else
        # Schaal op basis van de opgegeven breedte
        scale_width=$breedte
        scale_height=$(echo "scale=0; $orig_height * $breedte / $orig_width" | bc)
    fi

    # Zorg ervoor dat transparantie wordt behouden tijdens het schalen
    convert "icons/${icon_name}_converted.png" -resize "${scale_width}x${scale_height}" -background transparent -gravity center -extent "${scale_width}x${scale_height}" "icons/${icon_name}_scaled.png"

    # Stap 3: Vul de afbeelding aan met transparantie om de afbeelding op de gewenste afmeting te krijgen
    convert "icons/${icon_name}_scaled.png" -background transparent -gravity center -extent "${breedte}x${hoogte}" "icons/${icon_name}.png"

    # Verwijder tijdelijke bestanden
    rm "icons/${icon_name}_converted.png"
    rm "icons/${icon_name}_scaled.png"
    rm "icons/${icon_file}"

done < "icons.txt"

log "INFO" "Klaar! De iconen zijn gedownload, geconverteerd en bijgevuld met transparantie."
