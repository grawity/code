from nullroute.core import Core
from nullroute.file import compare_files
import os
import subprocess

_has_gio = False
_has_trash = False
for d in os.environ["PATH"].split(":"):
    if not _has_gio and os.path.exists("%s/gio" % d):
        _has_gio = True
    if not _has_trash and os.path.exists("%s/trash" % d):
        _has_trash = True

def is_file_partial(fname):
    return fname.endswith((".crdownload", ".filepart", ".part"))

def _safe_path(path):
    if path.startswith("-"):
        return "./" + path
    return path

def gio_trash_file(path):
    if _has_gio:
        subprocess.run(["gio", "trash", _safe_path(path)], check=True)
    elif _has_trash:
        subprocess.run(["trash", "-q", _safe_path(path)], check=True)
    else:
        #os.unlink(old_path)
        Core.die("'gio' tool is missing")

def gio_rename_file(old_name, new_name):
    if _has_gio:
        subprocess.run(["gio", "move", _safe_path(old_name),
                                       _safe_path(new_name)],
                       check=True)
    else:
        #os.rename(old_path, new_path)
        Core.die("'gio' tool is missing")

class RenameJob():
    fmt_found = "\033[38;5;10m%s\033[m"
    fmt_notfound = "\033[38;5;9m%s\033[m"
    fmt_same = "\033[38;5;2m%s\033[m"
    fmt_foreign = "\033[38;5;11m%s\033[m"

    def __init__(self, old_path, dry_run=False):
        self.old_path = old_path
        self.dry_run = dry_run

    def begin(self):
        print(self.old_path, end=" ", flush=True)

    def end_fail(self, e):
        print(self.fmt_notfound % "failed")
        Core.err(str(e))

    def end_foreign(self):
        print(self.fmt_foreign % "not recognized")

    def end_notfound(self):
        print("=>", self.fmt_notfound % "[not found]")

    def end_rename(self, new_filename):
        if "/" in new_filename:
            raise ValueError("end_rename() expects only basename, not full path")

        old_path = self.old_path
        new_path = os.path.join(os.path.dirname(old_path), new_filename)
        old_filename = os.path.basename(old_path)

        if old_filename == new_filename:
            print("=>", self.fmt_same % "[no change]")
        elif compare_files(old_path, new_path):
            print("=>", self.fmt_same % new_filename, "[same]")
            if not self.dry_run:
                gio_trash_file(old_path)
        elif os.path.exists(new_path) and os.stat(new_path).st_size == 0:
            print("=>", self.fmt_found % new_filename)
            Core.notice("overwriting 0-byte file %r", new_filename)
            if not self.dry_run:
                gio_trash_file(new_path)
                gio_rename_file(old_path, new_path)
        elif os.path.exists(new_path):
            print("=>", self.fmt_notfound % new_filename, "[diff]")
            Core.err("refusing to overwrite existing file %r", new_filename)
        else:
            print("=>", self.fmt_found % new_filename)
            if not self.dry_run:
                gio_rename_file(old_path, new_path)
