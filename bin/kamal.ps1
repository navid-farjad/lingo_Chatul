# Wrapper for running Kamal via Docker on Windows.
#
# The basecamp/kamal Docker image avoids needing Ruby on the host, but Windows
# bind-mounts surface files with 0777 perms which OpenSSH rejects. We mount
# ~/.ssh read-only into a staging path, then copy + chmod inside the container
# before invoking Kamal.
#
# Usage:
#   bin/kamal.ps1 setup
#   bin/kamal.ps1 deploy
#   bin/kamal.ps1 logs

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot\..").Path
$sshDir   = Join-Path $env:USERPROFILE ".ssh"

if (-not (Test-Path $sshDir)) {
  Write-Error "Expected SSH keys at $sshDir"
  exit 1
}

$cmd = ($args -join " ")

docker run --rm -i `
  -v "${repoRoot}:/workdir" `
  -v "${sshDir}:/host_ssh:ro" `
  -w /workdir/api `
  --entrypoint sh `
  ghcr.io/basecamp/kamal:latest `
  -c "mkdir -p /root/.ssh && cp -r /host_ssh/. /root/.ssh/ && chmod 700 /root/.ssh && find /root/.ssh -type f -exec chmod 600 {} \; && kamal $cmd"
