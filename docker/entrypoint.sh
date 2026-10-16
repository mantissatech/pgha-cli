#!/bin/sh
# Entrypoint of the pgha container image.
#
# Makes sure an SSH key is in $HOME/.ssh (the /data volume), then runs
# pgha with the given arguments. The key comes from, in order:
#   1. an existing $HOME/.ssh/id_ed25519
#   2. PGHA_SSH_PRIVATE_KEY (the key text) or PGHA_SSH_PRIVATE_KEY_FILE
#   3. a new key, made on the first start
# New clusters get the matching public key. Clusters made with another
# key need that key here.
set -eu

ssh_dir="${HOME:-/data}/.ssh"
key="$ssh_dir/id_ed25519"

if [ -n "${PGHA_SSH_PRIVATE_KEY_FILE:-}" ] && [ -z "${PGHA_SSH_PRIVATE_KEY:-}" ]; then
	PGHA_SSH_PRIVATE_KEY="$(cat "$PGHA_SSH_PRIVATE_KEY_FILE")"
fi

if [ ! -w "${HOME:-/data}" ]; then
	echo "pgha: ${HOME:-/data} is not writable by uid $(id -u)." >&2
	echo "pgha: for a host folder, run: chown -R 10001:10001 <folder>" >&2
	exit 1
fi

umask 077
mkdir -p "$ssh_dir"

if [ ! -f "$key" ]; then
	if [ -n "${PGHA_SSH_PRIVATE_KEY:-}" ]; then
		printf '%s\n' "$PGHA_SSH_PRIVATE_KEY" >"$key"
	else
		ssh-keygen -q -t ed25519 -N '' -C "pgha@container" -f "$key"
		echo "pgha: made a new SSH key in $key" >&2
	fi
fi
if [ ! -f "$key.pub" ]; then
	ssh-keygen -y -f "$key" >"$key.pub"
fi

exec pgha "$@"
