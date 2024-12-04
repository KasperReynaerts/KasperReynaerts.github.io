# Pauze Scheduler by Kasper Reynaerts

## Intro

In dit programma worden er twee agenda's vergeleken om te kijken of er een overeenstemmende pauze is. Die overeenstemmende pauze wordt dan in een nieuwe agenda gestoken waar je met jouw telefoon op kan abboneren. Moesten er meerdere pauze's beschikbaar zijn, wordt de langste gekozen.

## Installatie

### Submodule naar github pages

Om te zorgen dat jouw agenda app kan abboneren op jouw nieuwe agenda, moet je Github Pages instellen. Pages zorgt ervoor dat jouw file kan worden opgeroepen door andere apparaten. [Check hier hoe je een Github Pages repository maakt](https://docs.github.com/en/pages/quickstart#creating-your-website), moest je dat nog niet hebben.

### Shell script instellen

Eens je jouw Pages hebt, kan je jouw Github username plakken in de variabele "Github_username". 
Daarbij kan je ook jouw twee schoolagenda's die je wilt laten vergelijken plakken in de variabelen ics_link1 en ics_link2.
Moest je willen kan je ook de directory waar alle gegevens worden opgeslagen hernoemen door de variabele "project_dir" aan te passen.

### Automatisatie

Moest je willen dat het programma dagelijks draait, kan je een cronjob maken met:
```bash
crontab -e
```
Daarin plaats je dan volgende lijn code om jouw code elke dag om 20u te laten draaien:
```bash
0 20 * * * cd /jouw/pad/waar/script/staat/ && ./scriptnaam.sh >> /jouw/pad/waar/script/staat/cron.log 2>&1
```

## Eventuele errors

Moest je een error tegenkomen van github, ligt het waarschijnlijk aan de verificatie om te mogen pushen naar jouw Github Pages.
Om dat te voorkomen moet je volgende stappen uitvoeren:

### Personal Access Token (PAT) aanmaken
Log in op GitHub.
Ga naar Settings > Developer settings > Personal access tokens > Tokens (classic).
Klik op Generate new token > Generate new token (classic).
Kies een naam (bijvoorbeeld "Cron Task Token") en selecteer geen extra rechten.
Stel een vervaldatum in (bijvoorbeeld 30 dagen).
Klik op Generate token.
Kopieer het token direct, want je kunt het later niet meer zien.

### Remote-URL configureren
Vervang je repository's huidige remote-URL door er een die het token gebruikt:

Open een terminal en navigeer naar je repository:
```bash
cd /pad/naar/submodule.github.io
```

Configureer de URL:
```bash
git remote set-url origin https://<USERNAME>:<TOKEN>@github.com/<USERNAME>/<USERNAME>.github.io.git
```
USERNAME: Je GitHub-gebruikersnaam.
TOKEN: Het gegenereerde PAT.

Test de nieuwe configuratie:
```bash
git pull
```
Als dit zonder foutmeldingen werkt, is de configuratie geslaagd.

### Veiligheid: Token niet in plain text opslaan
Het direct opnemen van een token in een cron-taak is onveilig. Gebruik in plaats daarvan een Git credential helper.

Configureer Git credential helper:
```bash
git config --global credential.helper manager-core
```

Sla het token op: Voer een Git-commando uit dat authenticatie vereist, zoals:
```bash
git pull
```

Vul je gebruikersnaam en het token in wanneer hierom wordt gevraagd. Git slaat deze gegevens veilig op in ~/.git-credentials.
Controleer de opgeslagen gegevens:
```bash
cat ~/.git-credentials
```

De gegevens hebben de volgende indeling:
```
https://<USERNAME>:<TOKEN>@github.com
```

Door volgende lijn in te voeren, zorg je dat enkel jij er aan kan:
```bash
chmod 600 ~/.git-credentials
```

