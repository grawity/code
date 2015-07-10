# Licensed in the GPLv3
# Writtem in gedit and nano
# Who should receive the mail? 

sender="thermi_server@thermi.thermi"
#recipient="thermi@thermi.thermi"
recipient="grawity@gmail.com"

do_archive() {
	tar c ~/tmp/bleh
}

sendmail() { msmtp "$@"; } # temporary hax

filename="bleh.tar.bz2"

{
	boundary=$(uuidgen)
	echo "From: $sender"
	echo "To: $recipient"
	echo "Subject: webpidginz backup"
	echo "Content-Type: multipart/related; boundary=$boundary"
	echo ""
	echo "Multipart message follows."
	echo "--$boundary"
	echo "Content-Type: text/plain; charset=utf-8"
	echo "Content-Transfer-Encoding: quoted-printable"
	echo ""
	echo "Here is your backup." | gpg -sear $recipient
	echo "--$boundary"
	echo "Content-Type: application/octet-stream"
	echo "Content-Transfer-Encoding: base64"
	echo "Content-Disposition: attachment; filename=\"$filename.pgp\""
	echo ""
	do_archive | gpg -ser $recipient | base64
	echo "--$boundary--"
} | sendmail -i -t

# vim: ts=2
