def filter_filename(name):
    xlat = [
        (' ', '_'),
        ('　', '_'),
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

def uniq(items):
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            yield item
