![Showcase](https://i.ibb.co/Xrz2c4zr/grafik.png)  ![Showcase2](https://i.ibb.co/JjrGyZLz/grafik.png)

Modern **ESX crafting system** for FiveM with React NUI, built-in **in-game creator**, and **MySQL-based configuration**. Manage recipes, crafting points, blips, jobs, and categories without editing config files.

---

## Features

### Crafting (Players)
- Crafting UI with categories, ingredient display, and queue
- Crafting points as **marker**, **ped**, or **object**
- Job and grade restrictions (per point and per recipe)
- **ox_inventory** integration (material checks and item delivery)
- Success rate, craft time, and yield per recipe
- Collect finished items from the queue

### Creator (Admin)
- In-game editor for recipes, points, and settings
- Blip configuration (sprite, color, scale, **custom name**)
- Marker, coordinate, and interaction radius
- Categories with recipe assignment per point
- **Teleport to point** for quick positioning
- Save directly to the database (batch insert, partial save)

### Technical
- **ESX Legacy** + **oxmysql** + **ox_inventory**
- React 18 / Vite UI (bundled under `ui/`)
- SQL schema including legacy import script
- German and English locales

---

## Dependencies

| Required | Optional |
|----------|----------|
| es_extended (ESX Legacy) | ox_lib (notifications) |
| oxmysql | |
| ox_inventory | |
| MySQL / MariaDB | |

Details: [DEPENDENCIES.md](./DEPENDENCIES.md)

---

## Installation

### 1. Add the resource

```cfg
ensure oxmysql
ensure es_extended
ensure ox_inventory

ensure lex_crafting
```

### 2. Import the database

```sql
source sql/install.sql
```


### 3. Configuration

Edit `shared/config.lua`:

- `Config.AdminGroups` – who can use the creator
- `Config.CreatorCommand` – default: `craftingcreator`
- `Config.Locale` – `de` or `en`
- `Config.AllowCreatorForAll` – testing only (`false` in production)

---

## Commands & Keys

| Action | Command / Key |
|--------|---------------|
| Open creator | `/craftingcreator` or **F7** |
| Use crafting point | **E** at the point (default) |

---

## Project Structure

```
lex_crafting/
├── client/          # Points, NUI, bootstrap
├── server/          # DB, crafting, config store
├── shared/          # Config
├── locales/         # de / en
└── ui/             # UI 
```
---

## License

Use this resource at your own risk. Respect the licenses of ESX, oxmysql, ox_inventory, and other dependencies.
