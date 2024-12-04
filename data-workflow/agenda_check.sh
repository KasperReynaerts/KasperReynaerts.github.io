#!/bin/bash

# Variabelen
ics_link1="https://cloud.timeedit.net/be_hogent/web/student/ri6765Q0ZuY9u1Q5QtQn55B8ZQ1Qy55dZQ168Z856655CwtZAEFZB18C8603D31164E6369EF9915B0.ics"
ics_link2="https://cloud.timeedit.net/be_hogent/web/student/ri6887Q6ZuY9u1Q6QtQn5619ZQ3Qy57dZQ868Z8567557wtZ89DZ3D454451B0A42DE7156CFF7C2D.ics"

project_dir="./pauze_scheduler"

tomorrow="$(date -d "tomorrow" +%Y%m%d)"

Github_username="KasperReynaerts"

repo_path="./${Github_username}.github.io/" 


# Controleer op vereiste tools
echo "Controleer of vereiste tools beschikbaar zijn..."
if ! command -v ical2json &> /dev/null; then
    echo "Het hulpprogramma ical2json is niet geïnstalleerd. Installeren..."
    apt-get update && apt-get install -y ical2json
else
    echo "ical2json is geïnstalleerd."
fi

if ! command -v jq &> /dev/null; then
    echo "Het hulpprogramma jq is niet geïnstalleerd. Installeren..."
    apt-get update && apt-get install -y jq
else
    echo "jq is geïnstalleerd."
fi


# Projectdirectory instellen
mkdir -p "$project_dir"
echo "Projectdirectory ingesteld: $project_dir"

# Download ICS-bestanden
echo "ICS-bestanden downloaden..."
curl -s -o "$project_dir/agenda1.ics" "$ics_link1"
chmod 444 "$project_dir/agenda1.ics"
curl -s -o "$project_dir/agenda2.ics" "$ics_link2"
chmod 444 "$project_dir/agenda2.ics"


# Controleer of downloads gelukt zijn
if [[ ! -s "$project_dir/agenda1.ics" || ! -s "$project_dir/agenda2.ics" ]]; then
    echo "Fout bij downloaden van ICS-bestanden, het script wordt beëindigd."
    exit 1
else
    echo "ICS-bestanden succesvol gedownload."
fi

# Converteer ICS naar JSON
echo "Converteer ICS naar JSON..."
ical2json "$project_dir/agenda1.ics" > "$project_dir/agenda1.json"
chmod 444 "$project_dir/agenda1.json"
ical2json "$project_dir/agenda2.ics" > "$project_dir/agenda2.json"
chmod 444 "$project_dir/agenda2.json"

# Controleer of de JSON-bestanden correct zijn
if [[ ! -s "$project_dir/agenda1.json" || ! -s "$project_dir/agenda2.json" ]]; then
    echo "Fout bij het converteren naar JSON, het script wordt beëindigd."
    exit 1
else
    echo "ICS-bestanden succesvol geconverteerd naar JSON."
fi

# Filter de agenda voor morgen
echo "Filter de agenda voor de datum: $tomorrow"
for i in 1 2
do
    jq --arg tomorrow "$tomorrow" '
        .VCALENDAR[0].VEVENT | map(select((.DTSTART | tostring) | startswith($tomorrow)))' "$project_dir/agenda$i.json" > "$project_dir/agenda${i}_${tomorrow}.json"
    if [[ ! -s "$project_dir/agenda${i}_${tomorrow}.json" ]]; then
        echo "Geen evenementen gevonden voor $tomorrow in agenda$i.json, het script wordt beëindigd."
        exit 1
    else
        echo "Agenda $i voor morgen succesvol gefilterd."
    fi
done

# Bereken gaps en sla de resultaten op
echo "Bereken gaps in de agenda's..."
for i in 1 2
do
    json_file="$project_dir/agenda${i}_${tomorrow}.json"
    output_file="$project_dir/agenda${i}_${tomorrow}_gaps.json"

    jq '
        . as $events |
        reduce range(0; length - 1) as $i (
            [];
            . + [{
                "start": $events[$i].DTEND,
                "end": $events[$i + 1].DTSTART,
                "gap_minutes": (
                    ($events[$i + 1].DTSTART | split("T")[1] | sub("Z$"; "")) as $start |
                    ($events[$i].DTEND | split("T")[1] | sub("Z$"; "")) as $end |
                    (($start[0:2] | tonumber) * 60 + ($start[2:4] | tonumber)) - 
                    (($end[0:2] | tonumber) * 60 + ($end[2:4] | tonumber))
                )
            }]
        )
    ' "$json_file" > "$output_file"

    if [[ ! -s "$output_file" ]]; then
        echo "Fout bij het berekenen van gaps voor agenda$i, het script wordt beëindigd."
        exit 1
    else
        echo "Gaps succesvol berekend voor agenda$i."
    fi
done

# Vergelijk de pauzes en zoek overlappen
echo "Vergelijk pauzes voor overlappen..."
common_gap=$(jq -n --slurpfile file1 "$project_dir/agenda1_${tomorrow}_gaps.json" --slurpfile file2 "$project_dir/agenda2_${tomorrow}_gaps.json" '
  [
    $file1[0][] as $gap1 |
    $file2[0][] as $gap2 |
    select(
      (
        ($gap1.start | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) < (
        ($gap2.end | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) and (
        ($gap2.start | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) < (
        ($gap1.end | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      )
    ) | {
      "common_start": (if (
        ($gap1.start | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) > (
        ($gap2.start | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) then $gap1.start else $gap2.start end),
      "common_end": (if (
        ($gap1.end | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) < (
        ($gap2.end | sub("Z$"; "")) |
        strptime("%Y%m%dT%H%M%S") |
        mktime
      ) then $gap1.end else $gap2.end end),
      "gap_minutes": (if (
        ($gap1.gap_minutes) < ($gap2.gap_minutes)
      ) then $gap2.gap_minutes else $gap1.gap_minutes end)
    }
  ] | reduce .[] as $gap (
    null;
    if $gap == null or ($gap.gap_minutes > .gap_minutes) then $gap else . end
  )
')

# Controleer of er gemeenschappelijke pauzes zijn
if [[ "$common_gap" == "null" || -z "$common_gap" ]]; then
    echo "Geen gemeenschappelijke pauzes gevonden."
    exit 1
else
    echo "Gemeenschappelijke pauze gevonden: $common_gap"
fi

# Haal de start- en eindtijden uit het resultaat
new_start=$(echo "$common_gap" | jq -r '.common_start')
new_end=$(echo "$common_gap" | jq -r '.common_end')



# Maak de nieuwe agenda aan (alleen als de gap is gevonden)
if [[ "$common_gap" != "null" && -n "$common_gap" ]]; then

  # Check de repository status

  # URL van de submodule en doelpad
  SUBMODULE_URL="https://github.com/${Github_username}/${Github_username}.github.io.git"

  echo "Submodule toevoegen..."
  if git submodule add "$SUBMODULE_URL" "$repo_path" 2>/dev/null; then
    echo "Submodule succesvol toegevoegd: $repo_path"
  else
    echo "Submodule al toegevoegd of fout opgetreden."
    echo "Controleren of de submodule correct is ingesteld..."
    if [ -d "$repo_path" ]; then
        echo "Submodule-directory bestaat: $repo_path"
        git submodule update --init --recursive
        echo "Submodule geïnitialiseerd en bijgewerkt."
    else
        echo "Submodule-directory ontbreekt. Controleer de URL of paden."
        exit 1
    fi
  fi

# Controleren of de submodule werkt
if git ls-remote "$SUBMODULE_URL" &>/dev/null; then
    echo "Submodule-repository bereikbaar."
else
    echo "Submodule-repository niet bereikbaar. Controleer de URL of netwerkverbinding."
    exit 1
fi


    cd "$repo_path" || exit
    echo "Navigeren naar de repository..."

    echo "Nieuwe agenda aanmaken met pauze van $new_start tot $new_end..."

    # Maak een nieuwe agenda met de gevonden pauze
    cat > agenda.ics <<EOF
BEGIN:VCALENDAR
VERSION:2.0
X-WR-CALNAME:Pauze-agenda
X-PUBLISHED-TTL:PT6H
CALSCALE:GREGORIAN
BEGIN:VEVENT
SUMMARY:Vrije tijd voor pauze samen
DTSTART:${new_start}
DTEND:${new_end}
LOCATION:Schoonmeersen
DESCRIPTION:Vrij moment om samen af te spreken
END:VEVENT
END:VCALENDAR
EOF

    

    # Voeg bestand toe aan Git
    git add agenda.ics
    git commit -m "Nieuwe agenda toegevoegd"

    # Push naar de juiste branch
    echo "Pushen naar de GitHub repository..."
    git push origin main
else
    echo "Geen gemeenschappelijke pauze gevonden, geen agenda aangemaakt."
fi
echo "--------------------------------------------------"