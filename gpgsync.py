import subprocess
from operator import attrgetter

class GpgKeyring(dict):
	def __init__(self):
		self.last_key = None
	
	def add_key(self, key_id):
		key = GpgKey(key_id)
		self[key.id] = key
		self.last_key = key
	
	@classmethod
	def load(self, *gpgoptions):
		keyring = self()
		gpgargs = ["gpg", "--with-colons"] #, "--fast-list-mode"]
		gpgargs += gpgoptions
		gpgargs += ["--list-sigs"]
		proc = subprocess.Popen(gpgargs,
					stdout=subprocess.PIPE)

		for line in proc.stdout:
			line = line.strip().split(":")
			if line[0] == "pub":
				id = line[4]
				keyring.add_key(id)
			elif line[0] == "uid":
				keyring.last_key.add_uid()
			elif line[0] == "sig":
				signer_id = line[4]
				timestamp = int(line[5])
				keyring.last_key.last_uid.add_sig(signer_id, timestamp)
		
		return keyring

class GpgKey(object):
	def __init__(self, key_id):
		self.id = key_id
		self.uids = []
		self.last_uid = None
	
	def __repr__(self):
		return "Key(id=%r, uids=%r)" % (self.id, self.uids)

	def add_uid(self, name=None):
		uid = GpgUid(name)
		self.uids.append(uid)
		self.last_uid = uid
	
	def num_uids(self):
		return len(self.uids)
	
	def num_sigs(self):
		return sum(len(uid.sigs) for uid in self.uids)

class GpgUid(object):
	def __init__(self, name):
		self.name = name
		self.sigs = set()
	
	def __repr__(self):
		return "Uid(name=%r, sigs=%r)" % (self.name, self.sigs)

	def add_sig(self, signer_id, timestamp):
		sig = signer_id, timestamp
		self.sigs.add(sig)
	
def keyring_diff(local, remote):
	keys_local_only = []
	keys_local_moreuids = []
	keys_local_moresigs = []
	keys_remote_only = []
	keys_remote_moreuids = []
	keys_remote_moresigs = []
	
	# TODO: sync key removal
	
	for id in local:
		if id not in remote:
			keys_local_only.append(id)
		elif local[id].num_uids() > remote[id].num_uids():
			keys_local_moreuids.append(id)
		elif local[id].num_sigs() > remote[id].num_sigs():
			keys_local_moresigs.append(id)

	for id in remote:
		if id not in local:
			keys_remote_only.append(id)
		elif remote[id].num_uids() > local[id].num_uids():
			keys_remote_moreuids.append(id)
		elif remote[id].num_sigs() > local[id].num_sigs():
			keys_remote_moresigs.append(id)
	
	keys_export = set(keys_local_only + keys_local_moreuids + keys_local_moresigs)
	keys_import = set(keys_remote_only + keys_local_moreuids + keys_remote_moresigs)
	
	return keys_export, keys_import

def gpg_transport(src_args, dst_args, key_ids):
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

export_args = ["gpg",
		"--export-options",
			"export-local-sigs,export-sensitive-revkeys"]
import_args = ["gpg",
		"-v",
		"--import-options",
			"import-local-sigs",
		"--allow-non-selfsigned-uid"]

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
