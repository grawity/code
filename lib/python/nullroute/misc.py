def chunk(vec, size):
    for i in range(0, len(vec), size):
        yield vec[i:i+size]

def zip_prefix(prefix, items):
    """
    >>> zip_prefix("foo", ["one", "two", "three"])
    ['foo', 'one', 'foo', 'two', 'foo', 'three']
    """
    return (y
            for x in items
            for y in [prefix, x])

def flatten_dict(d):
    return (x
            for kv in d.items()
            for x in kv)

def uniq(items):
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            yield item

def print_dependency_tree(tree, root, *, indent=0, sep="", ctx=None):
    """
    >>> tree = {"a": {"b", "c"},
    >>>         "b": {"d"},
    >>>         "c": {"b", "d"}}
    >>> print_dependency_tree(tree, "a")
    a
    ├─b
    │ └─d
    └─c
      ├─b
      │ └─d
      └─d
    """
    depth, branches, seen = ctx or (0, [], set())
    if depth == 0:
        print(" "*indent + root)
    if root not in tree:
        return
    branches += [None]
    seen |= {root}
    children = set(tree[root]) - seen
    more = len(children)
    for child in sorted(children):
        more -= 1
        branches[depth] = ("├" if more else "└") + "─"
        if child in seen:
            continue
        print(" "*indent + "".join([b+sep for b in branches]) + child)
        if child in tree:
            branches[depth] = ("│" if more else " ") + " "
            ctx = depth + 1, branches.copy(), seen.copy()
            print_dependency_tree(tree, child, indent=indent, sep=sep, ctx=ctx)

def summarize_ranges(ints):
    lo = hi = None
    for x in ints:
        if lo is None:
            lo = hi = x
        elif x == hi + 1:
            hi = x
        else:
            yield (lo, hi)
            lo = hi = x
    if lo is not None:
        yield (lo, hi)

def stringify_ranges(ranges, sep="-"):
    for a, b in ranges:
        if a == b:
            yield "%s" % a
        else:
            yield "%s%s%s" % (a, sep, b)
