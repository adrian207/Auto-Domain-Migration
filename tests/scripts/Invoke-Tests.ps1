param(
    [ValidateSet('Integration','All')]
    [string] $Suite = 'All'
)

if ($Suite -in @('Integration','All')) {
    Write-Host 'Running integration tests...'
    Invoke-Pester -Path ../integration/Test-ServerMigration.Tests.ps1 -Output Detailed
}
