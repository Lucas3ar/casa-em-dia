# Casa em Dia

Projeto Flutter para organizar e dividir as tarefas domésticas de uma casa. A interface está em português do Brasil e o app roda no Android e na web.

[Esboços no Google Stitch](https://stitch.google.com/projects/10097943956771684340) · [Arquitetura oficial do Flutter](https://docs.flutter.dev/app-architecture/)

## Executar

O projeto foi verificado com Flutter 3.47.1 e Dart 3.13.1. No Android, configure o SDK com o Android Studio e confira o ambiente com `flutter doctor`. Abra a pasta que contém este README no terminal.

### Demonstração em um aparelho

```sh
flutter pub get
flutter run
```

Escolha **Explorar demonstração**. A casa de exemplo começa com três moradores, tarefas e recompensas. A aba **Casa** permite trocar de morador no modo demonstração. Para abrir no navegador, use `flutter run -d chrome --web-port=8300`.

### Casa compartilhada em dois aparelhos

No primeiro terminal, execute o servidor incluído no projeto.

```sh
dart run bin/server.dart 8080
```

Em outro terminal, execute o app para o dispositivo escolhido.

```sh
# Emulador Android
flutter run --dart-define=CASA_API=http://10.0.2.2:8080

# Chrome no computador do servidor
flutter run -d chrome --web-port=8300 --dart-define=CASA_API=http://127.0.0.1:8080

# Celular Android na mesma rede Wi-Fi do computador
flutter run --dart-define=CASA_API=http://192.168.1.10:8080
```

Para gerar um APK para a sua rede, use `flutter build apk --debug --dart-define=CASA_API=http://192.168.1.10:8080`.

No último comando, substitua `192.168.1.10` pelo IPv4 do computador que está executando o servidor. Os aparelhos precisam alcançar a porta TCP 8080. Só permita acesso à porta em uma rede confiável. Se for abrir duas sessões web no mesmo computador, use duas portas web diferentes ou uma janela anônima para isolar o armazenamento de sessão.

1. Crie a casa no primeiro aparelho e copie o convite na aba **Casa**.
2. No segundo aparelho, escolha **Entrar com código**, informe outro nome e cole o convite.
3. Cadastre uma tarefa no primeiro aparelho. A tarefa deve aparecer no segundo.
4. Para verificar o rodízio, crie uma tarefa semanal com rodízio ativo e conclua pelo perfil responsável. A próxima ocorrência deve aparecer com novo prazo e outro responsável.

O servidor escuta na porta indicada e salva em `casas.jsonl`. Para escolher outro caminho, defina `CASA_DB` antes de subir o servidor. Mantenha um único processo por arquivo. Na configuração local, HTTP e WebSocket trafegam sem criptografia. Para acesso pela internet, hospede atrás de um proxy HTTPS/WSS e trate o arquivo do servidor como privado. Ele contém nomes, sessões e comprovações. Cada instalação guarda a sessão localmente. Ao encerrar a sessão, o perfil antigo continua no grupo e o convite cria um novo perfil.

## Funcionalidades

| Requisito | Onde conferir |
| --- | --- |
| Grupo e convite | Criação e entrada na tela inicial. Convite e lista de moradores em **Casa**. Mudanças são anunciadas por WebSocket e o repositório atualiza a casa pela API. |
| Catálogo | **Casa** agrupa as tarefas por cômodo. **Nova tarefa** inclui prazo com hora, morador, frequência e esforço de 1 a 10. |
| Rodízio | Ao concluir uma tarefa recorrente com rodízio, a próxima ocorrência passa ao próximo morador na ordem de entrada. Se houver prazos já vencidos, o app agenda a primeira ocorrência futura. |
| Placar e recompensas | **Pontos** mostra ranking por semana ou mês, criação e resgate de recompensas e saldo acumulado. |
| Comprovação | Exija duas imagens JPEG ou PNG, de até 1,4 MB cada. O responsável pode anexar pela câmera ou galeria. O próprio responsável vê as fotos em **Meu histórico**. |
| Lembretes | O sino mostra as tarefas do morador que vencem hoje e as atrasadas. No Android, use **Ativar notificações no Android** para permitir alertas locais. O app programa um alerta antes do prazo, quando há tempo, e outro após o vencimento. O sistema pode atrasar a entrega. A lista de alarmes muda quando o aparelho sincroniza as tarefas. A web usa apenas lembretes internos. |
| Equilíbrio | **Equilíbrio** mostra percentuais e barras de esforço e de tarefas concluídas por morador. Os percentuais usam o total da semana atual, iniciada na segunda-feira, ou do mês atual. |

## Arquitetura MVVM

Referência da disciplina — Taniro Chacon Rodrigues, *Arquitetura Sugerida para Aplicações Flutter*, Aula 24.

```text
Views (widgets) ──ações──> ViewModels (ChangeNotifier)
ViewModels ──comandos──> HomeRepository ──requisições──> HomeService
HomeService <────────────────────────────────────────> API REST / WebSocket
HomeRepository ──estado──> ViewModels ──estado──> Views
```

- `lib/ui/` contém as Views e os ViewModels separados para sessão, Hoje, Casa, Pontos e Equilíbrio. As Views capturam ações e renderizam o estado. Os ViewModels filtram tarefas, calculam os totais dos períodos e expõem comandos.
- `lib/data/repositories/` guarda a última versão da casa e serializa operações. O mesmo repositório atende aos ViewModels, que recebem mudanças pelo `ChangeNotifier`. A API é a fonte de verdade entre aparelhos.
- `lib/data/services/` isola HTTP, WebSocket, armazenamento de sessão, fotos e integração com Android. O ponto de entrada injeta as dependências.
- `lib/domain/home.dart` contém os modelos e as regras de tarefas, recorrência, rodízio, comprovação e resgate. O servidor e a demonstração executam as mesmas regras.
- `bin/server.dart` valida a sessão, aplica as regras e persiste a atualização antes de avisar os outros aparelhos.

## Do Stitch para o Flutter

O projeto **Casa em Dia App** no Stitch contém a proposta Serene Hearth, as quatro abas, a tela de entrada, o formulário e um estado de sucesso. O Flutter adota o verde floresta, o marfim, os cartões arredondados, os indicadores e a navegação dessas telas. A versão funcional calcula os números pelas tarefas registradas, usa um código copiável para convites e separa a distribuição de pontos da distribuição de tarefas. O relatório usa duas opções de período, conforme o tema do trabalho.

## Verificar o projeto

```sh
flutter analyze
flutter test
flutter build apk --debug
```

Os testes cobrem o fluxo de demonstração, a criação de tarefa pelas telas, a validação de fotos, o rodízio e o saldo após resgate.

