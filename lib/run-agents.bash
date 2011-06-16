run-gpg-agent() {
	local active=false env="$HOME/.cache/gpg-agent.$HOSTNAME.env"

	if ! have gpg-agent; then
		return 1
	elif gpg-agent 2>/dev/null; then
		active=true
	else
		[ -f "$env" ] && . "$env"
	fi

	if $active || gpg-agent 2>/dev/null; then
		# mutt/gpgme requires the envvar
		if [ -z "$GPG_AGENT_INFO" ] && [ -S ~/.gnupg/S.gpg-agent ]; then
			export GPG_AGENT_INFO="$HOME/.gnupg/S.gpg-agent:0:1"
		fi
	else
		eval $(gpg-agent --daemon --use-standard-socket --write-env-file "$env")
	fi
}
