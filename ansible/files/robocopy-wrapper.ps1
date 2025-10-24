param(
    [Parameter(Mandatory)] [string] $Source,
    [Parameter(Mandatory)] [string] $Destination,
    [string[]] $Options = @('/MIR','/R:2','/W:5','/NFL','/NDL')
)

$arguments = @($Source, $Destination) + $Options
Write-Host "Invoking robocopy $($arguments -join ' ')"
$process = Start-Process -FilePath 'robocopy.exe' -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ge 8) {
    throw "Robocopy failed with exit code $($process.ExitCode)"
}
