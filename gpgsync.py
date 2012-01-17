import subprocess
from operator import attrgetter

class GpgKeyring(dict):
	def __init__(self):
		self.gpgoptions = None
		self.last_key = None

	def add_key(self, key_id):
		key = GpgKey(key_id)
		self[key.id] = key
		self.last_key = key

	@classmethod
	def load(self, *gpgoptions):
		keyring = self()
		keyring.gpgoptions = gpgoptions

		gpgargs = ["gpg", "--with-colons", "--fast-list-mode"]
		gpgargs += gpgoptions
		gpgargs += ["--list-sigs"]
		proc = subprocess.Popen(gpgargs,
					stdout=subprocess.PIPE)

		for line in proc.stdout:
			line = line.strip().split(":")
			if line[0] == "pub":
				id = line[4]
				keyring.add_key(id)
			elif line[0] == "sig":
				signer_id = line[4]
				timestamp = int(line[5])
				keyring.last_key.add_sig(signer_id, timestamp)

		return keyring

class GpgKey(object):
	def __init__(self, key_id):
		self.id = key_id
		self.sigs = set()

	def __repr__(self):
		return "Key(id=%r, sigs=%r)" % (self.id, self.sigs)

	def add_sig(self, signer_id, timestamp):
		sig = signer_id, timestamp
		self.sigs.add(sig)

def keyring_diff(local, remote):
	to_remote = set()
	to_local = set()

	# TODO: sync key removal

	all_ids = set(local.keys()) | set(remote.keys())

	for id in all_ids:
		if id in local and id not in remote:
			to_remote.add(id)
		elif id in remote and id not in local:
			to_local.add(id)
		elif local[id].sigs != remote[id].sigs:
			to_remote.add(id)
			to_local.add(id)

	return to_remote, to_local

def gpg_transport(src_args, dst_args, key_ids):
	export_args = ["gpg",
			"--export-options",
				"export-local-sigs,export-sensitive-revkeys"]
	import_args = ["gpg",
			"-v",
			"--import-options",
				"import-local-sigs",
			"--allow-non-selfsigned-uid"]

	export_cmd = export_args + src_args + ["--export"] + ["0x%s" % id for id in key_ids]
	import_cmd = import_args + dst_args + ["--import"]

	exporter = subprocess.Popen(export_cmd, stdout=subprocess.PIPE)
	importer = subprocess.Popen(import_cmd, stdin=exporter.stdout)

	r = importer.wait()
	if r == 0:
		exporter.wait()
	else:
		exporter.terminate()

local_args = []
remote_args = ["--home", "testgpg"]

local = GpgKeyring.load(*local_args)
print "Local: %d keys" % len(local)

remote = GpgKeyring.load(*remote_args)
print "Remote: %d keys" % len(remote)

to_remote, to_local = keyring_diff(local, remote)

if to_remote:
	print "Exporting %d keys" % len(to_remote)
	gpg_transport(local_args, remote_args, to_remote)

if to_local:
	print "Importing %d keys" % len(to_local)
	gpg_transport(remote_args, local_args, to_local)
