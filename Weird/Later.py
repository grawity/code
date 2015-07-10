def argify(a, kw):
    return ", ".join(["%r" % v for v in a] + ["%s=%r" % (k, v) for k, v in kw.items()])

class Later(object):
    def __init__(self, func=None, text=None):
        self.func = func or (lambda x: x)
        self.text = text or "x"

    def eval(self, value, *rest):
        if rest:
            return self.func(value).eval(*rest)
        else:
            return self.func(value)

        '''
        while rest:
            self = self.func(value)
            value, *rest = rest
        return self.func(value)
        '''

    def __repr__(self):
        return self.text

    def __call__(self, *a, **kw):
        return Later(lambda x: self.eval(x)(*a, **kw),
                     #"%r(…)" % self)
                     "%r(%s)" % (self, argify(a, kw)))

    def __getattr__(self, attr):
        return Later(lambda x: getattr(self.eval(x), attr),
                     "%r.%s" % (self, attr))

    def __getitem__(self, key):
        return Later(lambda x: self.eval(x)[key],
                     "%r[%r]" % (self, key))

    def __bool__(self):
        return None

    # unary

    def __neg__(self):
        return Later(lambda x: -self.eval(x),
                     "-%r" % self)

    def __pos__(self):
        return Later(lambda x: +self.eval(x),
                     "+%r" % self)

    def __abs__(self):
        return Later(lambda x: abs(self.eval(x)),
                     "abs(%r)" % self)

    # comparison

    def __eq__(self, other):
        return Later(lambda x: self.eval(x) == other,
                     "(%r == %r)" % (self, other))

    def __ne__(self, other):
        return Later(lambda x: self.eval(x) != other,
                     "(%r != %r)" % (self, other))

    def __lt__(self, other):
        return Later(lambda x: self.eval(x) < other,
                     "(%r < %r)" % (self, other))

    def __gt__(self, other):
        return Later(lambda x: self.eval(x) > other,
                     "(%r > %r)" % (self, other))

    def __le__(self, other):
        return Later(lambda x: self.eval(x) <= other,
                     "(%r <= %r)" % (self, other))

    def __ge__(self, other):
        return Later(lambda x: self.eval(x) >= other,
                     "(%r >= %r)" % (self, other))

    # numeric

    def __add__(self, other):
        return Later(lambda x: self.eval(x) + other,
                     "(%r + %r)" % (self, other))

    def __sub__(self, other):
        return Later(lambda x: self.eval(x) - other,
                     "(%r - %r)" % (self, other))

    def __mul__(self, other):
        return Later(lambda x: self.eval(x) * other,
                     "(%r * %r)" % (self, other))

    def __mod__(self, other):
        return Later(lambda x: self.eval(x) % other,
                     "(%r %% %r)" % (self, other))

    def __divmod__(self, other):
        return Later(lambda x: divmod(self.eval(x), other),
                     "divmod(%r, %r)" % (self, other))

    def __floordiv__(self, other):
        return Later(lambda x: self.eval(x) // other,
                     "(%r // %r)" % (self, other))

    def __truediv__(self, other):
        return Later(lambda x: self.eval(x) / other,
                     "(%r / %r)" % (self, other))

    def __pow__(self, other):
        return Later(lambda x: self.eval(x) ** other,
                     "(%r ** %r)" % (self, other))

    def __lshift__(self, other):
        return Later(lambda x: self.eval(x) << other,
                     "(%r << %r)" % (self, other))

    def __rshift__(self, other):
        return Later(lambda x: self.eval(x) >> other,
                     "(%r >> %r)" % (self, other))

    def __and__(self, other):
        return Later(lambda x: self.eval(x) & other,
                     "(%r & %r)" % (self, other))

    def __or__(self, other):
        return Later(lambda x: self.eval(x) | other,
                     "(%r | %r)" % (self, other))

    def __xor__(self, other):
        return Later(lambda x: self.eval(x) ^ other,
                     "(%r ^ %r)" % (self, other))

    # reverse numeric

    def __radd__(self, other):
        return Later(lambda x: other + self.eval(x),
                     "(%r + %r)" % (other, self))

    def __rsub__(self, other):
        return Later(lambda x: other - self.eval(x),
                     "(%r - %r)" % (other, self))

    def __rmul__(self, other):
        return Later(lambda x: other * self.eval(x),
                     "(%r * %r)" % (other, self))

    def __rmod__(self, other):
        return Later(lambda x: other % self.eval(x),
                     "(%r %% %r)" % (other, self))

    def __rdivmod__(self, other):
        return Later(lambda x: divmod(other, self.eval(x)),
                     "divmod(%r, %r)" % (other, self))

    def __rfloordiv__(self, other):
        return Later(lambda x: other // self.eval(x),
                     "(%r // %r)" % (other, self))

    def __rtruediv__(self, other):
        return Later(lambda x: other / self.eval(x),
                     "(%r / %r)" % (other, self))

    def __rpow__(self, other):
        return Later(lambda x: other ** self.eval(x),
                     "(%r ** %r)" % (other, self))

    def __rlshift__(self, other):
        return Later(lambda x: other << self.eval(x),
                     "(%r << %r)" % (other, self))

    def __rrshift__(self, other):
        return Later(lambda x: other >> self.eval(x),
                     "(%r >> %r)" % (other, self))

    def __rand__(self, other):
        return Later(lambda x: other & self.eval(x),
                     "(%r & %r)" % (other, self))

    def __ror__(self, other):
        return Later(lambda x: other | self.eval(x),
                     "(%r | %r)" % (other, self))

    def __rxor__(self, other):
        return Later(lambda x: other ^ self.eval(x),
                     "(%r ^ %r)" % (other, self))

x = Later()

f2c = (x - 32) * 5 / 9
c2f = (x * 9 / 5) + 32
