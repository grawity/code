from .file import *
from .string import *

def chunk(vec, size):
    for i in range(0, len(vec), size):
        yield vec[i:i+size]

def flatten_dict(d):
    for k, v in d.items():
        yield k
        yield v

def uniq(items):
    seen = set()
    for item in items:
        if item not in seen:
            seen.add(item)
            yield item

def print_dependency_tree(tree, root, *, indent=0, ctx=None):
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
        print(" "*indent + "".join(branches) + child)
        if child in tree:
            branches[depth] = ("│" if more else " ") + " "
            ctx = depth + 1, branches.copy(), seen.copy()
            print_dependency_tree(tree, child, indent=indent, ctx=ctx)
