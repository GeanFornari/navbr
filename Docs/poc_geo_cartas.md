# [HISTÓRICO] Prova de Conceito: Navegação GPS em Cartas Georreferenciadas

> **Este documento é histórico.** A PoC foi concluída com sucesso e o conhecimento foi integrado ao **navbr**, que está em desenvolvimento para produção. As decisões técnicas validadas aqui estão documentadas em `Docs/DICAS_IMPLEMENTACAO.md`. O plano arquitetural atual está em `Docs/DIRETRIZES.md`.

---

Este documento registra o planejamento e as hipóteses iniciais da PoC que originou o navbr.

## O que o DECEA (GeoAISWEB) fornece
- **GeoPDFs**: Cartas de procedimento (IAC, SID, STAR) baixadas diretamente do AISWEB já vêm com metadados geoespaciais (Padrão OGC / Adobe PDF embutido).
- **GeoTIFFs**: Cartas de rota (ERC, WAC, REA) são imagens rasterizadas em formato GeoTIFF de alta resolução, contendo as bordas geográficas no cabeçalho do arquivo.

## Viabilidade Técnica no Flutter
A exibição de cartas com a "bolinha do GPS" se movendo em cima exige traduzir coordenadas globais (Lat/Lon) para coordenadas locais (Pixels X/Y da imagem/PDF). Temos os seguintes caminhos técnicos:

### 1. PDF Viewer com Projeção Matemática (Para IAC/SID/STAR)
Lemos os metadados brutos do arquivo PDF usando um parser (procurando pelos dicionários `/Measure` ou `<ptx> / <pty> / <lat> / <lon>`), extraímos os 4 cantos da carta em Latitude/Longitude e adicionamos um *overlay* transparente por cima de um leitor de PDF comum. O GPS alimenta esse *overlay* fazendo uma interpolação linear simples.

### 2. Raster Image Overlay no Flutter Map (Para WAC/ERC)
Para WACs e ERCs, utilizamos `flutter_map` com `OverlayImage`. Extraímos o *Bounding Box* do GeoTIFF e "colamos" a imagem no mapa base, deixando o plugin `flutter_map_location_marker` cuidar nativamente da posição do GPS.

---

## O Fluxo Ideal (O Caminho do Expert)

Para evitar poluição de dependências no projeto principal e focar 100% na complexidade matemática e de rendering, o desenvolvimento seguiu a abordagem de um projeto Sandbox isolado.

### 1. App "Sandbox" (`aisbr_geo_poc`)
Criar um projeto Flutter em branco fora da árvore principal do aplicativo:
```bash
flutter create aisbr_geo_poc
```

### 2. Carga de Dados Estáticos
Configurar a pasta `assets` no PoC com arquivos de teste:
- 1 PDF de IAC (baixado do AISWEB).
- 1 GeoTIFF de WAC (baixado do GeoAISWEB).
*Nota: Não nos preocuparemos com arquiteturas complexas como Hive, Riverpod ou downloads em background nesta etapa. O foco é estritamente fazer a renderização funcionar.*

### 3. Mão na Massa
Foco absoluto em tentar extrair os metadados do PDF/TIFF e plotar o "aviãozinho" (Widget do GPS) andando em cima da imagem através das conversões matemáticas de Lat/Lon para X/Y.

### 4. Validação
Se o resultado for performático, elegante e não depender de bibliotecas nativas inviáveis ou pesadas demais, empacotamos o conhecimento e abstraímos o código em uma **classe/serviço limpo**.

### 5. Transplante
Trazemos apenas a classe validada, pronta, e os pacotes definitivos estritamente necessários para dentro do projeto principal `aisbr`.
