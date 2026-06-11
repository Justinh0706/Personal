# Wait
Start-Sleep -Seconds 1

# Install 7-Zip, force installation, and accept source agreements
winget install --id 7zip.7zip -e --source winget --force --accept-package-agreements --accept-source-agreements

# Wait
Start-Sleep -Seconds 1

Exit