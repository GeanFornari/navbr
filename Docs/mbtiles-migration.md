# Migração GeoTIFF → MBTiles

**Objetivo:** Eliminar OOM no device físico ao renderizar cartas WAC/ENRC.  
**Causa raiz:** `FileImage` carrega o raster inteiro (~174MB/tile, ~500MB+ decodificado RGBA) na RAM.  
**Solução:** MBTiles — SQLite com tiles 256×256 px. App carrega só os tiles visíveis no viewport (~5MB em uso).

---

## Por que MBTiles e não PNG/PDF

PNG e PDF são containers diferentes para o mesmo pixel data. No momento que o Flutter decodifica qualquer um deles com `FileImage` ou `pdfx`, o bitmap inteiro vai para a RAM. Não resolve o OOM.

MBTiles resolve porque parte a imagem em pedaços pequenos e só carrega o que está na tela. Alternativa equivalente: **PMTiles** (suporta HTTP range requests direto do R2, sem baixar o arquivo completo — considerar no futuro).

---

## Pipeline atual (referência)

```
charts_loader_cli (Dart)
  ├── Descobre: WMS GetCapabilities + AISWEB API
  ├── Baixa: WMS → .tif  |  AD → .pdf
  ├── Extrai bbox: GeoTIFF (metadata WMS) | PDF (regex /GPTS)
  └── Empacota: build/package/airac_YYYY-MM-DD/
        ├── vfr/wac/WAC_*.tif
        ├── rota/enrc/ENRC_*.tif
        ├── vfr/rea/REA_*.tif  vfr/ccvRea/  vfr/ccvReh/  vfr/reh/
        ├── ifr/arc/  ifr/iac/  ifr/sid/  ifr/star/  ifr/adc/ ...  (PDFs)
        └── manifest.json  ←  {path, size, sha256, bbox?}

GitHub Actions (update.yml)
  └── aws s3 sync build/package → R2 + latest.json

App navbr
  ├── R2Service.fetchLatest()  →  {emenda, folder}
  ├── R2Service.fetchManifest()  →  lista de arquivos + bboxes
  ├── R2Service.downloadFile()  →  /Documents/charts/airac_YYYY-MM-DD/{especie}/{tipo}/{file}
  ├── ChartIndex salvo no Hive (key=path, type, bbox)
  └── ChartSettingsProvider carrega por type → FileImage → OverlayImageLayer  ← PROBLEMA
```

---

## Pipeline alvo (com MBTiles)

```
charts_loader_cli  →  build/package/*.tif (sem mudança)
                              ↓
                    [NOVO — GitHub Actions, após o dart run]
                    gdal2mbtiles  →  *.mbtiles  (substitui .tif)
                    manifest.json atualizado (.tif → .mbtiles)
                              ↓
                         Upload R2
                              ↓
              App baixa .mbtiles (mesmo flow, extensão diferente)
                              ↓
           flutter_map_mbtiles renderiza só tiles visíveis  ✓
```

---

## Parte 1 — CI/CD (charts_loader_cli)

### Arquivo: `.github/workflows/update.yml`

Adicionar etapa **após** `dart run charts_loader_cli package`, **antes** do `aws s3 sync`:

```yaml
- name: Install GDAL
  run: sudo apt-get install -y gdal-bin

- name: Convert GeoTIFFs to MBTiles
  run: |
    find build/package -name "*.tif" | while read tif; do
      mbtiles="${tif%.tif}.mbtiles"
      gdal2mbtiles \
        --zoom=5-12 \
        --resampling=bilinear \
        --format=JPEG \
        --quality=75 \
        "$tif" "$mbtiles"
      rm "$tif"
    done

- name: Rebuild manifest (replace .tif → .mbtiles paths + recalculate sizes/hashes)
  run: dart run charts_loader_cli remanifest
  # OU: script Python/bash que relê os .mbtiles e regera o manifest.json
```

> **Alternativa ao gdal2mbtiles:** `gdal2tiles.py` + `mbutil` (mb-util).  
> `gdal2mbtiles` é mais direto: `pip install gdal2mbtiles`.

### Parâmetros de conversão sugeridos

| Parâmetro | Valor | Razão |
|---|---|---|
| `--zoom` | 5-12 | Z5 = overview Brasil, Z12 = detalhe suficiente para rota |
| `--format` | JPEG | Lossy aceitável para cartas base; ~3× menor que PNG |
| `--quality` | 75 | Boa legibilidade, arquivo menor |
| `--resampling` | bilinear | Qualidade adequada para mapas |

> Para ARC/REA (cartas com texto fino): avaliar PNG em vez de JPEG.

### Possíveis falhas no CI

| Risco | Mitigação |
|---|---|
| **Timeout** — 174MB WAC pode demorar 10-30 min por tile; múltiplos tiles ultrapassam 6h do runner gratuito | Converter só tiles **alterados**: comparar SHA256 ou Last-Modified com `wms_state.json` antes de converter |
| `gdal2mbtiles` não disponível (apt) | Alternativa: `pip install gdal2mbtiles` ou usar imagem Docker com GDAL pré-instalado |
| Manifest desatualizado após conversão | Implementar `dart run charts_loader_cli remanifest` ou script que relê os `.mbtiles` e regera |

---

## Parte 2 — App navbr

### 2a. Adicionar pacote

```yaml
# pubspec.yaml
dependencies:
  flutter_map_mbtiles: ^1.0.4   # requer flutter_map >=6 <9
```

Verificar versão atual de `flutter_map` no `pubspec.yaml` antes de adicionar.

### 2b. `charts_download_provider.dart` — reconhecer `.mbtiles`

**Arquivo:** `lib/providers/charts_download_provider.dart`  
**Trecho atual** (linha ~117):

```dart
if (ext == 'tif' || ext == 'tiff') {
  bbox = file.bbox;
} else if (ext == 'pdf') { ... }
```

**Mudança:**

```dart
if (ext == 'tif' || ext == 'tiff' || ext == 'mbtiles') {
  bbox = file.bbox;   // bbox vem do manifest (gerado antes da conversão)
} else if (ext == 'pdf') { ... }
```

O bbox dos GeoTIFFs está no manifest antes da conversão para MBTiles, então é preservado automaticamente.

### 2c. `chart_settings_provider.dart` — não chamar `_ensureRenderedPath` para `.mbtiles`

**Arquivo:** `lib/providers/chart_settings_provider.dart`  
**Trecho em `_loadBaseCharts`:**

```dart
for (final c in chartsFromDb) {
  String finalPath = await _ensureRenderedPath(c.path);  // ← só faz sentido para PDF
  ...
}
```

**Mudança:**

```dart
for (final c in chartsFromDb) {
  final ext = c.path.split('.').last.toLowerCase();
  final String finalPath = ext == 'pdf'
      ? await _ensureRenderedPath(c.path)
      : c.path;   // .mbtiles e .tif usam o caminho direto
  ...
}
```

Também atualizar o **lazy scan** (varre disco para indexar arquivos não no DB) para reconhecer `.mbtiles`:

```dart
// Onde hoje filtra .pdf e .tif/.tiff, adicionar .mbtiles
final ext = file.path.split('.').last.toLowerCase();
if (ext == 'mbtiles') {
  // bbox vem do MBTiles metadata table: SELECT value FROM metadata WHERE name='bounds'
  // formato: "west,south,east,north"
  // Pode usar o pacote mbtiles (dependência de flutter_map_mbtiles) para ler
}
```

### 2d. `navigation_map_screen.dart` — substituir OverlayImageLayer por MbTilesLayer

**Arquivo:** `lib/screens/navigation_map_screen.dart`

**Hoje (remove):**

```dart
if (settings.baseCharts.isNotEmpty)
  OverlayImageLayer(
    overlayImages: settings.baseCharts.map((chart) {
      return OverlayImage(
        imageProvider: FileImage(File(chart.path)),
        ...
      );
    }).toList(),
  ),
```

**Novo:**

```dart
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';

// dentro de FlutterMap children:
for (final chart in settings.baseCharts)
  MbTilesLayer(
    mbtiles: MbTiles(mbtilesPath: chart.path, gzip: false),
  ),
```

> O `bbox` continua sendo usado apenas para o `CameraFit` inicial — não muda.

### 2e. ARC charts (`arcCharts` em `ChartSettings`)

ARC vem de WMS → também é `.tif` → também converte para `.mbtiles`.  
A renderização atual (adicionada neste sprint) usa `OverlayImageLayer` com `FileImage` — precisa virar `MbTilesLayer` da mesma forma que o base chart.

**Atenção:** Existem dois tipos de ARC no pacote:
- **WMS ARC** (`.tif` → `.mbtiles`) — cartas regionais grandes, mesma lógica do ENRC
- **AD ARC** (`.pdf`) — cartas por aeródromo pequenas, continua como overlay PNG

O DB indexa ambos como `type = 'arc'`. Na hora de renderizar, diferenciar pela extensão do `path`.

### 2f. Migração do DB Hive (stale entries)

Se o device já tiver o DB com entradas apontando para `.tif` (de download anterior), os arquivos não existirão mais (foram substituídos por `.mbtiles` no R2).

**Solução:** Ao iniciar, verificar se o ciclo AIRAC mudou (comparar `emenda` salvo em `SharedPreferences` com o `emenda` do manifest). Se mudou → `DatabaseService.clearAllCharts()` antes de baixar o novo ciclo.

---

## PDFs — sem mudança

`ifr/iac/`, `ifr/sid/`, `ifr/star/`, `ifr/adc/`, `ifr/gmc/`, `ifr/pdc/`, `ifr/vac/`, `ifr/lc/` — continuam como `.pdf`, renderizados para PNG via `pdfx` (1× de resolução). Memória é limitada (uma carta por vez). Nada muda.

---

## Checklist de implementação

### CLI/CI
- [ ] Instalar GDAL no runner (`gdal-bin` ou `pip install gdal2mbtiles`)
- [ ] Adicionar etapa de conversão `.tif → .mbtiles` no `update.yml`
- [ ] Implementar conversão incremental (só tiles alterados)
- [ ] Regravar manifest com paths `.mbtiles` e novos `size`/`sha256`
- [ ] Testar localmente um WAC tile: `gdal2mbtiles --zoom=5-12 WAC_xxx.tif WAC_xxx.mbtiles`
- [ ] Verificar tamanho do arquivo resultante (estimativa: 30-80MB por WAC tile com JPEG 75)

### App navbr
- [ ] Verificar versão do `flutter_map` no `pubspec.yaml` (precisa `>=6 <9`)
- [ ] Adicionar `flutter_map_mbtiles: ^1.0.4` ao `pubspec.yaml`
- [ ] `charts_download_provider.dart`: reconhecer `.mbtiles` na extração de bbox
- [ ] `chart_settings_provider.dart`: pular `_ensureRenderedPath` para `.mbtiles`
- [ ] `chart_settings_provider.dart`: lazy scan reconhece `.mbtiles` (ler bbox da metadata table)
- [ ] `navigation_map_screen.dart`: `OverlayImageLayer` base charts → `MbTilesLayer`
- [ ] `navigation_map_screen.dart`: `OverlayImageLayer` arc charts → `MbTilesLayer` (para WMS ARC)
- [ ] Limpeza do DB ao trocar ciclo AIRAC
- [ ] Testar no device físico: zoom in/out, múltiplos tiles ENRC, memória estável

---

## Referências

- [flutter_map_mbtiles — pub.dev](https://pub.dev/packages/flutter_map_mbtiles)
- [flutter_map_pmtiles — pub.dev](https://pub.dev/packages/flutter_map_pmtiles) *(alternativa futura)*
- [gdal2mbtiles — PyPI](https://pypi.org/project/gdal2mbtiles/)
- [ForeFlight FBTiles Specification](https://blog.foreflight.com/2013/07/08/flight-bag-tiles-fbtiles-specification/)
- [aviationCharts (FAA → MBTiles pipeline, referência)](https://github.com/jlmcgraw/aviationCharts)
- [flutter_map Offline Mapping docs](https://docs.fleaflet.dev/tile-servers/offline-mapping)
