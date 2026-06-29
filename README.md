# LEX Crafting

Modernes **ESX Crafting-System** für FiveM mit React-NUI, integriertem **Ingame-Creator** und **MySQL-basierter Konfiguration**. Rezepte, Crafting Points, Blips, Jobs und Kategorien lassen sich ohne Config-Dateien verwalten.

---

## Features

### Crafting (Spieler)
- Crafting-UI mit Kategorien, Zutaten-Anzeige und Warteschlange
- Crafting Points als **Marker**, **Ped** oder **Objekt**
- Job- und Rang-Beschränkungen (pro Point und pro Rezept)
- Integration mit **ox_inventory** (Material-Check & Item-Abgabe)
- Erfolgsrate, Craft-Zeit und Yield pro Rezept
- Abholen fertiger Items aus der Queue

### Creator (Admin)
- Ingame-Editor für Rezepte, Points und Einstellungen
- Blip-Konfiguration (Sprite, Farbe, Skalierung, **eigener Name**)
- Marker-, Koordinaten- und Interaktions-Radius
- Kategorien mit Rezept-Zuordnung pro Point
- **Teleport zum Point** zum schnellen Positionieren
- Speichern direkt in die Datenbank (Batch-Insert, Partial-Save)

### Technik
- **ESX Legacy** + **oxmysql** + **ox_inventory**
- React 18 / Vite UI (mitgeliefert unter `ui/`)
- SQL-Schema inkl. Legacy-Import-Skript
- Deutsch & Englisch (Locales)

---

## Abhängigkeiten

| Pflicht | Optional |
|---------|----------|
| es_extended (ESX Legacy) | ox_lib (Notifications) |
| oxmysql | |
| ox_inventory | |
| MySQL / MariaDB | |

Details: [DEPENDENCIES.md](./DEPENDENCIES.md)

---

## Installation

### 1. Resource einbinden

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory

ensure soh_crafting
```

### 2. Datenbank importieren

```sql
source sql/install.sql
```

Optional:

```sql
source sql/import_basics.sql
source sql/import_legacy.sql
```

### 3. Konfiguration

In `shared/config.lua` anpassen:

- `Config.AdminGroups` – wer den Creator nutzen darf
- `Config.CreatorCommand` – Standard: `craftingcreator`
- `Config.Locale` – `de` oder `en`
- `Config.AllowCreatorForAll` – nur für Tests (`false` in Production)

---

## Befehle & Tasten

| Aktion | Befehl / Taste |
|--------|----------------|
| Creator öffnen | `/craftingcreator` oder **F7** |
| Crafting Point nutzen | **E** am Point (Standard) |

---

## Projektstruktur

```
soh_crafting/
├── client/          # Points, NUI, Bootstrap
├── server/          # DB, Crafting, Config-Store
├── shared/          # Config
├── locales/         # de / en
├── sql/             # install.sql, import_legacy.sql             
└── ui/             # UI
```

### UI neu bauen (Entwickler)

```bash
cd web
npm install
npm run build
```

---

## Lizenz

Nutze diese Resource auf eigenes Risiko. Beachte die Lizenzen von ESX, oxmysql, ox_inventory und weiteren Abhängigkeiten.
