# Diretrizes de Desenvolvimento — navbr

## 1. Versões e Dependências

- **Sempre utilize as versões mais recentes** (latest) de todos os pacotes do Flutter/Dart.
- Em caso de conflitos de dependência, priorizar a atualização do pacote mais antigo ou utilizar `dependency_overrides` no `pubspec.yaml`. Nunca fazer downgrade em cascata.

## 2. Arquitetura

- **State management:** Riverpod (`Notifier` / `NotifierProvider`). Não usar `ChangeNotifier`.
- **Navegação:** `go_router` com `StatefulShellRoute.indexedStack` (5 tabs).
- **Persistência local:** Hive para índice de cartas (`ChartIndex`), `SharedPreferences` para configurações simples.
- **Cartas base:** `ChartSettingsProvider` carrega cartas do DB por tipo e as expõe como `List<BaseChart>` com `path` + `bbox`.
- **Backend/CLI:** `charts_loader_cli` (projeto separado) — responsável por baixar, processar e empacotar as cartas. O app não faz parsing pesado; recebe bbox pronto via manifest.

## 3. Regras de Código

- Manter serviços isolados:
  - `AiswebApiService` — comunicação com a API AISWEB (XML).
  - `R2Service` — download de cartas do Cloudflare R2.
  - `DatabaseService` — CRUD do Hive (`ChartIndex`).
  - Parsers geográficos (`GeoTiffParser`, `GeoPdfParser`) — isolados, sem dependência de UI.
- Seguir as restrições de UI do `CLAUDE.md`: sem `AppBar`, sempre `AppColors`, sempre `SafeArea`.

## 4. Cartas — Tipos e Fontes

| Tipo | Fonte | Formato | Renderização atual |
|---|---|---|---|
| WAC | WMS GeoAISWEB | GeoTIFF `.tif` | `FileImage` → `OverlayImageLayer` |
| ENRC (H/L) | WMS GeoAISWEB | GeoTIFF `.tif` | `FileImage` → `OverlayImageLayer` |
| ARC | WMS GeoAISWEB | GeoTIFF `.tif` | `FileImage` → `OverlayImageLayer` (overlay automático com ENRC) |
| REA / REH / CCV | WMS GeoAISWEB | GeoTIFF `.tif` | `FileImage` → `OverlayImageLayer` |
| IAC / SID / STAR / ADC | AISWEB API | GeoPDF `.pdf` | `pdfx` → PNG 1× → `OverlayImageLayer` |

> **Nota:** A renderização via `FileImage` de GeoTIFFs causa OOM em devices físicos. A migração para MBTiles está documentada em `Docs/mbtiles-migration.md`.
