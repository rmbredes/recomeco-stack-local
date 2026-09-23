# Implantação educacional na Amazon EC2

Este diretório contém a configuração utilizada para executar parte da
plataforma Recomeco em uma instância Amazon EC2 usando Docker Compose.

## Arquitetura atual

```text
Internet
   ↓
Security Group — porta 8081 restrita ao IP do desenvolvedor
   ↓
Amazon EC2
   ↓
Docker Compose
   ├── pagamento-service:8081
   ├── pagamento-postgres:5432
   └── kafka:29092
```

O PostgreSQL e o Kafka não possuem portas publicadas para a internet.
Eles são acessados somente pela rede interna criada pelo Docker Compose.

## Origem das imagens

```text
GitHub Actions / Jenkins
            ↓
       Amazon ECR
            ↓
        Amazon EC2
            ↓
    Docker Compose
```

A imagem do `pagamento-service` vem do Amazon ECR:

```text
033649548808.dkr.ecr.sa-east-1.amazonaws.com/recomeco/pagamento-service:latest
```

As imagens do PostgreSQL e Kafka vêm dos respectivos registros públicos.

## Pré-requisitos da EC2

- Amazon Linux 2023;
- Docker Engine;
- Docker Compose;
- IAM Role `RecomecoEc2DevRole`;
- política `AmazonSSMManagedInstanceCore`;
- política `AmazonEC2ContainerRegistryReadOnly`;
- Security Group com SSH opcionalmente liberado somente para o IP do desenvolvedor;
- porta `8081` liberada somente para o IP do desenvolvedor durante os testes.

## Autenticação no Amazon ECR

A EC2 utiliza as credenciais temporárias fornecidas pela IAM Role.

```bash
aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com
```

Não é necessário copiar credenciais permanentes para a máquina.

## Validar o Compose

```bash
docker compose \
  -f compose.yaml \
  config
```

## Baixar as imagens

```bash
docker compose \
  -f compose.yaml \
  pull
```

## Iniciar o ambiente

```bash
docker compose \
  -f compose.yaml \
  up -d
```

## Consultar os containers

```bash
docker compose \
  -f compose.yaml \
  ps
```

## Consultar o consumo de recursos

```bash
docker stats --no-stream
free -h
df -h /
```

## Testar a aplicação dentro da EC2

```bash
curl -s http://localhost:8081/actuator/health |
python3 -m json.tool
```

## Consultar logs

```bash
docker compose \
  -f compose.yaml \
  logs --tail=100 pagamento-service
```

Acompanhar em tempo real:

```bash
docker compose \
  -f compose.yaml \
  logs -f pagamento-service
```

Sair do acompanhamento:

```text
Ctrl + C
```

## Atualizar a aplicação

Depois que uma nova imagem `latest` for publicada no ECR:

```bash
docker compose \
  -f compose.yaml \
  pull pagamento-service
```

```bash
docker compose \
  -f compose.yaml \
  up -d pagamento-service
```

## Parar sem remover

```bash
docker compose \
  -f compose.yaml \
  stop
```

## Iniciar novamente

```bash
docker compose \
  -f compose.yaml \
  start
```

## Remover containers e rede

```bash
docker compose \
  -f compose.yaml \
  down
```

Os volumes continuam preservados.

## Cuidado com volumes

Este comando também remove os volumes e os dados:

```bash
docker compose \
  -f compose.yaml \
  down -v
```

Não deve ser executado quando quisermos preservar o PostgreSQL ou o Kafka.

## Persistência

```text
pagamento-postgres-data
    └── tabelas e registros do pagamento-service

kafka-data
    └── tópicos, mensagens e offsets dos consumidores
```

## Comunicação interna

Os containers usam nomes de serviços como endereços:

```text
pagamento-service → pagamento-postgres:5432
pagamento-service → kafka:29092
```

Dentro de um container, `localhost` representa o próprio container, não outro serviço.

## Controle dos logs

Cada serviço utiliza rotação:

```text
tamanho máximo por arquivo: 10 MB
quantidade mantida:          3 arquivos
máximo aproximado:          30 MB por container
```

Essa configuração evita que uma exceção repetitiva ocupe todo o disco da EC2.

## Acessos administrativos

```text
Session Manager → terminal pelo Console AWS
SSH             → terminal remoto com chave privada
WinSCP          → transferência visual de arquivos por SFTP
```

## Estado atual do laboratório

O fluxo abaixo foi comprovado:

```text
mensagem no tópico pedidos-criados
        ↓
PedidoCriadoConsumer
        ↓
PagamentoService
        ↓
PostgreSQL
        ↓
pagamento com status PENDENTE
```

A implantação automática termina atualmente no Amazon ECR.

```text
GitHub Actions / Jenkins → ECR     automático
ECR → EC2                          manual
```

A automação da implantação será estudada posteriormente com Amazon ECS.