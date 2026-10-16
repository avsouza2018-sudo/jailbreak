#!/bin/sh
set -e

SSH_DIR="/root/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"
PORT=2222

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

echo "=== iSH OpenSSH setup ==="

if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    ssh-keygen -A
fi

if [ ! -f /etc/ssh/sshd_config ]; then
    touch /etc/ssh/sshd_config
fi

if ! grep -q '^[[:space:]]*Port ' /etc/ssh/sshd_config; then
    echo "Port $PORT" >> /etc/ssh/sshd_config
fi

if ! grep -q '^[[:space:]]*PubkeyAuthentication ' /etc/ssh/sshd_config; then
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
fi

if ! grep -q '^[[:space:]]*PermitRootLogin ' /etc/ssh/sshd_config; then
    echo "PermitRootLogin prohibit-password" >> /etc/ssh/sshd_config
fi

echo
echo "Paste your computer's PUBLIC SSH key below."
echo "It should start with ssh-ed25519 or ssh-rsa."
printf "Public key: "
IFS= read -r KEY

case "$KEY" in
    ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-nistp256\ *)
        if ! grep -Fqx "$KEY" "$AUTH_KEYS"; then
            printf '%s\n' "$KEY" >> "$AUTH_KEYS"
        fi
        ;;
    *)
        echo "That doesn't look like a supported public SSH key."
        exit 1
        ;;
esac

chmod 600 "$AUTH_KEYS"

echo
echo "Checking SSH configuration..."
/usr/sbin/sshd -t -p "$PORT"

echo "Starting SSH on port $PORT..."
exec /usr/sbin/sshd -D -e -p "$PORT"
