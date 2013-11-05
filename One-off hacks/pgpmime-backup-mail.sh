#!/usr/bin/bash

subject="backup"
recipient="grawity@gmail.com"
sender=$recipient
filename="bleh.tar.bz2"
pgpmime=0

if (( pgpmime )); then
	subject+=" [testing with pgpmime]"
else
	subject+=" [testing without pgpmime]"
fi

sendmail() { msmtp "$@"; } # temporary hax

:<<'#'

PGP/MIME structure:
	http://tools.ietf.org/html/rfc3156#section-4
	[multipart/encrypted]
		[application/pgp-encrypted]
			Version: 1
		[application/octet-stream]
			<encrypted+armored [multipart/mixed]>
				[text/plain]
					{body}
				[application/octet-stream <encoding base64, disposition attachment>]
					{attachment}

Inline structure:
	[multipart/mixed]
		[text/plain]
			<encrypted+armored {body}>
		[application/octet-stream <encoding base64, disposition attachment>]
			<encrypted {attachment}>

#

gpg_encrypt() {
	gpg --batch --recipient "$recipient" "$@" --sign --encrypt
}

m_nextpart() { echo ""; echo "--$boundary"; }

m_finish() { echo ""; echo "--$boundary--"; }

f_attach() {
	local filename=${1:-encrypted.txt}
	echo "Content-Type: application/octet-stream"
	echo "Content-Transfer-Encoding: base64"
	echo "Content-Disposition: attachment; filename=\"$filename\""
	echo ""
	base64
}

f_pgpmime() {
	local boundary=$(uuidgen)
	echo "Content-Type: multipart/encrypted; boundary=$boundary;"
	echo "	protocol=\"application/pgp-encrypted\""
	m_nextpart
		echo "Content-Type: application/pgp-encrypted"
		echo ""
		echo "Version: 1"
	m_nextpart
		echo "Content-Type: application/octet-stream"
		echo ""
		gpg_encrypt --armor
	m_finish
}

do_body() {
	echo "Here's your attachment."
}

do_archive() {
	tar c ~/tmp/bleh/Makefile
}

do_multipart() {
	local boundary=$(uuidgen)
	echo "Content-Type: multipart/mixed; boundary=$boundary"
	m_nextpart
		echo "Content-Type: text/plain; charset=utf-8"
		echo ""
		if (( pgpmime )); then
			do_body
		else
			do_body | gpg_encrypt --armor
		fi
	m_nextpart
		if (( pgpmime )); then
			do_archive | f_attach "$filename"
		else
			do_archive | gpg_encrypt | f_attach "$filename.pgp"
		fi
	m_finish
}

do_message() {
	echo "From: $sender"
	echo "To: $recipient"
	echo "Subject: $subject"
	if (( pgpmime )); then
		do_multipart | f_pgpmime
	else
		do_multipart
	fi
}

do_message | sendmail -i -t

# vim: ts=4 sw=4
