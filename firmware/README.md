# TermoScan Firmware

Firmware for the TermoScan embedded device, based on the ESP32. It reads thermal and electrical data from a photovoltaic panel, detects potential hotspots, controls the scanning and cleaning mechanisms, and sends measurements to the cloud via Wi-Fi.

## Main responsibilities

- Capture thermal readings from the MLX90640 sensor.
- Measure panel voltage and current.
- Move the scanning module along the panel.
- Detect hotspots and trigger localized cleaning when appropriate.
- Record measurements and cleaning events.
- Send device data to the cloud.

## Status

Under development.
