#!/bin/sh
echo "### Checking things for user: $(whoami)"

set -- "wheel" "sudo" "docker" "podman" 
#groups=("wheel" "sudo" "docker" "podman")
echo "### Checking groups"
printf %s\,\   "$@"
echo ""
for group in "$@"; do
if [ $(getent group $group) ]; then
echo "[AVAILABLE✅] - $group group"
else
echo "[MISSING❌] - $group group"
fi
done

set -- "sudo" "bash" "nala" "apt" "yum" "dnf" "apk" "snap" "git" "curl" "wget" "make" "nvim" "iptables" "firewall-cmd" "ufw" "docker" "podman" "docker-compose" "podman-compose" "getenforce" "aa-status" "cargo" "node" "nvm" "python" "python3" "pip" "pip3"
echo "### Checking commands"
printf %s\,\   "$@"
echo ""
for cmd in "$@"; do
if [ -x "$(command -v $cmd)" ]; then
echo "[AVAILABLE✅] - $cmd"
else
echo "[MISSING❌] - $cmd"
fi
done
