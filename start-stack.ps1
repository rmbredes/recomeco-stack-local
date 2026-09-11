param(
    # Perfil que assume a role utilizada pelo laboratório.
    [string]$AwsProfile = "projeto-s3",

    # Perfil interativo utilizado pelo comando aws login.
    [string]$LoginProfile = "default"
)

$ErrorActionPreference = "Stop"

function Get-TemporaryAwsCredentials {
    param(
        [string]$Profile
    )

    # O erro da primeira tentativa não é exibido porque pode representar
    # apenas uma sessão expirada, situação tratada logo abaixo.
    $credentialsJson = aws configure export-credentials `
        --profile $Profile `
        --format process 2>$null

    if ($LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace($credentialsJson)) {
        return $null
    }

    try {
        return $credentialsJson | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

# Guardamos os valores anteriores para não modificar permanentemente
# o ambiente da janela do PowerShell que chamou este script.
$previousAccessKeyId = $env:AWS_ACCESS_KEY_ID
$previousSecretAccessKey = $env:AWS_SECRET_ACCESS_KEY
$previousSessionToken = $env:AWS_SESSION_TOKEN

Push-Location -LiteralPath $PSScriptRoot

try {
    Write-Host "Obtendo credenciais temporarias do perfil AWS '$AwsProfile'..."

    $credentials = Get-TemporaryAwsCredentials -Profile $AwsProfile

    if ($null -eq $credentials) {
        Write-Host "Sessao AWS ausente ou expirada. Iniciando login pelo perfil '$LoginProfile'..."
        aws login --profile $LoginProfile

        if ($LASTEXITCODE -ne 0) {
            throw "O login na AWS nao foi concluido."
        }

        Write-Host "Login concluido. Obtendo novas credenciais temporarias..."
        $credentials = Get-TemporaryAwsCredentials -Profile $AwsProfile

        if ($null -eq $credentials) {
            throw "Nao foi possivel obter credenciais do perfil AWS '$AwsProfile' apos o login."
        }
    }

    if ([string]::IsNullOrWhiteSpace($credentials.AccessKeyId) -or
        [string]::IsNullOrWhiteSpace($credentials.SecretAccessKey) -or
        [string]::IsNullOrWhiteSpace($credentials.SessionToken)) {
        throw "A AWS CLI nao devolveu todas as credenciais temporarias esperadas."
    }

    # O Docker Compose lê essas variáveis e as entrega somente ao
    # container do monólito, que acessa SQS, S3 e SNS.
    $env:AWS_ACCESS_KEY_ID = $credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $credentials.SessionToken

    Write-Host "Subindo a stack local..."
    docker compose up -d --build

    if ($LASTEXITCODE -ne 0) {
        throw "O Docker Compose nao conseguiu subir a stack."
    }

    Write-Host "Stack iniciada. Estado atual dos containers:"
    docker compose ps

    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel consultar o estado dos containers."
    }
}
finally {
    # As credenciais já foram copiadas para o container. Restauramos
    # o ambiente anterior para não deixá-las na sessão do PowerShell.
    $env:AWS_ACCESS_KEY_ID = $previousAccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $previousSecretAccessKey
    $env:AWS_SESSION_TOKEN = $previousSessionToken

    Pop-Location
}
