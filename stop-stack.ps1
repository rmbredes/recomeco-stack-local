$ErrorActionPreference = "Stop"

Push-Location -LiteralPath $PSScriptRoot

try {
    Write-Host "Parando a stack local sem apagar os volumes..."
    docker compose down

    if ($LASTEXITCODE -ne 0) {
        throw "O Docker Compose nao conseguiu parar a stack."
    }

    Write-Host "Stack local parada. Os volumes foram preservados."
}
finally {
    Pop-Location
}
