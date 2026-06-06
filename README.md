# Blackout Prague

Blackout Prague je mobilní aplikace vytvořená ve Flutteru, která pomáhá lidem během krizových situací, hlavně při rozsáhlém výpadku elektřiny v Praze.

Aplikace kombinuje přehledné nouzové informace, mapu důležitých míst, systém zásob, návody pro přežití a experimentální Bluetooth mesh komunikaci mezi zařízeními.

## Hlavní funkce

- Přehledná domovská obrazovka pro krizové situace
- Mapa Prahy s důležitými body
- Možnost spojovat body na mapě
- Sekce s návody pro přežití při blackoutu
- Přehled zásob a nouzového vybavení
- Bluetooth mesh komunikace mezi zařízeními
- Odesílání krátkých textových zpráv přes mesh síť
- Přijaté, odeslané a všechny zprávy v přehledu
- Automatické spuštění mesh sítě po otevření aplikace
- Podpora běhu mesh sítě na pozadí přes Android foreground service
- Moderní tmavé UI ve stylu krizové aplikace

## Cíl projektu

Cílem aplikace je ukázat, jak by mohla fungovat jednoduchá krizová aplikace pro město během blackoutu.

V případě výpadku internetu nebo mobilní sítě může aplikace nabídnout základní informace, lokální návody a experimentální možnost komunikace mezi uživateli přes Bluetooth mesh síť.

## Technologie

Projekt je postavený na:

- Flutter
- Dart
- Android
- Bluetooth Low Energy
- Foreground Service
- SharedPreferences
- Permission Handler
- Offline-first principu

## Bluetooth Mesh

Aplikace obsahuje experimentální Bluetooth mesh systém.

Zařízení mezi sebou mohou předávat krátké zprávy pomocí Bluetooth. Každá zpráva obsahuje unikátní ID, ID odesílatele, čas vytvoření a omezený počet přeposlání pomocí TTL.

Díky tomu lze zabránit nekonečnému přeposílání stejných zpráv a zároveň umožnit šíření zpráv mezi více zařízeními.

Mesh systém je určený hlavně pro nouzové krátké zprávy, například:

- Jsem v pořádku
- Potřebuji vodu
- Potřebuji pomoc
- Mám lékárničku
- Potřebuji se spojit

## Web demo

Aplikace může mít také webové demo vytvořené pomocí Flutter Web.

Webová verze slouží hlavně k ukázce designu, obrazovek a základního ovládání aplikace.

Reálné funkce jako Bluetooth mesh síť, Android oprávnění, foreground service a běh na pozadí fungují pouze v Android aplikaci.

## Android verze

Pro plnou funkčnost je potřeba Android verze aplikace.

Android verze podporuje:

- Bluetooth oprávnění
- Location oprávnění potřebné pro BLE skenování
- Notifikace
- Foreground service
- Automatické spuštění mesh sítě
- Běh mesh sítě na pozadí
- Obnovení stavu po restartu aplikace

## Instalace pro vývojáře

Nejdříve je potřeba mít nainstalovaný Flutter SDK.

Potom spusť:

```bash
flutter pub get

## AI Assistance

Tento projekt byl vytvořen s využitím AI nástrojů.

Na vývoji aplikace se podílel OpenAI Codex jako coding agent pro úpravy, generování a opravy kódu.  
Návrh funkcí, technické konzultace, vysvětlení postupů a části dokumentace byly připravovány s pomocí ChatGPT, modelu GPT-5.5 Thinking.

AI nástroje byly použity jako asistenti při vývoji. Finální rozhodnutí, testování a úpravy projektu byly prováděny autorem projektu.
