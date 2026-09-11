# Recomeço — Stack local

Este projeto centraliza a execução do laboratório completo com Docker Compose.

Ele não contém código Java. Sua responsabilidade é importar e orquestrar os arquivos Compose das três aplicações.

## Estrutura esperada

Os quatro repositórios devem permanecer lado a lado:

```text
C:\Recomeco\projetos\
├── ProjetoSpringBoot
├── pagamento-service
├── logistica-service
└── recomeco-stack-local
```

## Aplicações

| Aplicação | Função | Porta |
|---|---|---:|
| ProjetoSpringBoot | Monólito principal | 8080 |
| pagamento-service | Processamento de pagamentos | 8081 |
| logistica-service | Autorização de entregas | 8084 |

## Infraestrutura

| Serviço | Porta |
|---|---:|
| PostgreSQL do monólito | 5432 |
| PostgreSQL de pagamentos | 5433 |
| PostgreSQL de logística | 5434 |
| Redis | 6379 |
| Kafka | 9092 |
| Kafka UI | 8083 |
| Keycloak | 8085 |
| Grafana | 3000 |
| Prometheus | 9090 |
| Loki | 3100 |
| Alloy | 12345 |
| Jaeger | 16686 |

## Comunicação principal

```text
ProjetoSpringBoot
        │
        ├── Kafka → pagamento-service
        │
        ├── Kafka ← pagamento-service
        │
        └── REST + OAuth2/JWT → logistica-service
```

## Integrações AWS

O fluxo de relatórios utiliza:

```text
ProjetoSpringBoot
        ↓
Amazon SQS
        ↓
PDF → Amazon S3
        ↓
Amazon SNS
        ├── e-mail simples
        ├── fila de auditoria
        └── Lambda → SES → e-mail com PDF
```

O Amazon RDS não precisa estar ligado. As aplicações usam PostgreSQL em containers.

## Credenciais AWS

O script `start-stack.ps1` usa a AWS CLI para exportar automaticamente as
credenciais temporárias do perfil `projeto-s3`. Se a sessão estiver ausente ou
expirada, o próprio script executa `aws login --profile default` e aguarda a
autenticação pelo navegador.

Os valores das credenciais não são exibidos, gravados no projeto ou armazenados
na imagem Docker.

Internamente, o script executa o equivalente a:

```powershell
aws configure export-credentials --profile projeto-s3 --format process
```

Quando as credenciais temporárias expirarem, renove o login e execute novamente
o script. O container do monólito será recriado com as novas credenciais.

## Subir a stack

Execute a partir da pasta do orquestrador:

```powershell
cd C:\Recomeco\projetos\recomeco-stack-local
.\start-stack.ps1
```

Por padrão, o script utiliza o perfil `projeto-s3`. Outro perfil pode ser informado:

```powershell
.\start-stack.ps1 -AwsProfile outro-perfil -LoginProfile outro-login
```

## Consultar os containers

```powershell
docker compose ps
```

## Parar a stack

```powershell
.\stop-stack.ps1
```

Não use `-v`, a menos que queira apagar permanentemente os bancos e os demais volumes.
