#!/bin/sh
set -e

PORT=2222
CONFIG=/etc/ssh/sshd_config

mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Generate host keys if missing
ssh-keygen -A

# Configure SSH for passwordless root access
cat > "$CONFIG" <<'CONF'
Port 2222
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication no
PermitEmptyPasswords yes
UsePAM no
CONF

# Set root's password to empty
passwd -d root

# Validate and launch SSH
/usr/sbin/sshd -t
echo "SSH listening on port $PORT"
exec /usr/sbin/sshd -D -e -p "$PORT"
