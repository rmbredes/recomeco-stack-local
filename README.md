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
└└── recomeco-stack-local
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

## Preparar credenciais AWS

Se a sessão estiver expirada:

```powershell
aws login --profile default
```

Carregue as credenciais temporárias no PowerShell:

```powershell
$awsCredentials = aws configure export-credentials `
    --profile projeto-s3 `
    --format process |
    ConvertFrom-Json

$env:AWS_ACCESS_KEY_ID = $awsCredentials.AccessKeyId
$env:AWS_SECRET_ACCESS_KEY = $awsCredentials.SecretAccessKey
$env:AWS_SESSION_TOKEN = $awsCredentials.SessionToken
```

As credenciais existem somente na janela atual do PowerShell e não são armazenadas no Git.

## Subir a stack

Na mesma janela em que as credenciais foram carregadas:

```powershell
cd C:\Recomeco\projetos\recomeco-stack-local
docker compose up -d --build
```

## Consultar os containers

```powershell
docker compose ps
```

## Parar a stack

```powershell
docker compose down
```

Não use `-v`, a menos que queira apagar permanentemente os bancos e os demais volumes.