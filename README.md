# ThermoScan

ThermoScan is a system for monitoring photovoltaic panels and detecting thermal hotspots. It uses a thermal sensor to scan the panel, measures electrical data, and aims to clean affected areas automatically with a targeted water jet.

A mobile app lets users view measurements and monitor the system. The embedded device sends data to cloud services for storage and access through the app.

## Repository structure

- `app/` — Mobile application.
- `firmware/` — ESP32 code for sensors, hotspot detection, and cleaning control.
- `backend/` — Cloud API and data storage.
- `hardware/` — Electrical schematics, PCB files, and 3D models.
- `docs/` — Requirements, architecture, and communication documentation.
