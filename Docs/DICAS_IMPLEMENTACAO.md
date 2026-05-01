# Dicas de Implementação para o App Principal (AISBR)

Com a finalização bem-sucedida da Prova de Conceito (PoC) de renderização de Moving Map (GPS sobre cartas do DECEA), compilamos abaixo as principais lições aprendidas e recomendações arquiteturais para quando este código for migrado para o projeto pai.

## 1. Desoneração do Lado do Cliente (Mobile)
Durante a PoC, o aplicativo Flutter precisou carregar arquivos GeoTIFF imensos (como a WAC de São Paulo com ~170MB) na memória RAM (via `ByteData`) apenas para ler as Tags EXIF binárias e descobrir as coordenadas dos quatro cantos. 
**Recomendação:** Seu servidor/CLI deve assumir essa responsabilidade. O fluxo ideal é:
1. A CLI baixa a WAC do GeoAISWEB.
2. A CLI lê as Tags geográficas (33922, 33550, 34264) no servidor.
3. A CLI gera um arquivo JSON leve (ex: `wac_sao_paulo_meta.json`) contendo apenas as latitudes e longitudes (Bounding Box).
4. O App Mobile baixa o `.tif` e o `.json`. Assim, o Flutter não gasta bateria e memória fazendo *parsing* binário; ele apenas joga o TIFF na tela usando as coordenadas já prontas do JSON.

## 2. Tratamento de Arquivos Pesados (Tiling)
Arquivos de 200MB num dispositivo móvel antigo causarão fechamentos (Out of Memory - OOM).
**Recomendação futura:** O `flutter_map` roda de maneira absurdamente mais rápida se você converter grandes GeoTIFFs em recortes menores (Tiles / formato MBTiles / XYZ). A sua CLI no servidor pode rodar ferramentas gratuitas como o `gdal2tiles` nas cartas WAC antes de mandá-las pro celular. Isso viabiliza abrir o mapa inteiro do Brasil num celular antigo.

## 3. Alinhamento Preciso do GeoPDF (Cartas de Procedimento - IAC/SID)
Na PoC, conseguimos ler a matriz `/GPTS` e `/LPTS` do padrão OGC embutido no PDF. No entanto, o PDF de procedimento é uma página A4 que contém o mapa apenas em um "quadrado" desenhado no meio da página (envolto por margens brancas, perfil de descida e tabelas de mínimos).
**Recomendação:** Para o avião "bater" exatamente em cima das linhas do PDF:
1. Extraia o `LPTS` (Local Points) - Eles informam a porcentagem (de 0.0 a 1.0) da folha A4 onde o mapa começa e termina.
2. Use esses percentuais para aplicar um "Offset" (deslocamento) ou fazer um "Crop" (recorte) na imagem gerada pelo `pdfx`, garantindo que apenas a seção geográfica seja usada na projeção (Bounding Box) do `flutter_map`.

## 4. O Sistema de Rotação (North Up / Track Up)
A matemática de rotação é complexa devido à interferência entre o motor gráfico e os widgets de interface.
Para que o ícone do avião funcione livre de erros em ambos os modos:
- Configure a camada que segura o avião (`MarkerLayer`) com o parâmetro `rotate: false`. Isso fará o contêiner do avião ser imune à rotação da terra embaixo dele.
- Quando o mapa estiver no modo **Track Up**, a terra (`_mapController`) gira no valor exato de `-bearing` (proa invertida) e o ícone do avião fica no ângulo `0` (Sempre apontando para o topo fixo da tela de vidro do celular).
- Quando no modo **North Up**, a terra fica travada em `0` e o ícone do avião ganha a rotação igual ao `bearing` (apontando na diagonal).

## 5. Lidando com Coordenadas Repetidas
Sistemas reais de GPS flutuam e muitas vezes transmitem dois pacotes (ticks) idênticos seguidos. Se a coordenada atual for idêntica à do milissegundo passado, calcular a "Proa" (Bearing) resultará em **`NaN`** (Not a Number) devido a divisões por zero na matriz da distância, fazendo o mapa fechar.
Sempre inclua *guards* (travas) como `if (bearing.isNaN)` antes de passar graus para a interface visual.

## 6. Múltiplos Formatos e Domínios
O DECEA usa dois domínios diferentes. Fique atento no parser de links da sua CLI:
- APIs XML antigas (como as que trazem PDFs): Costumam apontar links com o `.gov.br` (ex: aisweb.decea.gov.br). Algumas rotas foram desativadas neste domínio, devendo sempre ser substituído em tempo de execução para `.mil.br`.
- Mídias estáticas pesadas (TIFFs): Ficam em servidor Nginx "cru" e previsível no GeoAISWEB (ex: `geoaisweb.decea.mil.br/src/geotiffs/WAC_3262_SAO_PAULO.tif`).
