@dataclass
class Context:
    symbols: Dict[str, Tuple[SExpr, Union[Token, None]]]
    functions: Dict[str, Tuple[Token, List[str], List[Stmt], 'Context']]
    def clone(self) -> 'Context':
        return Context(deepcopy(self.symbols), deepcopy(self.functions))

meta_transformations: Dict[str, List[Tuple[SExpr, SExpr]]] = {}
transformations: Dict[str, List[Tuple[SExpr, SExpr, Token]]] = {}
ctx_glbl = Context({}, {})
ctx_list: List[Context] = []    

def get_context() -> Context:
    if ctx_list:
        return ctx_list[-1]
    return ctx_glbl

def get_symbol(name: str) -> Tuple[SExpr, Token | None] | None:
    if ctx_list and name in ctx_list[-1].symbols:
        return ctx_list[-1].symbols[name]
    if name in ctx_glbl.symbols:
        return ctx_glbl.symbols[name]
    return None

def set_symbol(name: str, value: Tuple[SExpr, Token | None]) -> None:
    if ctx_list and not name in ctx_glbl.symbols:
        ctx_list[-1].symbols[name] = value
        return None
    ctx_glbl.symbols[name] = value

def del_symbol(name: str) -> None:
    if ctx_list and name in ctx_list[-1].symbols:
        del ctx_list[-1].symbols[name]
        return None
    del ctx_glbl.symbols[name]

def get_function(name: str) -> Tuple[Token, List[str], List[Stmt], Context] | None:
    if ctx_list and name in ctx_list[-1].functions:
        return ctx_list[-1].functions[name]
    if name in ctx_glbl.functions:
        return ctx_glbl.functions[name]
    return None

def set_function(name: str, value: Tuple[Token, List[str], List[Stmt], Context]) -> None:
    if ctx_list and not name in ctx_glbl.functions:
        ctx_list[-1].functions[name] = value
        return
    ctx_glbl.functions[name] = value

def del_function(name: str) -> None:
    if ctx_list and name in ctx_list[-1].functions:
        del ctx_list[-1].functions[name]
        return
    del ctx_glbl.functions[name]

def interpret_expr(e: Expr, comptime: bool = False, tok: Token | None = None) -> SExpr:
    if isinstance(e, ExprSymbol):
        if not comptime:
            s = get_symbol(e.sym)
            if s:
                return s[0]
        return SExprSymbol(e.token, False, e.sym)
    if isinstance(e, ExprCall):
        if comptime:
            return expr_to_sexpr(e)
        if e.fun in transformations:
            t = [(a[0],a[1]) for a in transformations[e.fun]]
            return substitute_compatible(interpret_expr(e.arg), t, tok)
        f = get_function(e.fun)
        if f:
            ctx_list.append(f[3].clone())
            _args = e.arg
            if not isinstance(_args, ExprTuple):
                raise RuntimeError(f"Expr kind {type(_args)} doesn't supported by functions at {format_loc(tok) if tok else 'Somewhere'}")
            args = _args.el
            l = len(f[1])
            if len(args) != l:
                raise RuntimeError(f"Expected {l} arguments but got {len(args)} arguments at {format_loc(tok) if tok else 'Somewhere'}")
            for i in range(l):
                ctx_list[-1].symbols[f[1][i]] = interpret_expr(args[i], comptime, tok), args[i].token
            for p in f[2]:
                interpret_stmt(p)
            r = get_symbol("Result")
            ctx_list.pop()
            if r is None:
                return SExprSymbol(tok if tok is not None else NITOK, False, "NIL")
            return r[0]
        if e.fun in builtin_funcs:
            return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok))
        raise RuntimeError(f"Unknown transformation or builtin function `{e.fun}' at {format_loc(tok) if tok else 'Somewhere'}")
    if isinstance(e, ExprCTCall):
        if comptime:
            if e.fun in meta_transformations:
                t = meta_transformations[e.fun]
                return substitute_compatible(interpret_expr(e.arg), t, tok)
            if e.fun in builtin_funcs:
                return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok))
            raise RuntimeError(f"Unknown meta-transformation or builtin function `{e.fun}' at {format_loc(tok) if tok else 'Somewhere'}")
        raise RuntimeError(f"CT-Call is avaliable only at transformation definition at {format_loc(tok) if tok else 'Somewhere'}")
    if isinstance(e, ExprTuple):
        return SExprTuple(e.token, False, [interpret_expr(i) for i in e.el])
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

def interpret_sexpr(e: SExpr, comptime: bool = False, tok: Token | None = None) -> SExpr:
    if isinstance(e, SExprSymbol):
        return e
    if isinstance(e, SExprCall):
        if comptime:
            return e
        if e.fun in transformations:
            t = [(a[0],a[1]) for a in transformations[e.fun]]
            e = substitute_compatible(interpret_sexpr(e.arg), t, tok)
            return e
        f = get_function(e.fun)
        if f:
            ctx_list.append(f[3].clone())
            _args = e.arg
            if not isinstance(_args, SExprTuple):
                raise RuntimeError(f"SExpr kind {type(_args)} doesn't supported by functions at {format_loc(tok) if tok else 'Somewhere'}")
            args = _args.el
            l = len(f[1])
            if len(args) != l:
                raise RuntimeError(f"Expected {l} arguments but got {len(args)} arguments at {format_loc(tok) if tok else 'Somewhere'}")
            for i in range(l):
                ctx_list[-1].symbols[f[1][i]] = interpret_sexpr(args[i], comptime, tok), args[i].token
            for p in f[2]:
                interpret_stmt(p)
            r = get_symbol("Result")
            ctx_list.pop()
            if r is None:
                return SExprSymbol(tok if tok is not None else NITOK, False, "NIL")
            return r[0]
        if e.fun in builtin_funcs:
            return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok))
        raise RuntimeError(f"Unknown transformation or builtin function `{e.fun}' at {format_loc(tok) if tok else 'Somewhere'}")
    if isinstance(e, SExprTuple):
        return SExprTuple(e.token, False, [interpret_sexpr(i) for i in e.el])
    assert False, "Unreachable"

def interpret_expr_extra(e: Expr, comptime: bool = False, tok: Token | None = None) -> SExpr:
    s = interpret_expr(e, comptime, tok)
    while is_unresolved(s):
        s = interpret_sexpr(s, comptime, tok)
    return s

def interpret_sexpr_extra(e: SExpr, comptime: bool = False, tok: Token | None = None) -> SExpr:
    s: SExpr = interpret_sexpr(s, comptime, tok)
    while is_unresolved(s):
        s = interpret_sexpr(s, comptime, tok)
    return s


@dataclass
class BuiltinFunc_Args:
    e: ExprCall | SExprCall | ExprCTCall
    is_at_comptime: bool
    token: Token | None

# TBD: resolve function calls in bf_* statements.

def bf_iscomptime(args: BuiltinFunc_Args) -> SExpr:
    return SExprSymbol(args.e.token, False, "TRUE" if args.is_at_comptime else "FALSE")

def bf_length(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(args.e.token, False, str(len(args.e.arg.sym)))
    elif isinstance(args.e.arg, ExprTuple):
        return SExprSymbol(args.e.token, False, str(len(args.e.arg.el)))
    else:
        raise RuntimeError(f"Expected ExprSymbol/ExprTuple but got `{type(args.e.arg)}' at {format_loc(args.e.arg.token) if isinstance(args.e.arg, Expr) else 'Somewhere'}")

def bf_is_symbol(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(args.e.token, False, "TRUE")
    return SExprSymbol(args.e.token, False, "FALSE")

def bf_gi(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token)
    if not isinstance(arg, SExprTuple) or len(arg.el) != 2:
        raise RuntimeError(f"Expected ({{EL}} {{ID}}) but got `{stringify(arg)}' at {format_loc(arg.token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[0], SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg.el[0])}' at {format_loc(arg.el[0].token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[1], SExprSymbol):
        raise RuntimeError(f"Expected symbol but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not arg.el[1].sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token) if isinstance(arg, Expr) else 'Somewhere'}")
    return arg.el[0].el[int(arg.el[1].sym)]

def bf_si(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token)
    if not isinstance(arg, SExprTuple) or len(arg.el) != 3:
        raise RuntimeError(f"Expected ({{EL}} {{ID}} {{VL}}) but got `{stringify(arg)}' at {format_loc(arg.token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[0], SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg.el[0])}' at {format_loc(arg.el[0].token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[1], SExprSymbol):
        raise RuntimeError(f"Expected symbol but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not arg.el[1].sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg.el[1])}' at {format_loc(arg.el[1].token) if isinstance(arg, Expr) else 'Somewhere'}")
    i = int(arg.el[1].sym)
    return SExprTuple(arg.token, False, arg.el[0].el[:i]+[arg.el[2]]+arg.el[0].el[i+1:])

def bf_to_peano(args: BuiltinFunc_Args) -> SExpr:
    tok = args.token if args.token is not None else NITOK
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token)
    if not isinstance(arg, SExprSymbol) or not arg.sym.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg)}' at {format_loc(args.e.arg.token) if isinstance(arg, Expr) else 'Somewhere'}")
    a = SExprTuple(tok, False, [])
    b = a
    i = 0
    c = int(arg.sym)
    while i < c:
        b.el.append(SExprSymbol(tok, False, "s"))
        b.el.append(SExprTuple(tok, False, []) if i != c - 1 else SExprSymbol(tok, False, "0"))
        if isinstance(b.el[1], SExprTuple):
            b = b.el[1]
        i += 1
    return a

def bf_inclusion_level(args: BuiltinFunc_Args) -> SExpr:
    tok = args.token if args.token is not None else NITOK
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token)
    if not isinstance(arg, SExprTuple):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg)}' at {format_loc(args.e.arg.token) if isinstance(arg, Expr) else 'Somewhere'}")
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
    return SExprSymbol(tok, False, str(a))

def bf_let(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token) if isinstance(args.e.arg, Expr) else interpret_sexpr(args.e.arg, args.is_at_comptime, args.token)
    if not isinstance(arg, SExprTuple) or len(arg.el) != 2:
        raise RuntimeError(f"Expected ({{ID}} {{EL}}) but got `{stringify(arg)}' at {format_loc(arg.token) if isinstance(arg, Expr) else 'Somewhere'}")
    if not isinstance(arg.el[0], SExprSymbol):
        raise RuntimeError(f"Expected symbol but got `{stringify(arg.el[0])}' at {format_loc(arg.el[0].token) if isinstance(arg, Expr) else 'Somewhere'}")
    interpreter_let(arg.el[0].sym, arg.el[1], args.token)
    return arg.el[1]


builtin_funcs: Dict[str, Callable[[BuiltinFunc_Args], SExpr]] = {
    "_ISCOMPTIME": bf_iscomptime,
    "_LENGTH": bf_length,
    "_ISSYMBOL": bf_is_symbol,
    "_GI": bf_gi,
    "_SI": bf_si,
    "_TOPEANO": bf_to_peano,
    "_INCLVL": bf_inclusion_level,
    "_LET": bf_let
}

def expr_to_sexpr(e: Expr) -> SExpr:
    if isinstance(e, ExprSymbol):
        return SExprSymbol(e.token, False, e.sym)
    if isinstance(e, ExprCall):
        return SExprCall(e.token, False, e.fun, expr_to_sexpr(e.arg))
    if isinstance(e, ExprTuple):
        return SExprTuple(e.token, False, [expr_to_sexpr(i) for i in e.el])
    assert False, "Unreachable"

def interpreter_let(name: str, expr: SExpr, tok: Token | None) -> None:
    if name in transformations:
        raise RuntimeError(f"Failed to define symbol `{name}' at {format_loc(tok) if tok else 'Somewhere'}\nThis name is already taken by a transformation'")
    set_symbol(name, (expr, tok))

def interpret_stmt(inst: Stmt) -> None:
    if isinstance(inst, StmtLet):
        interpreter_let(inst.name, interpret_expr_extra(inst.expr, False, inst.expr.token), inst.token)
    elif isinstance(inst, StmtUnlink):
        if inst.name in transformations:
            del transformations[inst.name]
        elif get_symbol(inst.name):
            del_symbol(inst.name)
        elif get_function(inst.name):
            del_function(inst.name)
        else:
            raise RuntimeError(f"Failed to unlink `{inst.name}' at {format_loc(inst.token)}")
    elif isinstance(inst, StmtShow):
        print(stringify(interpret_expr_extra(inst.expr, False, inst.expr.token)))
    elif isinstance(inst, StmtPrint):
        print(inst.text)
    elif isinstance(inst, StmtDefFunc):
        set_function(inst.name, (inst.token, inst.arg, inst.stmt, get_context()))
    else:
        assert False, f"What is `{inst}'?!?!?!"

def interpret_program(prog: List[Stmt]) -> None:
    pc = 0
    lprog = len(prog)
    while pc < lprog:
        inst = prog[pc]
        interpret_stmt(inst)
        pc += 1

