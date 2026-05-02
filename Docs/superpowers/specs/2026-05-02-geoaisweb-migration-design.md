# Design: Migração para GeoTIFFs do geoaisweb + Bbox no Manifest

**Data:** 2026-05-02  
**Repos afetados:** `charts_loader_cli` e `navbr`

---

## Contexto

As cartas ENRC, ARC, WAC, REA e REH baixadas via AISWEB API chegam como PDF com bordas de informação da carta impressa, o que inviabiliza o georreferenciamento preciso no overlay. O servidor `geoaisweb.decea.mil.br` disponibiliza essas mesmas cartas como GeoTIFF limpo (sem bordas), com bounding boxes precisos acessíveis via WMS GetCapabilities.

Cartas de aeródromo (IAC, SID, STAR, ADC, PDC, VAC, GMC, LC, CV) continuam sendo baixadas da AISWEB API como PDF — não estão disponíveis no geoaisweb.

---

## Fontes de Dados

| Tipo de carta | Fonte atual | Fonte nova |
|---|---|---|
| ENRC H1–H9, L1–L9 | AISWEB API (PDF com bordas) | `geoaisweb.decea.mil.br/src/geotiffs/ENRC_H1.tif` |
| ARC (18 cartas) | AISWEB API (PDF com bordas) | `geoaisweb.decea.mil.br/src/geotiffs/ARC_<NOME>.tif` |
| WAC (46 cartas) | AISWEB API (PDF com bordas) | `geoaisweb.decea.mil.br/src/geotiffs/WAC_<NUM>_<CIDADE>.tif` |
| CCV_REA (23), REA (3) | AISWEB API (PDF com bordas) | `geoaisweb.decea.mil.br/src/geotiffs/CCV_REA_<ID>.tif` |
| CCV_REH (9), REH (3) | AISWEB API (PDF com bordas) | `geoaisweb.decea.mil.br/src/geotiffs/CCV_REH_<ID>.tif` |
| IAC, SID, STAR, ADC, PDC, VAC, GMC, LC, CV | AISWEB API (PDF) | AISWEB API (PDF) — sem mudança |
| REUL | AISWEB API | **Removido do projeto** |

**Nomes dos layers no geoaisweb** são os mesmos nomes dos arquivos GeoTIFF, idênticos às layers WMS (ex: `ARC_CURITIBA_E_FLORIANOPOLIS`, `CCV_REA_XP2_SAO_PAULO`). Descobertos dinamicamente via WMS GetCapabilities.

---

## Arquitetura do Fluxo (CLI)

```
charts_loader_cli package <airac>
        │
        ├─ 1. DISCOVER
        │      ├─ WMS GetCapabilities → lista dinâmica de layers + bbox (EPSG:4326)
        │      │     Endpoint: geoaisweb.decea.mil.br/geoserver/ICA/wms?service=WMS&version=1.1.0&request=GetCapabilities
        │      │     Filtro: layers com prefixo ENRC_, ARC_, WAC_, CCV_REA_, CCV_REH_, REA_, REH_
        │      └─ AISWEB API checklist(<airac>) → IDs inseridos/destruídos (cartas de AD)
        │            Endpoint: aisweb.decea.mil.br/api/?area=checklist&airac=<data>
        │
        ├─ 2. SYNC
        │      ├─ Geoaisweb charts → baixar GeoTIFF de todos os layers descobertos
        │      │     bbox vem do WMS GetCapabilities (já disponível no passo 1)
        │      │     Re-baixa tudo a cada ciclo AIRAC (conjunto pequeno, ~120 arquivos)
        │      └─ API charts → aplicar checklist:
        │            inserir → baixar PDF + extrair bbox via /GPTS do PDF
        │            destruir → remover do cache local
        │            ausente → manter cache
        │
        ├─ 3. VALIDATE
        │      ├─ Confirmar que todos os layers WMS têm GeoTIFF local
        │      ├─ Confirmar que todos os IDs em `inserir` foram baixados
        │      └─ Reportar qualquer falha — abortar se completude < 100%
        │
        └─ 4. PACKAGE + UPLOAD
               ├─ Gerar manifest.json (ver formato abaixo)
               └─ Sync para Cloudflare R2
```

---

## Formato do manifest.json (novo)

```json
{
  "generatedAt": "2026-05-02T10:30:45.123Z",
  "generator": { "name": "charts_loader_cli", "version": "0.2.0" },
  "emenda": "2026-05-29",
  "stats": { "totalCharts": 2578, "downloaded": 2578, "failed": 0 },
  "files": [
    {
      "path": "ifr/enrc/ENRC_H1.tif",
      "size": 99640716,
      "sha256": "abc123...",
      "bbox": { "north": -23.745, "south": -34.350, "east": -41.026, "west": -59.155 }
    },
    {
      "path": "ifr/iac/sbgr_iac_20260416.pdf",
      "size": 524288,
      "sha256": "def456...",
      "bbox": { "north": -23.39, "south": -23.47, "east": -46.44, "west": -46.55 }
    }
  ]
}
```

`bbox` é obrigatório para cartas de rota/área (GeoTIFF). Para cartas de AD (PDF), é incluído se a extração `/GPTS` for bem-sucedida; `null` caso contrário.

---

## Mudanças na CLI (`charts_loader_cli`)

### Novos arquivos

| Arquivo | Responsabilidade |
|---|---|
| `lib/src/discovery/wms_discovery.dart` | Consulta WMS GetCapabilities, parseia XML, retorna `List<WmsChart>` com `name` e `bbox` |
| `lib/src/geo/geopdf_extractor.dart` | Lê PDF binário, extrai `/GPTS` via regex, retorna bbox em graus decimais |
| `lib/src/services/geoaisweb_download_service.dart` | Baixa GeoTIFFs de `geoaisweb.decea.mil.br/src/geotiffs/<NAME>.tif` |

### Arquivos modificados

| Arquivo | Mudança |
|---|---|
| `lib/src/models/chart.dart` | Adiciona `ChartTipo.ccvRea`, `ChartTipo.ccvReh`; remove `ChartTipo.reul`; adiciona campo `bbox` em `Chart` |
| `lib/src/discovery/chart_discovery.dart` | Incorpora `WmsDiscovery`; usa checklist para diff das cartas de AD |
| `lib/src/packaging/package_manifest.dart` | Inclui campo `bbox` no JSON gerado |
| `bin/charts_loader_cli.dart` | Orquestra o novo fluxo: discover → sync → validate → package |

### Modelo `WmsChart`
```dart
class WmsChart {
  final String layerName;   // ex: "ENRC_H1", "ARC_CURITIBA_E_FLORIANOPOLIS"
  final double north, south, east, west;
}
```

---

## Mudanças no App Flutter (`navbr`)

### `lib/models/r2_manifest.dart`
Adicionar campo `bbox` opcional em `R2ManifestFile`:
```dart
class R2ManifestFile {
  final String path;
  final int size;
  final String sha256;
  final BoundingBox? bbox;  // null para PDFs sem geo
}

class BoundingBox {
  final double north, south, east, west;
}
```

### `lib/providers/charts_download_provider.dart`
- Após download de carta de rota (GeoTIFF): usar `bbox` do manifest diretamente
- Não chamar `GeoTiffParser` para cartas de rota
- Salvar `ChartIndex` com bbox do manifest

### Remoções/simplificações
- `GeoTiffParser` → pode ser removido após validação da migração completa
- `GeoPdfParser` → mantido como fallback para cartas de AD (IAC, SID, STAR, ADC, PDC, VAC, GMC, LC, CV) nos casos em que `bbox` vier `null` no manifest

### Tipos de carta
- Adicionar suporte para `ccvRea`, `ccvReh` na UI de download/seleção
- Remover `reul` de todas as listas e agrupamentos

---

## Notas Técnicas

- **ARC_ACADEMIA**: bbox retorna `-180/-90/180/90` no GetCapabilities (misconfiguration no GeoServer). Bbox correto: `W=-50.1397, S=-23.0993, E=-46.0515, N=-20.5230`. Hardcode como exceção na `WmsDiscovery`.
- **Nomes com hífen**: `CCV_REA_PI-PARINTINS` e `CCV_REA_XN-ANAPOLIS` têm hífen no nome — tanto o GeoTIFF quanto o WMS usam o mesmo nome, funciona normalmente.
- **REUL removido**: `CCV_REUL_WJ3_RIO_DE_JANEIRO` não será descoberto nem baixado.
- **Checklist e cartas de rota**: ENRC/ARC/WAC aparecem na API com IDs, mas como são baixados do geoaisweb (sem vínculo direto de ID↔nome), o checklist não é usado para eles — re-download por ciclo é suficiente.
