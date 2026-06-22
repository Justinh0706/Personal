$AeExe = "C:\Program Files (x86)\AutoElevate\AEUACAgent.exe"

$LocalMsi = "C:\Windows\Temp\AESetup.msi"
$MsiUrl = "https://autoelevate-installers.s3.us-east-2.amazonaws.com/current/AESetup.msi"

if (-not (Test-Path $AeExe)) {

    Invoke-WebRequest -Uri $MsiUrl -OutFile $LocalMsi -UseBasicParsing

    $Process = Start-Process "msiexec.exe" -ArgumentList @(
        '/i'
        "`"$LocalMsi`""
        '/quiet'
        'LICENSE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjVlNDg4NzZiLWE3NzEtNGU3MC05Y2UwLTFlMWUwZWIwODJhNiIsIm5hbWUiOiJTdXByYWNvbSBCLlYuIiwiaWF0IjoxNzY5NDQxMjMyfQ.wWloe5E7mpQOc1zUBvXVTMA_YxTaLz5rxYrHtMHbIds"'
        'COMPANY_NAME="Tandzorg Centrum Ermelo"'
        'COMPANY_INITIALS="LCE"'
        'LOCATION_NAME="Wiekslag"'
        'ELEVATE_MODE="audit"'
        'BLOCKER_MODE="disabled"'
    ) -Wait -NoNewWindow -PassThru

    if ($Process.ExitCode -eq 0) {
        Remove-Item -Path $LocalMsi -Force -ErrorAction SilentlyContinue
    }
}