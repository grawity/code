from nullroute.core import Core
from nullroute.file import compare_files
import os

def is_file_partial(fname):
    return fname.endswith((".crdownload", ".filepart", ".part"))

def gio_trash_file(path):
    import subprocess
    subprocess.run(["gio", "trash", path]).check_returncode()

def gio_rename_file(old_name, new_name):
    import subprocess
    subprocess.run(["gio", "move", old_name, new_name]).check_returncode()

class RenameJob():
    fmt_found = "\033[38;5;10m%s\033[m"
    fmt_notfound = "\033[38;5;9m%s\033[m"
    fmt_same = "\033[38;5;2m%s\033[m"

    def __init__(self, old_path, dry_run=False):
        self.old_path = old_path
        self.dry_run = dry_run

    def begin(self):
        print(self.old_path, end=" ", flush=True)

    def end_fail(self, e):
        print(self.fmt_notfound % "failed")
        Core.err(str(e))

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
                #os.unlink(old_path)
                gio_trash_file(old_path)
        elif os.path.exists(new_path):
            print("=>", self.fmt_notfound % new_filename, "[diff]")
            Core.err("refusing to overwrite existing file %r", new_filename)
        else:
            print("=>", self.fmt_found % new_filename)
            if not self.dry_run:
                #os.rename(old_path, new_path)
                gio_rename_file(old_path, new_path)
