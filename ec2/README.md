# Implantação educacional da plataforma Recomeço na Amazon EC2

Este diretório contém a configuração utilizada para executar a plataforma
Recomeço em uma instância Amazon EC2 usando Docker Compose.

O ambiente reúne:

- o monólito `ProjetoSpringBoot`;
- o microserviço `pagamento-service`;
- o microserviço `logistica-service`;
- três bancos PostgreSQL independentes;
- Redis;
- Apache Kafka;
- Keycloak;
- integrações com S3, SQS, SNS, Lambda e SES;
- atualização manual ou automatizada pelo GitHub Actions e AWS Systems Manager.

Esta implantação possui finalidade educacional. Ela foi mantida simples para
facilitar o estudo das tecnologias e da comunicação entre os componentes.

---

## Arquitetura geral

```text
Internet
    ↓
Security Group da EC2
    ├── porta 8080 → ProjetoSpringBoot
    ├── porta 8081 → pagamento-service
    ├── porta 8084 → logistica-service
    └── porta 22   → SSH opcional, restrito ao IP do desenvolvedor
    ↓
Amazon EC2
    ↓
Docker Compose
    ├── projeto-springboot:8080
    │       ├── monolito-postgres:5432
    │       ├── redis:6379
    │       ├── kafka:29092
    │       ├── keycloak:8080
    │       └── logistica-service:8084
    │
    ├── pagamento-service:8081
    │       ├── pagamento-postgres:5432
    │       └── kafka:29092
    │
    ├── logistica-service:8084
    │       ├── logistica-postgres:5432
    │       └── keycloak:8080
    │
    ├── kafka:29092
    ├── redis:6379
    └── keycloak:8080
```

Os bancos, o Redis e o Kafka não possuem portas publicadas para a internet.

Eles são acessados somente pela rede interna criada pelo Docker Compose.

---

## Serviços do Docker Compose

```text
projeto-springboot
pagamento-service
logistica-service
monolito-postgres
pagamento-postgres
logistica-postgres
redis
kafka
keycloak
```

São nove serviços executados na mesma rede Docker.

---

## Comunicação entre as aplicações

### Fluxo de criação do pedido

```text
cliente HTTP
    ↓ JWT do usuário
ProjetoSpringBoot
    ↓
PostgreSQL do monólito
    ↓ Outbox
Kafka: pedidos-criados
    ├── pagamento-service
    ├── consumer de estoque
    └── consumer de notificação
```

### Fluxo de pagamento e logística

```text
pagamento-service
    ↓ pagamento aprovado
Kafka: pagamentos-processados
    ↓
ProjetoSpringBoot
    ↓ registra APROVADO
PostgreSQL do monólito
    ↓
ProjetoSpringBoot solicita token
    ↓ client_credentials
Keycloak
    ↓ JWT técnico
ProjetoSpringBoot
    ↓ REST + Bearer Token
logistica-service
    ↓
PostgreSQL da logística
    ↓
entrega AUTORIZADA
    ↓
ProjetoSpringBoot registra statusLogistica=AUTORIZADA
```

A comunicação com pagamentos é assíncrona por Kafka.

A comunicação com logística é síncrona por REST e protegida por OAuth2/JWT.

---

## Fluxo AWS dos relatórios

```text
POST /pedidos/{pedidoId}/relatorios
    ↓
ProjetoSpringBoot
    ↓
Amazon SQS
    ↓
consumer de relatórios
    ↓
gera PDF
    ↓
Amazon S3
    ↓
banco marca relatório como DISPONIVEL
    ↓
Amazon SNS
    ├── assinatura de e-mail
    ├── SQS de auditoria
    │       ↓
    │   consumer de auditoria
    │       ↓
    │   PostgreSQL do monólito
    │
    └── AWS Lambda
            ↓
        lê o PDF no S3
            ↓
        Amazon SES
            ↓
        e-mail formatado com PDF anexado
```

O download do relatório utiliza uma URL pré-assinada do S3 com validade
limitada.

---

## Origem das imagens

```text
código no GitHub
    ↓
GitHub Actions / Jenkins
    ↓
Amazon ECR
    ↓
Amazon EC2
    ↓
Docker Compose
```

### ProjetoSpringBoot

```text
033649548808.dkr.ecr.sa-east-1.amazonaws.com/recomeco/projeto-springboot:latest
```

### pagamento-service

```text
033649548808.dkr.ecr.sa-east-1.amazonaws.com/recomeco/pagamento-service:latest
```

### logistica-service

```text
033649548808.dkr.ecr.sa-east-1.amazonaws.com/recomeco/logistica-service:latest
```

PostgreSQL, Redis, Kafka e Keycloak utilizam imagens de registros públicos.

---

## Pré-requisitos da EC2

- Amazon Linux 2023;
- arquitetura `x86_64`;
- Docker Engine;
- Docker Compose;
- Git;
- AWS CLI;
- SSM Agent;
- IAM Role `RecomecoEc2DevRole`;
- Security Group configurado;
- repositório clonado em `/home/ec2-user/recomeco-stack-local`.

A instância utilizada no laboratório possui memória suficiente para executar
todos os containers simultaneamente.

---

## Portas publicadas

```text
EC2:8080 → projeto-springboot:8080
EC2:8081 → pagamento-service:8081
EC2:8084 → logistica-service:8084
EC2:8085 → keycloak:8080
```

Durante o laboratório, as portas públicas devem ser liberadas somente para o
IP do desenvolvedor.

Os bancos e componentes internos permanecem sem porta pública:

```text
monolito-postgres:5432  → somente rede Docker
pagamento-postgres:5432 → somente rede Docker
logistica-postgres:5432 → somente rede Docker
redis:6379              → somente rede Docker
kafka:29092             → somente rede Docker
```

---

## Nome local para a EC2

Como o endereço IPv4 público pode mudar depois que a instância é parada e
iniciada, o Windows pode utilizar o arquivo:

```text
C:\Windows\System32\drivers\etc\hosts
```

Exemplo:

```text
IP_PUBLICO_ATUAL recomeco-ec2.test
```

Depois da alteração:

```powershell
ipconfig /flushdns
```

As aplicações podem ser acessadas por:

```text
http://recomeco-ec2.test:8080
http://recomeco-ec2.test:8081
http://recomeco-ec2.test:8084
```

---

## Variáveis no Insomnia

Exemplo de Environment:

```json
{
  "monolito_url": "http://recomeco-ec2.test:8080/ProjetoSpringBoot",
  "pagamento_url": "http://recomeco-ec2.test:8081",
  "logistica_url": "http://recomeco-ec2.test:8084",
  "monolito_token": "",
  "keycloak_token": ""
}
```

Exemplos de uso:

```text
{{ monolito_url }}/auth/login
{{ monolito_url }}/clientes
{{ monolito_url }}/pedidos
{{ pagamento_url }}/actuator/health
{{ logistica_url }}/actuator/health
```

---

## IAM Role da EC2

A EC2 utiliza:

```text
RecomecoEc2DevRole
```

Permissões principais:

```text
RecomecoEc2DevRole
    ├── AmazonSSMManagedInstanceCore
    │       └── comunicação com AWS Systems Manager
    │
    ├── AmazonEC2ContainerRegistryReadOnly
    │       └── download das imagens privadas do ECR
    │
    └── RecomecoEc2AwsServicesDevPolicy
            ├── objetos do bucket S3 do laboratório
            ├── filas SQS de relatórios e auditoria
            └── tópico SNS de relatórios
```

A EC2 recebe credenciais temporárias automaticamente pela IAM Role.

Não existem access keys permanentes armazenadas no Compose ou na máquina.

---

## IMDSv2 e containers

O AWS SDK utilizado pelo monólito obtém as credenciais da role pelo
Instance Metadata Service.

Configuração da EC2:

```text
Instance metadata service:           Enabled
IMDSv2:                               Required
Metadata response hop limit:          2
Access to tags in instance metadata: Disabled
```

O valor `2` permite que a resposta atravesse a camada adicional da rede
Docker.

```text
container do monólito
    ↓ DefaultCredentialsProvider
IMDSv2
    ↓
RecomecoEc2DevRole
    ↓ credenciais temporárias
S3 + SQS + SNS
```

---

## Perfis de credenciais AWS

No computador local, a aplicação pode utilizar um perfil configurado pela
AWS CLI.

Na EC2, as propriedades de perfil permanecem vazias:

```yaml
APPLICATION_AWS_S3_CREDENTIALS_PROFILE: ""
APPLICATION_AWS_SQS_CREDENTIALS_PROFILE: ""
APPLICATION_AWS_SNS_CREDENTIALS_PROFILE: ""
```

Isso faz as configurações Java utilizarem:

```text
DefaultCredentialsProvider
    ↓
credenciais temporárias da IAM Role
```

---

## Autenticação do usuário no monólito

```text
usuário e senha
    ↓
POST /auth/login
    ↓
ProjetoSpringBoot valida no PostgreSQL
    ↓
JWT próprio do monólito
    ↓
Authorization: Bearer token
```

Esse token protege os endpoints de clientes, pedidos e relatórios.

---

## Autenticação entre monólito e logística

```text
ProjetoSpringBoot
    ↓ client_id + client_secret
Keycloak
    ↓ access token JWT
ProjetoSpringBoot
    ↓ Authorization: Bearer token
logistica-service
    ↓ valida assinatura, issuer e expiração
EntregaController
    ↓
EntregaService
```

O token do usuário do monólito e o token técnico do Keycloak são diferentes.

```text
token do monólito
    → usuário chama ProjetoSpringBoot

token do Keycloak
    → ProjetoSpringBoot chama logistica-service
```

---

## Acesso administrativo ao Keycloak

A forma recomendada é utilizar um túnel SSH:

```powershell
ssh `
  -i "$env:USERPROFILE\Downloads\recomeco-ec2-dev-key.pem" `
  -N `
  -L 18085:localhost:8085 `
  ec2-user@IP_PUBLICO_DA_EC2
```

Depois:

```text
http://localhost:18085/admin/
```

O terminal do túnel deve permanecer aberto.

Para encerrá-lo:

```text
Ctrl + C
```

---

## Volumes persistentes

```text
monolito-postgres-data
    └── tabelas e registros do ProjetoSpringBoot

pagamento-postgres-data
    └── tabelas e registros do pagamento-service

logistica-postgres-data
    └── tabelas e registros do logistica-service

kafka-data
    └── tópicos, mensagens e offsets dos consumidores
```

Os dados sobrevivem à recriação dos containers.

O Redis não possui volume porque armazena somente cache reconstruível.

O realm do Keycloak é importado a partir do arquivo versionado:

```text
ec2/keycloak/recomeco-realm.json
```

---

## Comunicação interna do Docker

Os containers utilizam os nomes dos serviços como DNS:

```text
projeto-springboot → monolito-postgres:5432
projeto-springboot → redis:6379
projeto-springboot → kafka:29092
projeto-springboot → keycloak:8080
projeto-springboot → logistica-service:8084

pagamento-service → pagamento-postgres:5432
pagamento-service → kafka:29092

logistica-service → logistica-postgres:5432
logistica-service → keycloak:8080
```

Dentro de um container, `localhost` representa o próprio container.

Para alcançar outro container, utiliza-se o nome do serviço.

---

## Configuração do datasource do monólito

O Compose fornece diretamente as propriedades reconhecidas pelo Spring:

```yaml
SPRING_DATASOURCE_URL: jdbc:postgresql://monolito-postgres:5432/projetodb
SPRING_DATASOURCE_USERNAME: postgres
SPRING_DATASOURCE_PASSWORD: postgres
```

O Spring realiza o mapeamento:

```text
SPRING_DATASOURCE_URL
    ↓
spring.datasource.url
    ↓
HikariDataSource
    ↓
PostgreSQL
```

Variáveis de ambiente possuem prioridade sobre os valores presentes em
`application.yaml` e `application-docker.yaml`.

---

## Limites de memória das aplicações

As JVMs possuem limites explícitos para evitar consumo descontrolado:

```text
ProjetoSpringBoot
    → -Xms256m -Xmx768m

pagamento-service
    → -Xms128m -Xmx384m

logistica-service
    → -Xms128m -Xmx384m

Keycloak
    → -Xms256m -Xmx512m

Kafka
    → -Xms256m -Xmx384m
```

Esses valores são adequados ao laboratório e podem ser revisados conforme
a capacidade da instância.

---

## Controle dos logs

Cada container utiliza rotação:

```text
tamanho máximo por arquivo: 10 MB
quantidade mantida:          3 arquivos
máximo aproximado:          30 MB por container
```

A configuração global do Docker também protege contra crescimento
descontrolado dos arquivos JSON de log.

O monólito escreve os logs no console do container na EC2. O arquivo de log
utilizado pelo ambiente local permanece desativado nessa implantação.

---

## Monitoração nesta etapa

A stack EC2 não executa:

```text
Prometheus
Grafana
Loki
Alloy
Jaeger
```

Essas ferramentas permanecem no laboratório local.

Na EC2, a operação atual utiliza:

```text
Actuator health
docker compose logs
docker stats
rotação de logs
```

CloudWatch será estudado separadamente para logs, métricas e alarmes.

---

## Clonar o repositório na EC2

```bash
cd ~

git clone \
  https://github.com/rmbredes/recomeco-stack-local.git
```

O repositório público pode ser clonado sem token.

---

## Entrar no diretório da implantação

```bash
cd ~/recomeco-stack-local/ec2
```

---

## Validar o Compose

```bash
docker compose config --quiet
```

Sem saída significa que a configuração é válida.

Listar serviços:

```bash
docker compose config --services
```

---

## Autenticar o Docker no Amazon ECR

```bash
aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com
```

O login utiliza credenciais temporárias da IAM Role da EC2.

O token do Docker no ECR é temporário e deve ser renovado antes de novos
downloads quando estiver expirado.

---

## Implantação manual

```bash
cd ~/recomeco-stack-local

git switch master

git pull --ff-only origin master

cd ec2

aws ecr get-login-password \
  --region sa-east-1 |
docker login \
  --username AWS \
  --password-stdin \
  033649548808.dkr.ecr.sa-east-1.amazonaws.com

docker compose pull

docker compose up \
  -d \
  --remove-orphans

docker compose ps
```

Fluxo:

```text
git pull
    ↓
login temporário no ECR
    ↓
docker compose pull
    ↓
docker compose up
    ↓
docker compose ps
```

---

## CI da stack

Arquivo:

```text
.github/workflows/ci.yaml
```

O CI é executado em:

```text
Pull Request para master
push na master
```

Ele baixa os quatro repositórios:

```text
recomeco-stack-local
ProjetoSpringBoot
pagamento-service
logistica-service
```

Depois valida a configuração integrada:

```text
docker compose config --quiet
docker compose config --services
```

O CI verifica o código e a configuração, mas não altera a EC2.

---

## CD da stack por GitHub Actions e SSM

Arquivo:

```text
.github/workflows/deploy-ec2.yaml
```

O CD é iniciado manualmente:

```text
GitHub
    ↓
recomeco-stack-local
    ↓
Actions
    ↓
CD - Implantar na EC2
    ↓
Run workflow
    ↓
master
```

Fluxo interno:

```text
GitHub Actions
    ↓ OIDC
GitHubActionsEcrRecomecoRole
    ↓ ssm:SendCommand
AWS Systems Manager
    ↓
SSM Agent da EC2
    ↓
script executado como ec2-user
    ├── git pull
    ├── login no ECR
    ├── docker compose pull
    ├── docker compose up
    └── docker compose ps
    ↓
resultado devolvido ao GitHub
```

O workflow não armazena:

```text
chave .pem
senha da EC2
access key permanente
secret key permanente
```

A implantação só é autorizada quando o workflow é executado pela branch
`master`.

A instância precisa estar ligada e registrada como managed node no Systems
Manager.

---

## Role do GitHub Actions

O GitHub assume temporariamente:

```text
GitHubActionsEcrRecomecoRole
```

A trust policy permite somente as branches `master` dos repositórios
autorizados.

Para o repositório da stack:

```text
repo:rmbredes@312544427/recomeco-stack-local@1366601047:ref:refs/heads/master
```

A permissão de implantação permite:

```text
ssm:SendCommand
    → somente AWS-RunShellScript
    → somente a EC2 do laboratório

ssm:GetCommandInvocation
    → consulta resultado da execução
```

---

## Systems Manager

O AWS Systems Manager administra a EC2 por meio do SSM Agent.

### Session Manager

```text
usuário
    ↓
terminal interativo no Console AWS
    ↓
SSM Agent
    ↓
EC2
```

### Run Command

```text
GitHub Actions
    ↓
comando não interativo
    ↓
SSM Agent
    ↓
script executado na EC2
    ↓
status e saída retornam ao GitHub
```

O SSM evita colocar chaves SSH dentro do workflow.

---

## Consultar os containers

```bash
docker compose ps
```

Incluir containers parados:

```bash
docker compose ps -a
```

---

## Consultar logs

### Monólito

```bash
docker compose logs \
  --tail=100 \
  projeto-springboot
```

### Pagamentos

```bash
docker compose logs \
  --tail=100 \
  pagamento-service
```

### Logística

```bash
docker compose logs \
  --tail=100 \
  logistica-service
```

### Acompanhar em tempo real

```bash
docker compose logs \
  -f \
  projeto-springboot
```

Para sair:

```text
Ctrl + C
```

---

## Consultar recursos da EC2

### Containers

```bash
docker stats --no-stream
```

### Memória geral

```bash
free -h
```

O campo mais importante é:

```text
available
```

Ele considera memória livre e cache que o Linux pode liberar.

### Disco

```bash
df -h /
```

### Uso interno do Docker

```bash
docker system df
```

---

## Health checks

### ProjetoSpringBoot

```bash
curl -s \
  http://localhost:8080/ProjetoSpringBoot/actuator/health |
python3 -m json.tool
```

### pagamento-service

```bash
curl -s \
  http://localhost:8081/actuator/health |
python3 -m json.tool
```

### logistica-service

```bash
curl -s \
  http://localhost:8084/actuator/health |
python3 -m json.tool
```

Resultado esperado:

```json
{
  "status": "UP"
}
```

O health da logística é público. Os endpoints de negócio exigem JWT do
Keycloak.

---

## Teste funcional completo

```text
1. cadastrar usuário no monólito
2. fazer login
3. guardar JWT do usuário
4. cadastrar cliente
5. criar pedido
6. confirmar recebimento no pagamento-service
7. aprovar pagamento
8. confirmar APROVADO no monólito
9. aguardar integração REST
10. confirmar AUTORIZADA na logística
11. solicitar relatório
12. confirmar DISPONIVEL
13. gerar URL temporária
14. baixar PDF do S3
15. conferir auditoria
16. conferir e-mail do SNS
17. conferir e-mail com anexo enviado por Lambda e SES
```

Fluxo final:

```text
cliente
    ↓
ProjetoSpringBoot
    ↓ Kafka
pagamento-service
    ↓ Kafka
ProjetoSpringBoot
    ↓ Keycloak
logistica-service
    ↓
entrega autorizada

ProjetoSpringBoot
    ↓ SQS
gera PDF
    ↓ S3
publica SNS
    ├── e-mail
    ├── auditoria SQS
    └── Lambda → SES
```

---

## Mensagem inválida no Kafka

Durante o laboratório, uma mensagem vazia foi enviada ao tópico
`pedidos-criados`.

```text
mensagem vazia
    ↓
falha de desserialização
    ↓
consumer repete a leitura
    ↓
logs crescem continuamente
```

Cada grupo possui seu próprio offset:

```text
pagamento-service-group
estoque-service-group
notificacao-service-group
```

Avançar um grupo não altera os demais.

A correção foi feita avançando somente o offset inválido e preservando a
mensagem válida seguinte.

---

## Incidente de disco cheio

Uma repetição de erros criou aproximadamente 8,6 GB de logs.

```text
erro repetitivo
    ↓
arquivo JSON de log cresce
    ↓
disco chega a 100%
    ↓
Docker e Kafka ficam inconsistentes
```

A recuperação incluiu:

```text
parar o serviço problemático
    ↓
identificar o arquivo de log
    ↓
recuperar espaço
    ↓
corrigir o offset
    ↓
recriar os containers
    ↓
configurar rotação de logs
```

A rotação atual reduz o risco de repetição desse problema.

---

## Parar e iniciar serviços

### Parar toda a stack sem remover

```bash
docker compose stop
```

### Iniciar novamente

```bash
docker compose start
```

### Parar somente um serviço

```bash
docker compose stop projeto-springboot
```

### Iniciar somente um serviço

```bash
docker compose start projeto-springboot
```

### Recriar somente um serviço

```bash
docker compose up \
  -d \
  projeto-springboot
```

---

## Remover containers

```bash
docker compose down
```

Os volumes permanecem preservados.

Este comando também remove os volumes:

```bash
docker compose down -v
```

Ele não deve ser executado quando quisermos preservar bancos e Kafka.

---

## Parar a instância EC2

Quando o laboratório não estiver sendo utilizado, a instância pode ser
parada pelo Console AWS:

```text
EC2
    ↓
Instance state
    ↓
Stop instance
```

Não é necessário selecionar `Skip OS shutdown`.

Ao parar:

```text
cobrança de processamento da instância é interrompida
containers deixam de executar
volumes EBS continuam preservados
IPv4 público pode mudar na próxima inicialização
```

Depois de iniciar novamente:

```text
1. atualizar o arquivo hosts do Windows
2. executar ipconfig /flushdns
3. conferir docker compose ps
4. executar health checks
```

---

## Segurança aplicada

```text
Security Group
    └── portas públicas restritas ao IP do desenvolvedor

IAM Role da EC2
    └── somente permissões necessárias

IMDSv2
    └── credenciais temporárias dentro dos containers

GitHub OIDC
    └── nenhuma chave AWS permanente no GitHub

SSM
    └── implantação sem chave SSH no workflow

Keycloak
    └── JWT técnico entre aplicações

JWT do monólito
    └── autenticação dos usuários
```

---

## Situação atual da automação

```text
Pull Request
    ↓
CI valida configuração
    ↓
merge na master
    ↓
imagens das aplicações publicadas no ECR
    ↓
Run workflow manual
    ↓
GitHub Actions
    ↓
SSM
    ↓
EC2
    ↓
Docker Compose atualiza a plataforma
```

A implantação permanece manualmente acionada para evitar mudanças acidentais
e permitir controle durante o estudo.

---

## Próxima etapa planejada

Com a etapa EC2 concluída, o próximo assunto é Amazon ECS:

```text
imagem no ECR
    ↓
Task Definition
    ↓
Task
    ↓
Service
    ↓
Cluster ECS
```

Serão estudados:

- cluster;
- task definition;
- task;
- service;
- Fargate;
- roles de execução e aplicação;
- logs no CloudWatch;
- comparação entre Docker Compose, EC2 e ECS.