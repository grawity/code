import sys

def get():
    if sys.platform == "win32":
        import win32clipboard as clip
        clip.OpenClipboard()
        # TODO: what type does this return?
        data = clip.GetClipboardData(clip.CF_UNICODETEXT)
        #print("clipboard.get =", repr(data))
        clip.CloseClipboard()
        return data
    else:
        raise RuntimeError("Unsupported platform")

def put(data):
    if sys.platform == "win32":
        import win32clipboard as clip
        clip.OpenClipboard()
        clip.EmptyClipboard()
        clip.SetClipboardText(data, clip.CF_UNICODETEXT)
        clip.CloseClipboard()
    elif sys.platform.startswith("linux"):
        import subprocess
        proc = subprocess.Popen(("xsel", "-i", "-b", "-l", "/dev/null"),
                                stdin=subprocess.PIPE)
        proc.stdin.write(data.encode("utf-8"))
        proc.stdin.close()
        proc.wait()
    else:
        raise RuntimeError("Unsupported platform")
