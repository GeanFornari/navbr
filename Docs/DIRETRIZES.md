# Diretrizes de Desenvolvimento (PoC Geo Cartas)

## 1. Versões e Dependências
- **Sempre utilize as versões mais recentes** (latest) de todos os pacotes do Flutter/Dart.
- Em caso de conflitos de dependência (ex: pacote A exige pacote C v1, mas pacote B exige pacote C v2), devemos priorizar a atualização do pacote mais antigo ou, se necessário, utilizar `dependency_overrides` no `pubspec.yaml` ao invés de fazer downgrade em cascata, mantendo assim o projeto apontando para o futuro.

## 2. Arquitetura do PoC
- O escopo atual é 100% focado no frontend/renderização.
- Não usar arquiteturas complexas (como Hive, Riverpod, etc.) até que a prova de conceito matemática (Lat/Lon -> XY) esteja validada.
- O backend/CLI que servirá os arquivos de forma otimizada será implementado em outro projeto/momento. O aplicativo apenas testa o download pontual para ter os arquivos localmente.

## 3. Regras de Código
- Manter as classes pequenas e bem separadas:
  - `AiswebApiService`: Lida com comunicação de APIs.
  - `DownloadService`: Lida com a gravação de arquivos e requisições HTTP estáticas de mídias.
  - *Parsers* geográficos devem ser isolados em serviços próprios.
