# Implantação educacional na Amazon EC2

Este diretório contém a configuração utilizada para executar parte da
plataforma Recomeco em uma instância Amazon EC2 usando Docker Compose.

## Arquitetura atual

```text
Internet
   ↓
Security Group
   ├── porta 8081 restrita ao IP do desenvolvedor
   └── porta 8084 restrita ao IP do desenvolvedor
   ↓
Amazon EC2
   ↓
Docker Compose
   ├── pagamento-service:8081
   │      └── pagamento-postgres:5432
   │
   ├── logistica-service:8084
   │      └── logistica-postgres:5432
   │
   └── kafka:29092
```

Os bancos PostgreSQL e o Kafka não possuem portas publicadas para a internet.

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

A imagem do `logistica-service` também vem do Amazon ECR:

```text
033649548808.dkr.ecr.sa-east-1.amazonaws.com/recomeco/logistica-service:latest
```

As imagens do PostgreSQL e do Kafka vêm dos respectivos registros públicos.

## Pré-requisitos da EC2

- Amazon Linux 2023;
- Docker Engine;
- Docker Compose;
- Git;
- AWS CLI;
- IAM Role `RecomecoEc2DevRole`;
- política `AmazonSSMManagedInstanceCore`;
- política `AmazonEC2ContainerRegistryReadOnly`;
- Security Group com SSH opcionalmente liberado somente para o IP do desenvolvedor;
- porta `8081` liberada somente para o IP do desenvolvedor durante os testes;
- porta `8084` liberada somente para o IP do desenvolvedor durante os testes.

## Permissões da IAM Role

```text
RecomecoEc2DevRole
        │
        ├── AmazonSSMManagedInstanceCore
        │       └── permite acesso pelo Session Manager
        │
        └── AmazonEC2ContainerRegistryReadOnly
                └── permite baixar imagens do Amazon ECR
```

A EC2 recebe credenciais temporárias automaticamente pela IAM Role.

Não é necessário copiar credenciais permanentes para a máquina.

## Autenticação no Amazon ECR

O login do Docker no ECR utiliza as credenciais temporárias da IAM Role:

```bash
aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com
```

O token utilizado pelo Docker é temporário. Quando ele expirar, o login
deverá ser executado novamente antes de um novo `docker compose pull`.

## Baixar a configuração pelo GitHub

Como o repositório é público, a EC2 pode cloná-lo sem token:

```bash
cd ~
git clone https://github.com/rmbredes/recomeco-stack-local.git
```

Para receber futuras alterações:

```bash
cd ~/recomeco-stack-local
git pull
```

A EC2 possui acesso somente de leitura ao repositório público.

## Entrar no diretório da implantação

```bash
cd ~/recomeco-stack-local/ec2
```

## Validar o Compose

```bash
docker compose config
```

Esse comando valida a estrutura do arquivo sem iniciar containers.

## Baixar as imagens

Primeiro renove o login no ECR:

```bash
aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com
```

Depois baixe as imagens:

```bash
docker compose pull
```

## Iniciar o ambiente

```bash
docker compose up -d
```

O Compose compara a configuração declarada com o estado atual e cria ou
recria somente o que for necessário.

## Consultar os containers

```bash
docker compose ps
```

Para visualizar também containers parados:

```bash
docker compose ps -a
```

## Consultar o consumo de recursos

```bash
docker stats --no-stream
```

```bash
free -h
```

```bash
df -h /
```

Esses comandos mostram, respectivamente:

```text
consumo dos containers
memória da EC2
espaço disponível no disco
```

## Testar o pagamento-service dentro da EC2

```bash
curl -s http://localhost:8081/actuator/health |
python3 -m json.tool
```

O resultado esperado contém:

```text
status UP
PostgreSQL UP
liveness UP
readiness UP
```

## Testar o logistica-service dentro da EC2

O endpoint de health é público e não exige token:

```bash
curl -s http://localhost:8084/actuator/health |
python3 -m json.tool
```

Os demais endpoints permanecem protegidos por OAuth2/JWT.

O Keycloak será adicionado numa etapa posterior.

## Consultar logs do pagamento-service

```bash
docker compose logs \
  --tail=100 \
  pagamento-service
```

Acompanhar em tempo real:

```bash
docker compose logs \
  -f \
  pagamento-service
```

## Consultar logs do logistica-service

```bash
docker compose logs \
  --tail=100 \
  logistica-service
```

Acompanhar em tempo real:

```bash
docker compose logs \
  -f \
  logistica-service
```

Para sair do acompanhamento em tempo real:

```text
Ctrl + C
```

## Atualizar as aplicações

Depois que novas imagens `latest` forem publicadas no ECR, renove o login:

```bash
aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com
```

Atualize as imagens:

```bash
docker compose pull
```

Aplique as atualizações:

```bash
docker compose up -d
```

O fluxo completo é:

```text
git pull
    ↓
renovar login no ECR
    ↓
docker compose pull
    ↓
docker compose up -d
    ↓
docker compose ps
```

## Parar sem remover

```bash
docker compose stop
```

## Iniciar novamente

```bash
docker compose start
```

## Parar apenas um serviço

Exemplo:

```bash
docker compose stop pagamento-service
```

## Iniciar apenas um serviço

Exemplo:

```bash
docker compose start pagamento-service
```

## Remover containers e rede

```bash
docker compose down
```

Os volumes continuam preservados.

## Cuidado com volumes

Este comando também remove os volumes e seus dados:

```bash
docker compose down -v
```

Não deve ser executado quando quisermos preservar os bancos PostgreSQL
ou os dados do Kafka.

## Persistência

```text
pagamento-postgres-data
    └── tabelas e registros do pagamento-service

logistica-postgres-data
    └── tabelas e registros do logistica-service

kafka-data
    └── tópicos, mensagens e offsets dos consumidores
```

Os dados ficam armazenados em volumes Docker e sobrevivem à recriação
dos containers.

## Comunicação interna

Os containers utilizam os nomes dos serviços como endereços:

```text
pagamento-service → pagamento-postgres:5432
pagamento-service → kafka:29092
logistica-service → logistica-postgres:5432
```

O Docker possui um DNS interno que resolve esses nomes.

Dentro de um container, `localhost` representa o próprio container,
não outro serviço.

## Healthcheck interno do Kafka

O healthcheck do Kafka utiliza:

```text
localhost:29092
```

Isso funciona porque o comando é executado dentro do próprio container Kafka.

Já o pagamento utiliza:

```text
kafka:29092
```

porque está em outro container.

## Portas publicadas

```text
EC2:8081 → pagamento-service:8081
EC2:8084 → logistica-service:8084
```

As portas dos bancos e do Kafka não são publicadas:

```text
pagamento-postgres:5432 → somente rede Docker
logistica-postgres:5432 → somente rede Docker
kafka:29092             → somente rede Docker
```

O Security Group deve liberar as portas das aplicações somente para o
IP do desenvolvedor durante o laboratório.

## Controle dos logs

Cada serviço utiliza rotação:

```text
tamanho máximo por arquivo: 10 MB
quantidade mantida:          3 arquivos
máximo aproximado:          30 MB por container
```

Essa configuração impede que uma exceção repetitiva ocupe todo o disco
da EC2.

## Incidente estudado: disco cheio

Uma mensagem vazia enviada ao Kafka causou falhas repetidas de
desserialização no pagamento-service.

O fluxo do problema foi:

```text
mensagem vazia
    ↓
erro repetitivo no consumidor
    ↓
arquivo de log cresceu para 8,6 GB
    ↓
disco da EC2 chegou a 100%
    ↓
containers ficaram inconsistentes
```

A correção realizada foi:

```text
parar o pagamento-service
    ↓
zerar somente o arquivo de log corrompido
    ↓
recuperar espaço no disco
    ↓
avançar o offset além da mensagem inválida
    ↓
recriar os containers
    ↓
configurar rotação dos logs
```

## Acessos administrativos

```text
Session Manager → terminal pelo Console AWS
SSH             → terminal remoto com chave privada
WinSCP          → transferência visual de arquivos por SFTP
```

## Fluxo Kafka comprovado

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

## Fluxo de entrega planejado

Quando o Keycloak e o monólito forem adicionados:

```text
pagamento aprovado
        ↓ Kafka
monólito recebe pagamentos-processados
        ↓
monólito solicita token ao Keycloak
        ↓
REST + Bearer JWT
        ↓
logistica-service
        ↓
logistica-postgres
```

## Situação da automação

A implantação automática termina atualmente no Amazon ECR:

```text
GitHub Actions / Jenkins → ECR     automático
ECR → EC2                          manual
```

Na EC2, a atualização ainda exige:

```text
git pull
docker login no ECR
docker compose pull
docker compose up -d
```

Essa última etapa poderá ser automatizada futuramente ou substituída
pela administração de containers com Amazon ECS.