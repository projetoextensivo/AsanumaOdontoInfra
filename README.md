# Infra — Asanuma Odonto

Scripts locais para iniciar, parar, reiniciar e acompanhar a aplicação Asanuma Odonto como ela funciona atualmente: API Spring Boot no backend e interface Vite no frontend.

> Estes scripts são voltados a desenvolvimento e demonstração em uma máquina Linux com Bash. O Vite fica acessível na rede local quando iniciado por eles. Não são uma configuração de produção ou um serviço de inicialização automática do sistema.

## Pré-requisitos

- Linux com Bash e `setsid`
- Java 21 e Maven
- Node.js 22.13 ou superior e npm
- `curl`
- Dependências do frontend instaladas (`npm ci` em `frontend/`)

## Localizar o projeto principal

Quando `infra/` estiver dentro do repositório principal, os scripts detectam automaticamente a raiz. Como este diretório poderá ser usado em um repositório separado, informe `APP_ROOT` para localizar o código da aplicação:

```bash
export APP_ROOT="/caminho/para/AsanumaOdonto"
```

A raiz informada deve conter `backend/pom.xml` e `frontend/package.json`. `APP_ROOT` será salvo no diretório de execução para que os comandos de parada e monitoramento encontrem a mesma instância.

Se o banco estiver vazio e o modo de demonstração estiver desligado, configure `ADMIN_EMAIL` e `ADMIN_PASSWORD` antes de iniciar a aplicação. Consulte os READMEs do backend e do projeto principal para os detalhes de configuração.

## Scripts

Execute os comandos a partir deste diretório (`infra/`) ou use os caminhos completos.

| Script | Ação |
| --- | --- |
| `scripts/start.sh` | Inicia Spring Boot e Vite em segundo plano e aguarda a API e a interface responderem. |
| `scripts/stop.sh` | Encerra os dois processos de forma graciosa; força a parada após 15 segundos se necessário. |
| `scripts/restart.sh` | Para e inicia novamente a aplicação. |
| `scripts/monitor.sh` | Acompanha processos e respostas HTTP a cada cinco segundos. `Ctrl+C` encerra somente o monitoramento. |

Exemplo:

```bash
./scripts/start.sh
./scripts/monitor.sh
./scripts/stop.sh
```

Para atualizar o código ou as configurações e reiniciar:

```bash
./scripts/restart.sh
```

## Acesso à aplicação

O backend usa a porta `8080` e o frontend usa a porta `5173` por padrão. O Vite encaminha `/api` ao backend em `127.0.0.1:8080`, mantendo as chamadas do navegador na mesma origem.

- Na própria máquina: `http://localhost:5173`
- Em outro dispositivo da mesma rede: `http://IP-DA-MAQUINA-QUE-EXECUTA-A-APLICACAO:5173`

Use o IPv4 privado da máquina anfitriã. Se outros dispositivos não conseguirem conectar, permita entrada TCP na porta `5173` pelo firewall, restrita à rede privada/local, e verifique se a rede Wi-Fi não isola os clientes. Não é necessário expor a porta `8080` para esse acesso via Vite.

## Configuração opcional

| Variável | Padrão | Uso |
| --- | --- | --- |
| `APP_ROOT` | Dois níveis acima de `infra/scripts/` | Caminho para o checkout do projeto principal. |
| `APP_RUNTIME_DIR` | `$XDG_RUNTIME_DIR/asanumaodonto-infra-$UID` ou `/tmp/asanumaodonto-infra-$UID` | Diretório de PIDs, logs e parâmetros da execução. Defina-o igual ao usar todos os scripts. |
| `PORT` | `8080` | Porta da API Spring Boot. |
| `VITE_PORT` | `5173` | Porta do frontend Vite. |
| `API_PROXY_TARGET` | `http://127.0.0.1:$PORT` | Destino das chamadas `/api` encaminhadas pelo Vite. |
| `STARTUP_TIMEOUT` | `90` segundos | Tempo máximo para a API e o frontend ficarem prontos. |
| `INTERVAL` | `5` segundos | Intervalo entre verificações de `monitor.sh`. |

Exemplo com portas alternativas:

```bash
PORT=8081 VITE_PORT=5174 ./scripts/start.sh
```

O monitor e os scripts seguintes recuperam as portas salvas durante a inicialização. Se definir `APP_RUNTIME_DIR` ou `APP_ROOT`, mantenha o mesmo valor ao executar os comandos subsequentes.

## Logs e encerramento

Os logs são gravados em `backend.log` e `frontend.log` dentro de `APP_RUNTIME_DIR`. Os arquivos de PID e os parâmetros da instância também ficam nesse diretório temporário, fora do repositório.

Para acompanhar os logs em outra janela:

```bash
tail -f "${APP_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asanumaodonto-infra-${UID}}/backend.log"
tail -f "${APP_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/asanumaodonto-infra-${UID}}/frontend.log"
```

Interromper `monitor.sh` não para a aplicação. Use `stop.sh` para encerrar o backend e o frontend.
