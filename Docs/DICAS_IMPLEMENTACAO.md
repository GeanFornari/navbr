# Lições Aprendidas — navbr

Decisões técnicas validadas durante o desenvolvimento, documentadas para referência futura.

## 1. Bbox no servidor, não no app

Durante os primeiros testes, o app carregava GeoTIFFs inteiros (~170MB) na RAM só para ler as tags EXIF binárias e descobrir as coordenadas dos quatro cantos. Isso causava OOM.

**Decisão adotada:** O `charts_loader_cli` extrai o bbox de cada arquivo (GeoTIFF via metadata WMS; PDF via regex `/GPTS`) e o publica no `manifest.json`. O app consome o manifest e nunca faz parsing de headers binários.

## 2. GeoTIFFs grandes causam OOM — próximo passo: MBTiles

Mesmo com o bbox vindo pronto, carregar um `.tif` de 174MB como `FileImage` aloca ~500MB+ RGBA na RAM. Em devices físicos com memória limitada, o app fecha.

**Decisão planejada:** Converter GeoTIFFs para MBTiles no CI antes do upload para o R2. O app usará `flutter_map_mbtiles` para renderizar só os tiles visíveis (~5MB em uso). Plano completo em `Docs/mbtiles-migration.md`.

## 3. Alinhamento preciso do GeoPDF (IAC/SID)

O PDF de procedimento é uma folha A4 com o mapa num quadrado central, cercado de margens, perfil de descida e tabelas. O overlay atual alinha pelo bbox da folha inteira.

**Para corrigir:** Extrair o `LPTS` (Local Points, valores 0.0–1.0) e usá-los como offset/crop da imagem gerada pelo `pdfx`, para que somente a seção geográfica seja projetada no `OverlayImage`. Ainda não implementado.

## 4. Rotação North Up / Track Up

- `MarkerLayer(rotate: false)` — o container do avião é imune à rotação do mapa.
- **Track Up:** `_mapController.rotate(360 − bearing)` + ícone a 0°.
- **North Up:** mapa travado em 0° + ícone rotaciona com o `bearing`.

## 5. NaN no bearing (coordenadas duplicadas)

GPS real emite pacotes com coordenadas idênticas. Calcular bearing entre dois pontos iguais resulta em `NaN` (divisão por zero na distância). Sempre verificar `bearing.isNaN` antes de repassar ao mapa.

## 6. Dois domínios DECEA

- API XML (PDFs): links podem apontar para `aisweb.decea.gov.br` (domínio antigo). Substituir por `.mil.br` em tempo de execução — o `DownloadService` já faz isso automaticamente.
- Mídias estáticas (GeoTIFFs): `geoaisweb.decea.mil.br` via WMS.
