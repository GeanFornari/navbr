# navbr

Aeronautical Moving Map navigation application for Brazilian airspace.

## Overview

**navbr** is a standalone, real-time aeronautical navigation application built with Flutter. It utilizes charts from DECEA (Brazil's Department of Airspace Control) to provide a dynamic Moving Map experience, overlaying aircraft position (GPS) securely onto geo-referenced aviation charts (WAC, IAC, etc.).

## Features

- **Real-time Navigation (Moving Map):** Live GPS plotting directly over georeferenced charts.
- **WAC Support:** Reads and displays World Aeronautical Charts via embedded GeoTIFF metadata.
- **IAC Support:** Reads and extracts OGC coordinate data from Instrument Approach Charts (GeoPDF).
- **Offline First Approach:** Downloads and locally caches charts for seamless offline use.
- **Flight Orientation:** Supports North Up and Track Up rendering.

## Setup

1. Copy `.env.example` to `.env` and fill in the necessary API keys.
2. Run `flutter pub get`
3. Run the application with `flutter run`
