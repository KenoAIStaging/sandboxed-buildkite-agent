# Install the AWS CLI v2.
#
# The Julia CI artifact-staging flow uploads build artifacts to S3 with a
# conditional write (`aws s3api put-object --if-none-match`), which requires
# AWS CLI v2 >= 2.19.  The canonical MSI below always installs the latest v2,
# so this stays comfortably ahead of that floor.
Write-Output " -> Installing AWS CLI v2"

$awsUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$awsMsi = Join-Path $env:TEMP "AWSCLIV2.msi"
Invoke-WebRequest -Uri $awsUrl -OutFile $awsMsi -ErrorAction Stop

$proc = Start-Process -FilePath "msiexec.exe" `
    -ArgumentList "/i", "`"$awsMsi`"", "/qn", "/norestart" -PassThru
if (-not $proc.WaitForExit(300000)) {
    try { $proc.Kill() } catch {}
    throw "AWS CLI install timed out after 300s (msiexec still running)"
}
# 0 = success, 3010 = success but a reboot is pending; both are fine here.
if ($proc.ExitCode -ne 0 -and $proc.ExitCode -ne 3010) {
    throw "AWS CLI install failed (msiexec exit code $($proc.ExitCode))"
}
