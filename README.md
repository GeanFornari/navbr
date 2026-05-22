# navbr

Aplicativo de navegação aeronáutica (Moving Map) para o espaço aéreo brasileiro.

## Visão Geral

**navbr** é um aplicativo Flutter de navegação aérea em tempo real com cartas do DECEA (Departamento de Controle do Espaço Aéreo). Renderiza a posição da aeronave (GPS) sobre cartas aeronáuticas georreferenciadas offline — WAC, ENRC, IAC, ARC e demais tipos do pacote AISWEB.

## Funcionalidades

- **Moving Map:** Posição GPS em tempo real plotada sobre cartas georreferenciadas.
- **Cartas WAC e ENRC:** Suporte a World Aeronautical Charts e En-Route Charts (GeoTIFF via `OverlayImageLayer`).
- **Overlay ARC:** Aerodrome Radar Charts sobrepostas automaticamente ao selecionar ENRC.
- **Cartas de Procedimento (IAC, SID, STAR):** GeoPDF com metadados OGC renderizados como overlay.
- **Download integrado:** Catálogo completo de cartas do ciclo AIRAC via Cloudflare R2, com progresso por grupo e indexação local no Hive.
- **Busca de cartas online:** Busca de cartas de aeródromo por ICAO direto do AISWEB.
- **Offline First:** Todas as cartas baixadas ficam em cache local.
- **Orientação Norte / Track Up.**

## Configuração

1. Copie `.env.example` para `.env` e preencha as credenciais da API AISWEB.
2. `flutter pub get`
3. `flutter run`

## Infraestrutura relacionada

- **charts_loader_cli** — CLI Dart que baixa, processa e empacota as cartas do DECEA em ciclos AIRAC. Roda via GitHub Actions e publica o pacote no Cloudflare R2.
- **R2 público:** `https://pub-cca17949fcc04b1ca9e632ae8b19d69c.r2.dev/`

## Pendências conhecidas (Technical Debt)

- GeoTIFFs carregados inteiramente na RAM → OOM em devices físicos. **Fix planejado: MBTiles.** Ver `Docs/mbtiles-migration.md`.
- IAC `/LPTS` lido mas não aplicado — overlay alinha pela folha A4 completa, não pelo mapa recortado.
