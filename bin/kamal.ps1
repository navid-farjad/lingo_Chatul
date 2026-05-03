# Wrapper for running Kamal via Docker on Windows.
#
# The basecamp/kamal Docker image avoids needing Ruby on the host, but Windows
# bind-mounts surface files with 0777 perms which OpenSSH rejects. We mount
# ~/.ssh read-only into a staging path, then copy + chmod inside the container
# before invoking Kamal. We also stage /root/.docker/config.json so buildx can
# push to ghcr.io using KAMAL_REGISTRY_PASSWORD from .env.
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

# Read KAMAL_REGISTRY_PASSWORD from .env (so the container can stage docker auth).
$envFile = Join-Path $repoRoot ".env"
$registryPw = ""
if (Test-Path $envFile) {
  $line = Select-String -Path $envFile -Pattern "^KAMAL_REGISTRY_PASSWORD=" | Select-Object -First 1
  if ($line) { $registryPw = ($line.Line -replace "^KAMAL_REGISTRY_PASSWORD=", "") }
}

# Write the prep script to a file under bin/ so the container can source it
# without any PowerShell-side variable expansion munging the contents.
$prepPath = Join-Path $PSScriptRoot "kamal-prep.sh"
$prepBody = @'
#!/bin/sh
set -e
mkdir -p /root/.ssh
cp -r /host_ssh/. /root/.ssh/
chmod 700 /root/.ssh
find /root/.ssh -type f -exec chmod 600 {} \;
cat >/root/.ssh/config <<'SSH_EOF'
Host 49.12.247.57
  User root
  IdentityFile /root/.ssh/lingo_chatul
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
SSH_EOF
chmod 600 /root/.ssh/config
mkdir -p /root/.docker
if [ -n "$KAMAL_REGISTRY_PASSWORD" ]; then
  AUTH=$(printf 'navid-farjad:%s' "$KAMAL_REGISTRY_PASSWORD" | base64 -w0)
  printf '{"auths":{"ghcr.io":{"auth":"%s"}}}\n' "$AUTH" >/root/.docker/config.json
  chmod 600 /root/.docker/config.json
fi
'@
# Write with LF endings (no BOM) so sh can parse it.
[System.IO.File]::WriteAllText($prepPath, ($prepBody -replace "`r", ""))

docker run --rm -i `
  -v "${repoRoot}:/workdir" `
  -v "${sshDir}:/host_ssh:ro" `
  -e "KAMAL_REGISTRY_PASSWORD=$registryPw" `
  -w /workdir/api `
  --entrypoint sh `
  ghcr.io/basecamp/kamal:latest `
  -c ". /workdir/bin/kamal-prep.sh && kamal $cmd"
