# Starling 🌠

> *Astronomy for dreamers, not just scientists.*

Starling is an AI celestial companion that turns cold astronomical data into warm, human narratives. Instead of showing raw coordinates, it tells the story of the sky — weaving together star positions, constellation myths, and atmospheric conditions into poetic, culturally rich prose.

---

## Overview

Most astronomy apps are built for scientists. Starling is built for everyone else.

At its core is **The Bard** — an AI engine that translates real-time celestial positions into storytelling. Whether you're a parent turning a backyard session into a bedtime adventure, a photographer chasing the Aurora Borealis, or simply someone who finds meaning in the night sky, Starling speaks your language.

---

## Who It's For

- **Romantics** — People searching for myth and meaning in the stars.
- **Mobile Astrophotographers** — Optimized for high-latitude users (e.g., Alaska, Oregon) chasing Auroras and dark skies.
- **Parents** — Turning a backyard stargazing session into an interactive, imaginative bedtime story.

---

## Key Features

| Feature | Description |
|---------|-------------|
| **AI Bard Engine** | Generates real-time, context-aware celestial stories from live sky data. |
| **Atmospheric Awareness** | Tailors suggestions based on your specific latitude, weather, and visibility. |
| **Creative Prompts** | Intelligent guides for capturing the perfect celestial photograph. |
| **Dual Sky Cultures** | Presents both Western (IAU) and Chinese constellation traditions side by side. |

---

## Roadmap

- [ ] **API Integration** — Connect to high-precision real-time astronomical data.
- [ ] **Voice Tuning** — Refine the "Bard" persona to ensure the tone stays poetic, not robotic.
- [ ] **Location Beta** — Test Aurora prediction accuracy for users in Alaska and Oregon.
- [ ] **Social Cards** — Build the "Celestial Postcard" feature for sharing AI-narrated photos.

---

## Data Sources

Starling's star catalog and constellation data are compiled from the following open astronomical datasets:

| Dataset | Source | License |
|---------|--------|---------|
| **Hipparcos Star Catalogue** (primary) | [ESA/CDS VizieR I/239](https://cdsarc.cds.unistra.fr/viz-bin/cat/I/239) | ESA/CDS |
| **HYG Database v38** (fallback) | [astronexus/HYG-Database](https://github.com/astronexus/HYG-Database) — David Nash | CC BY-SA 4.0 |
| **IAU Constellation Lines** | [Stellarium modern skyculture](https://github.com/Stellarium/stellarium/tree/master/skycultures/modern) | GPL-2.0+ |
| **IAU Constellation Boundaries** | [Davenhall & Leggett VI/49](https://cdsarc.cds.unistra.fr/viz-bin/cat/VI/49) — CDS | CDS |
| **Chinese Sky Culture** | [Stellarium Chinese skyculture](https://github.com/Stellarium/stellarium/tree/master/skycultures/chinese) | GPL-2.0+ |

> Raw data files are not bundled with the app. They are downloaded and compiled into compact binary assets by the [data pipeline](tool/README.md) at build time.

---

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) 3.41+
- [Dart](https://dart.dev/get-dart) 3.x

### Run the app

```bash
flutter pub get
flutter run
```

### Rebuild data assets (optional)

The compiled star catalog is already included in `assets/bin/`. To regenerate it from raw sources:

```bash
cd tool/
./generate_bins.sh   # downloads sources + runs the pipeline
```

See [tool/README.md](tool/README.md) for full pipeline documentation.

---

## Tech Stack

- **Flutter** — cross-platform UI (iOS, Android, Web)
- **FlatBuffers** — compact binary format for the star catalog
- **Dart** — data pipeline and app logic

---

## License

This project is open source. See [LICENSE](LICENSE) for details.

Third-party data is subject to their respective licenses as listed in the [Data Sources](#data-sources) table above.
