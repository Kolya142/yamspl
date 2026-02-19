def interpret_expr(e: Expr, comptime: bool = False, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    if isinstance(e, ExprSymbol):
        if not comptime and e.sym in symbols:
            return symbols[e.sym][0]
        return SExprSymbol(False, e.sym)
    if isinstance(e, ExprCall):
        if comptime:
            return expr_to_sexpr(e)
        if e.fun in transformations:
            t = [(a[0],a[1]) for a in transformations[e.fun]]
            return substitute_compatible(interpret_expr(e.arg), t, tok, scl)
        if e.fun in builtin_funcs:
            return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok, scl))
        raise RuntimeError(f"Unknown transformation or builtin function `{e.fun}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
    if isinstance(e, ExprCTCall):
        if comptime:
            if e.fun in meta_transformations:
                t = meta_transformations[e.fun]
                return substitute_compatible(interpret_expr(e.arg), t, tok, scl)
            if e.fun in builtin_funcs:
                return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok, scl))
            raise RuntimeError(f"Unknown meta-transformation or builtin function `{e.fun}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
        raise RuntimeError(f"CT-Call is avaliable only at transformation definition at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
    if isinstance(e, ExprTuple):
        return SExprTuple(False, [interpret_expr(i) for i in e.el])
    if isinstance(e, ExprQuote):
        return expr_to_sexpr(e.sentence)
    assert False, "Unreachable"

def is_unresolved(e: SExpr) -> bool:
    if isinstance(e, SExprSymbol):
        return False
    if isinstance(e, SExprCall):
        return True
    if isinstance(e, SExprTuple):
        return any(is_unresolved(i) for i in e.el)
    assert False, "Unreachable"

def interpret_sexpr(e: SExpr, comptime: bool = False, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    if isinstance(e, SExprSymbol):
        return e
    if isinstance(e, SExprCall):
        if comptime:
            return e
        if e.fun in transformations:
            t = [(a[0],a[1]) for a in transformations[e.fun]]
            e = substitute_compatible(interpret_sexpr(e.arg), t, tok, scl)
            return e
        if e.fun in builtin_funcs:
            return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok, scl))
        raise RuntimeError(f"Unknown transformation or builtin function `{e.fun}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
    if isinstance(e, SExprTuple):
        return SExprTuple(False, [interpret_sexpr(i) for i in e.el])
    assert False, "Unreachable"

def interpret_expr_extra(e: Expr, comptime: bool = False, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    s = interpret_expr(e, comptime, tok, scl)
    while is_unresolved(s):
        s = interpret_sexpr(s, comptime, tok, scl)
    return s

symbols: Dict[str, Tuple[SExpr, tuple]] = {}
meta_transformations: Dict[str, List[Tuple[SExpr, SExpr]]] = {}  # Transformations at compile-time.
transformations: Dict[str, List[Tuple[SExpr, SExpr, tuple]]] = {}

@dataclass
class BuiltinFunc_Args:
    e: ExprCall | SExprCall | ExprCTCall
    is_at_comptime: bool
    token: tuple | None
    scl: Sequence[str] | None

# TBD: resolve function calls in bf_* statements.

def bf_iscomptime(args: BuiltinFunc_Args) -> SExpr:
    return SExprSymbol(False, "TRUE" if args.is_at_comptime else "FALSE")

def bf_length(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(False, str(len(args.e.arg.sym)))
    elif isinstance(args.e.arg, ExprTuple):
        return SExprSymbol(False, str(len(args.e.arg.el)))
    else:
        raise RuntimeError(f"Expected ExprSymbol/ExprTuple but got `{type(args.e.arg)}' at {format_loc(args.e.arg.token, args.scl) if isinstance(args.e.arg, Expr) else 'Somewhere'}")

def bf_is_symbol(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(False, "TRUE")
    return SExprSymbol(False, "FALSE")

def bf_gi(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if not isinstance(arg, SExprTuple) or len(arg.el) != 2:
        raise RuntimeError(f"Expected ({{EL}} {{ID}}) but got `{stringify(arg)}' at {format_loc(arg.token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[0], SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg.el[0])}' at {format_loc(arg.el[0].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[1], SExprSymbol):
        raise RuntimeError(f"Expected symbol but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not arg.el[1].sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    return arg.el[0].el[int(arg.el[1].sym)]

def bf_si(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if not isinstance(arg, SExprTuple) or len(arg.el) != 3:
        raise RuntimeError(f"Expected ({{EL}} {{ID}} {{VL}}) but got `{stringify(arg)}' at {format_loc(arg.token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[0], SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg.el[0])}' at {format_loc(arg.el[0].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[1], SExprSymbol):
        raise RuntimeError(f"Expected symbol but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    if not arg.el[1].sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    i = int(arg.el[1].sym)
    return SExprTuple(False, arg.el[0].el[:i]+[arg.el[2]]+arg.el[0].el[i+1:])

def bf_to_peano(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if not isinstance(arg, SExprSymbol) or not arg.sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    a = SExprTuple(False, [])
    b = a
    i = 0
    c = int(arg.sym)
    while i < c:
        b.el.append(SExprSymbol(False, "s"))
        b.el.append(SExprTuple(False, []) if i != c - 1 else SExprSymbol(False, "0"))
        if isinstance(b.el[1], SExprTuple):
            b = b.el[1]
        i += 1
    return a

def bf_inclusion_level(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if not isinstance(arg, SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl) if isinstance(arg, Expr) else 'Somewhere'}")
    a = 1
    r = True
    while r:
        r = False
        for i in arg.el:
            if isinstance(i, SExprTuple):
                r = True
                arg = i
                a += 1
                break
    return SExprSymbol(False, str(a))

builtin_funcs: Dict[str, Callable[[BuiltinFunc_Args], SExpr]] = {
    "_ISCOMPTIME": bf_iscomptime,
    "_LENGTH": bf_length,
    "_ISSYMBOL": bf_is_symbol,
    "_GI": bf_gi,
    "_SI": bf_si,
    "_TOPEANO": bf_to_peano,
    "_INCLVL": bf_inclusion_level
}

# Maybe add I/O operations

def expr_to_sexpr(e: Expr) -> SExpr:
    if isinstance(e, ExprSymbol):
        return SExprSymbol(False, e.sym)
    if isinstance(e, ExprCall):
        return SExprCall(False, e.fun, expr_to_sexpr(e.arg))
    if isinstance(e, ExprTuple):
        return SExprTuple(False, [expr_to_sexpr(i) for i in e.el])
    assert False, "Unreachable"

def interpret_program(prog: List[Stmt], scl: Sequence[str]) -> None:
    global symbols, transformations
    symbols = {}
    transformations = {}

    pc = 0
    lprog = len(prog)
    while pc < lprog:
        inst = prog[pc]
        if isinstance(inst, StmtLet):
            if inst.name in transformations:
                raise RuntimeError(f"Failed to define symbol `{inst.name}' at {format_loc(inst.token, scl)}\nThis name is already taken by a transformation at {format_loc(transformations[inst.name][2], scl)}")
            symbols[inst.name] = interpret_expr_extra(inst.expr, False, inst.expr.token, scl), inst.token
            pc += 1
        elif isinstance(inst, StmtDefForm):
            if inst.name in symbols:
                raise RuntimeError(f"Failed to define transformation `{inst.name}' at {format_loc(inst.token, scl)}\nThis name is already taken by a symbol at {format_loc(symbols[inst.name][1], scl)}")
            if inst.name not in transformations:
                transformations[inst.name] = []
            transformations[inst.name].append((inst.a, inst.b, inst.token))
            pc += 1
        elif isinstance(inst, StmtUnlink):
            if inst.name in transformations:
                del transformations[inst.name]
            elif inst.name in symbols:
                del symbols[inst.name]
            else:
                raise RuntimeError(f"Failed to unlink `{inst.name}' because  at {format_loc(inst.token, scl)}")
            pc += 1
        elif isinstance(inst, StmtShow):
            print(stringify(interpret_expr_extra(inst.expr, False, inst.expr.token, scl)))
            pc += 1
        elif isinstance(inst, StmtPrint):
            print(inst.text)
            pc += 1
        else:
            assert False, f"What is `{inst}'?!?!?!"

