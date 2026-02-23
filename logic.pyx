# TODO: document code!!!
def replace(expr: SExpr, a: Any, b: Any) -> SExpr:
    if isinstance(expr, SExprSymbol) and expr.sym == a:
        return b
    if expr.wr:  # If `expr' is wrapped, it shouldn't be replaced.
        return expr
    if isinstance(expr, SExprSymbol):  # if the a parameter `expr' is a symbol that not equal to a parameter `a', it shouldn't be replaced.
        return expr
    if isinstance(expr, SExprCall):
        return SExprCall(expr.token, False, expr.fun, replace(expr.arg, a, b))
    if isinstance(expr, SExprTuple):
        return SExprTuple(expr.token, False, [replace(i, a, b) for i in expr.el])
    assert False, "unreachable"

def walk(expr: SExpr, form: SExpr, m: Dict[str, SExpr], tok: Token | None = None) -> Dict[str, SExpr]:
    if isinstance(form, SExprSymbol) and form.sym and form.sym[0].isupper():
        if form.sym in m and m[form.sym] != expr:
            raise RuntimeError(f"The expression `{stringify(expr)}' called `{form.sym}' is incompatible with the expression `{stringify(m[form.sym])}' with the same name at {format_loc(tok) if tok else 'Somewhere'}")
        m[form.sym] = expr
        return m
    if isinstance(form, SExprTuple) and isinstance(expr, SExprTuple):
        if len(form.el) != len(expr.el):
            raise RuntimeError(f"The expression `{stringify(expr)}' is incompatible with the format `{stringify(form)}' at {format_loc(tok) if tok else 'Somewhere'}")
        for i in range(len(expr.el)):
            m = walk(expr.el[i], form.el[i], m, tok)
        return m
    if not is_compatible(expr, form):
        raise RuntimeError(f"The expression `{stringify(expr)}' is incompatible with the format `{stringify(form)}' at {format_loc(tok) if tok else 'Somewhere'}")
    return m

def is_compatible(expr: SExpr, form: SExpr) -> bool:
    if isinstance(form, SExprSymbol) and form.sym and form.sym[0].isupper():
        return True
    if isinstance(form, SExprTuple) and isinstance(expr, SExprTuple):
        if len(form.el) != len(expr.el):
            return False
        for i in range(len(expr.el)):
            if not is_compatible(expr.el[i], form.el[i]):
                return False
        return True
    elif isinstance(form, SExprCall) and isinstance(expr, SExprCall):
        return form.fun == expr.fun and is_compatible(form.arg, expr.arg)
    elif isinstance(form, SExprSymbol) and isinstance(expr, SExprSymbol):
        return form.sym == expr.sym
    return False

def wrap(expr: SExpr) -> SExpr:
    if expr.wr:
        return expr
    if isinstance(expr, SExprSymbol):
        return SExprSymbol(expr.token, True, expr.sym)
    if isinstance(expr, SExprCall):
        return SExprCall(expr.token, True, expr.fun, expr.arg)
    if isinstance(expr, SExprTuple):
        return SExprTuple(expr.token, True, expr.el)
    assert False, "unreachable"

def unwrap(expr: SExpr) -> SExpr:
    if isinstance(expr, SExprSymbol):
        return SExprSymbol(expr.token, False, expr.sym)
    if isinstance(expr, SExprCall):
        return SExprCall(expr.token, False, expr.fun, unwrap(expr.arg))
    if isinstance(expr, SExprTuple):
        return SExprTuple(expr.token, False, [unwrap(i) for i in expr.el])
    assert False, "unreachable"

def substitute(expr: SExpr, sform: SExpr, rform: SExpr, tok: Token | None = None) -> SExpr:
    m = walk(expr, sform, {}, tok)
    for r in m:
        rform = replace(rform, r, wrap(m[r]))
    rform = unwrap(rform)
    return rform

def substitute_compatible(expr: SExpr, forms: List[Tuple[SExpr, SExpr]], tok: Token | None = None) -> SExpr:
    for s, r in forms:
        if is_compatible(expr, s):
            return substitute(expr, s, r, tok)
    raise RuntimeError(f"The expression `{stringify(expr)}' is incompatible with any format in this list: {';'.join(stringify(i[0]) for i in forms)} at {format_loc(tok) if tok else 'Somewhere'}")
