def filter_filename(name):
    xlat = [
        (' ', '_'),
        ('"', '_'),
        ('*', '_'),
        ('/', '⁄'),
        (':', '_'),
        ('<', '_'),
        ('>', '_'),
        ('?', '_'),
    ]
    name = name.strip()
    for k, v in xlat:
        name = name.replace(k, v)
    if name.startswith("."):
        name = "·" + name[1:]
    return name
