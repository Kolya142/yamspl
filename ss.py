from dataclasses import dataclass
from typing import *
from enum import Enum

class TokenKind(Enum):
    SYMBOL  = 0
    LPAREN  = 1
    RPAREN  = 2
    LBRACK  = 3
    RBRACK  = 4
    ARROW   = 5
    COLON   = 6
    GRAVE   = 7

# TO NOT BE CONFUSED, `SExpr' is a purely logic type, when `Expr' is a purely parsing type.


@dataclass
class SExpr:
    wr: bool

@dataclass
class SExprSymbol(SExpr):
    sym: str

@dataclass
class SExprCall(SExpr):
    fun: str
    arg: SExpr

@dataclass
class SExprTuple(SExpr):
    el: List[SExpr]

def replace(expr: SExpr, a: Any, b: Any) -> SExpr:
    if expr == a:
        return b
    if expr.wr:  # If `expr' is wrapped, it shouldn't be replaced.
        return expr
    if isinstance(expr, SExprSymbol):  # if the a parameter `expr' is a symbol that not equal to a parameter `a', it shouldn't be replaced.
        return expr
    if isinstance(expr, SExprCall):
        return SExprCall(False, expr.fun, replace(expr.arg, a, b))
    if isinstance(expr, SExprTuple):
        return SExprTuple(False, [replace(i, a, b) for i in expr.el])
    assert False, "unreachable"

def walk(expr: SExpr, form: SExpr, m: Dict[str, SExpr], tok: tuple | None = None, scl: Sequence[str] | None = None) -> Dict[str, SExpr]:
    # TODO: document code
    if isinstance(form, SExprSymbol) and form.sym and form.sym[0].isupper():
        m[form.sym] = expr
        return m
    if isinstance(form, SExprTuple) and isinstance(expr, SExprTuple):
        if len(form.el) != len(expr.el):
            raise RuntimeError(f"An expression `{stringify(expr)}' is incompatible with a format `{stringify(form)}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
        for i in range(len(expr.el)):
            m = walk(expr.el[i], form.el[i], m)
        return m
    if expr != form:
        raise RuntimeError(f"An expression `{stringify(expr)}' is incompatible with a format `{stringify(form)}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
    return m

def is_compatible(expr: SExpr, form: SExpr) -> bool:
    # TODO: document code
    if isinstance(form, SExprSymbol) and form.sym and form.sym[0].isupper():
        return True
    if isinstance(form, SExprTuple) and isinstance(expr, SExprTuple):
        if len(form.el) != len(expr.el):
            return False
        for i in range(len(expr.el)):
            if not is_compatible(expr.el[i], form.el[i]):
                return False
        return True
    return expr == form

def wrap(expr: SExpr) -> SExpr:
    if expr.wr:
        return expr
    if isinstance(expr, SExprSymbol):
        return SExprSymbol(True, expr.sym)
    if isinstance(expr, SExprCall):
        return SExprCall(True, expr.fun, expr.arg)
    if isinstance(expr, SExprTuple):
        return SExprTuple(True, expr.el)
    assert False, "unreachable"

def unwrap(expr: SExpr) -> SExpr:
    if isinstance(expr, SExprSymbol):
        return SExprSymbol(False, expr.sym)
    if isinstance(expr, SExprCall):
        return SExprCall(False, expr.fun, unwrap(expr.arg))
    if isinstance(expr, SExprTuple):
        return SExprTuple(True, [unwrap(i) for i in expr.el])
    assert False, "unreachable"

def substitute(expr: SExpr, sform: SExpr, rform: SExpr, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    m = walk(expr, sform, {}, tok, scl)
    for r in m:
        rform = replace(rform, r, wrap(m[r]))
    rform = unwrap(rform)
    return rform

def substitute_compatible(expr: SExpr, forms: List[Tuple[SExpr, SExpr]], tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    for s, r in forms:
        if is_compatible(expr, s):
            return substitute(expr, s, r, tok, scl)
    raise RuntimeError(f"An expression `{stringify(expr)}' is incompatible with any format in this list: {';'.join(stringify(i[0]) for i in forms)} at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")

def lexer(text: str) -> List[tuple]:
    tokens: List[tuple] = []
    i = 0
    ltext = len(text)
    x = 0
    y = 0
    while i < ltext:
        c = text[i]
        if c == '(':
            tokens.append((TokenKind.LPAREN, (x, y)))
            x += 1
        elif c == ')':
            tokens.append((TokenKind.RPAREN, (x, y)))
            x += 1
        elif c == '[':
            tokens.append((TokenKind.LBRACK, (x, y)))
            x += 1
        elif c == ']':
            tokens.append((TokenKind.RBRACK, (x, y)))
            x += 1
        elif c == ':':
            tokens.append((TokenKind.COLON, (x, y)))
            x += 1
        elif c == '`':
            tokens.append((TokenKind.GRAVE, (x, y)))
            x += 1
        elif c == '-' and i+1 < ltext and text[i+1]:
            tokens.append((TokenKind.ARROW, (x, y)))
            x += 2
            i += 1
        elif c.isalnum() or c == "_":
            s = ""
            sx = x
            while i < ltext and (text[i].isalnum() or text[i] == "_"):
                s += text[i]
                i += 1
                x += 1
            i -= 1
            x -= 1
            tokens.append((TokenKind.SYMBOL, (sx, y), s))
        elif c == '\n':
            y += 1
            x = 0
        elif c.isspace():
            x += 1
        else:
            raise SyntaxError(f"Unexpected symbol `{c}' at {y+1}:{x}")
        i += 1
    return tokens

def format_loc(tok: tuple, scl: Sequence[str] | None) -> str:
    if scl != None:
        return f"{tok[1][1]+1}:{tok[1][0]} | {scl[tok[1][1]]}"
    return f"{tok[1][1]+1}:{tok[1][0]}"

@dataclass
class Expr:
    token: tuple

@dataclass
class ExprSymbol(Expr):
    sym: str

@dataclass
class ExprCTCall(Expr):
    fun: str
    arg: Expr

@dataclass
class ExprCall(Expr):
    fun: str
    arg: Expr

@dataclass
class ExprQuote(Expr):
    sentence: Expr

@dataclass
class ExprTuple(Expr):
    el: List[Expr]

@dataclass
class Stmt:
    token: tuple

@dataclass
class StmtLet(Stmt):
    name: str
    expr: Expr

@dataclass
class StmtDefForm(Stmt):
    name: str
    a: SExpr
    b: SExpr

@dataclass
class StmtUnlink(Stmt):
    name: str

@dataclass
class StmtShow(Stmt):
    expr: Expr

# `scl' is for errors generations.
# `scl' is for errors generations.

def parse_tuple(tokens: List[tuple], scl: Sequence[str], ft: tuple) -> Tuple[List[tuple], Expr]:
    n = []
    while tokens:
        if tokens[0][0] != TokenKind.SYMBOL and tokens[0][0] != TokenKind.LPAREN:
            break
        tokens, e = parse_expr(tokens, scl)
        n.append(e)
    return tokens, ExprTuple(ft, n)

def parse_expr(tokens: List[tuple], scl: Sequence[str]) -> Tuple[List[tuple], Expr]:
    if not tokens:
        raise SyntaxError(f"Expected quote, symbol, or lparen but got EOF: {format_loc(tokens[0], scl)}")
    if tokens[0][0] == TokenKind.GRAVE:
        tokens, sentence = parse_expr(tokens[1:], scl)
        return tokens, ExprQuote(tokens[0], sentence)
    if tokens[0][0] == TokenKind.SYMBOL:
        if len(tokens) > 2 and tokens[1][0] == TokenKind.GRAVE and tokens[2][0] == TokenKind.LBRACK:
            tokens_, arg = parse_expr(tokens[3:], scl)
            if not tokens:
                raise SyntaxError(f"Expected rparen but got EOF: {format_loc(tokens[0], scl)}")
            if tokens_[0][0] != TokenKind.RBRACK:
                raise SyntaxError(f"Expected rbrack but got {tokens_[0][0]}: {format_loc(tokens_[0], scl)}")
            return tokens_[1:], ExprCTCall(tokens[0], tokens[0][2], arg)
        if len(tokens) > 1 and tokens[1][0] == TokenKind.LBRACK:
            tokens_, arg = parse_expr(tokens[2:], scl)
            if not tokens:
                raise SyntaxError(f"Expected rparen but got EOF: {format_loc(tokens[0], scl)}")
            if tokens_[0][0] != TokenKind.RBRACK:
                raise SyntaxError(f"Expected rbrack but got {tokens_[0][0]}: {format_loc(tokens_[0], scl)}")
            return tokens_[1:], ExprCall(tokens[0], tokens[0][2], arg)
        return tokens[1:], ExprSymbol(tokens[0], tokens[0][2])
    if tokens[0][0] == TokenKind.LPAREN:
        tokens, e = parse_tuple(tokens[1:], scl, tokens[0])
        if not tokens:
            raise SyntaxError(f"Expected rparen but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[0][0] != TokenKind.RPAREN:
            raise SyntaxError(f"Expected rparen but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        return tokens[1:], e
    raise SyntaxError(f"Failed to parse expression at {format_loc(tokens[0], scl)}")

@dataclass
class BuiltinFunc_Args:
    e: ExprCall | SExprCall | ExprCTCall
    is_at_comptime: bool
    token: tuple | None
    scl: Sequence[str] | None

symbols: Dict[str, Tuple[SExpr, tuple]] = {}
meta_transformations: Dict[str, List[Tuple[SExpr, SExpr]]] = {}  # Transformations at compile-time.
transformations: Dict[str, List[Tuple[SExpr, SExpr, tuple]]] = {}


def bf_iscomptime(args: BuiltinFunc_Args) -> SExpr:
    return SExprSymbol(False, "TRUE" if args.is_at_comptime else "FALSE")

"""
def bf_length(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(False, str(len(args.e.arg.sym)))
    elif isinstance(args.e.arg, ExprTuple):
        return str(len(args.e.arg.el))
    else:
        raise RuntimeError(f"Expected ExprSymbol/ExprTuple but got `{type(args.e.arg)}' at {format_loc(args.e.arg.token, args.scl)}")

def bf_is_symbol(args: BuiltinFunc_Args) -> SExpr:
    if isinstance(args.e.arg, ExprSymbol):
        return SExprSymbol(False, "TRUE")
    return SExprSymbol(False, "FALSE")

def bf_gi(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if isinstance(arg, str) or len(arg) != 2:
        raise RuntimeError(f"Expected ({{EL}} {{ID}}) but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl)}")
    if not arg[1].isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg[1])}' at {format_loc(args.e.arg.el[1].token, args.scl)}")
    return arg[0][int(arg[1])]

def bf_si(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if isinstance(arg, str) or len(arg) != 3:
        raise RuntimeError(f"Expected ({{EL}} {{ID}} {{VL}}) but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl)}")
    if not arg[1].isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg[1])}' at {format_loc(args.e.arg.el[1].token, args.scl)}")
    i = int(arg[1])
    if isinstance(arg[0], str):
        vl = arg[2]
        if isinstance(vl, list):
            raise RuntimeError(f"Expected string but got `{stringify(arg[2])}' at {format_loc(args.e.arg.el[2].token, args.scl)}")
        return arg[0][:i]+vl+arg[0][i+1:]
    else:
        vl = arg[2]
        return arg[0][:i]+[vl]+arg[0][i+1:]

def bf_to_peano(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if isinstance(arg, list) or not arg.isnumeric():
        raise RuntimeError(f"Expected numberic but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl)}")
    a = []
    b = a
    i = 0
    c = int(arg)
    while i < c:
        b.append("s")
        b.append([] if i != c - 1 else "0")
        b = b[1]
        i += 1
    return a

def bf_inclusion_level(args: BuiltinFunc_Args) -> SExpr:
    arg = interpret_expr(args.e.arg, args.is_at_comptime, args.token, args.scl)
    if isinstance(arg, str):
        raise RuntimeError(f"Expected tuple but got `{stringify(arg)}' at {format_loc(args.e.arg.token, args.scl)}")
    a = 1
    r = True
    while r:
        r = False
        for i in arg:
            if isinstance(i, list):
                r = True
                arg = i
                a += 1
                break
    return str(a)
"""

builtin_funcs: Dict[str, Callable[[BuiltinFunc_Args], SExpr]] = {
    "_ISCOMPTIME": bf_iscomptime,
    # "_LENGTH": bf_length,
    # "_ISSYMBOL": bf_is_symbol,
    # "_GI": bf_gi,
    # "_SI": bf_si,
    # "_TOPEANO": bf_to_peano,
    # "_INCLVL": bf_inclusion_level
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

def interpret_sexpr(e: SExpr, comptime: bool = False, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    if isinstance(e, SExprSymbol):
        return e
    if isinstance(e, SExprCall):
        if comptime:
            return e
        if e.fun in transformations:
            t = [(a[0],a[1]) for a in transformations[e.fun]]
            return substitute_compatible(interpret_sexpr(e.arg), t, tok, scl)
        if e.fun in builtin_funcs:
            return builtin_funcs[e.fun](BuiltinFunc_Args(e, comptime, tok, scl))
        raise RuntimeError(f"Unknown transformation or builtin function `{e.fun}' at {format_loc(tok, scl) if tok and scl else 'Somewhere'}")
    if isinstance(e, SExprTuple):
        return SExprTuple(False, [interpret_sexpr(i) for i in e.el])
    assert False, "Unreachable"

def interpret_expr_extra(e: Expr, comptime: bool = False, tok: tuple | None = None, scl: Sequence[str] | None = None) -> SExpr:
    return interpret_sexpr(interpret_expr(e, comptime, tok, scl), comptime, tok, scl)

def parse_stmt(tokens: List[tuple], scl: Sequence[str]) -> Tuple[List[tuple], Stmt]:
    if not tokens:
        raise SyntaxError(f"Expected symbol but got EOF: {format_loc(tokens[0], scl)}")
    if tokens[0][0] != TokenKind.SYMBOL:
        raise SyntaxError(f"Expected symbol but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
    if tokens[0][2] == "let":
        ft = tokens[0]
        if len(tokens) == 1:
            raise SyntaxError(f"Expected symbol but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.SYMBOL:
            raise SyntaxError(f"Expected symbol but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        if len(tokens) == 2:
            raise SyntaxError(f"Expected colon but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[2][0] != TokenKind.COLON:
            raise SyntaxError(f"Expected colon but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        name = tokens[1][2]
        tokens, e = parse_expr(tokens[3:], scl)
        return tokens, StmtLet(ft, name, e)
    if tokens[0][2] == "form":
        ft = tokens[0]
        tokens = tokens[1:]
        if not tokens:
            raise SyntaxError(f"Expected symbol but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[0][0] != TokenKind.SYMBOL:
            raise SyntaxError(f"Expected symbol but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        name = tokens[0][2]
        if len(tokens) == 1:
            raise SyntaxError(f"Expected colon but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.COLON:
            raise SyntaxError(f"Expected colon but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        tokens, a = parse_expr(tokens[2:], scl)
        if not tokens:
            raise SyntaxError(f"Expected arrow but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[0][0] != TokenKind.ARROW:
            raise SyntaxError(f"Expected arrow but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        tokens, b = parse_expr(tokens[1:], scl)
        ia, ib = interpret_expr(a, True, a.token, scl), interpret_expr(b, True, b.token, scl)
        if name not in meta_transformations:
            meta_transformations[name] = []
        meta_transformations[name].append((ia, ib))
        return tokens, StmtDefForm(ft, name, ia, ib)
    if tokens[0][2] == "unlink":
        if len(tokens) == 1:
            raise SyntaxError(f"Expected symbol but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.SYMBOL:
            raise SyntaxError(f"Expected symbol but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        return tokens[2:], StmtUnlink(tokens[0], tokens[1][2])
    if tokens[0][2] == "show":
        ft = tokens[0]
        tokens, e = parse_expr(tokens[1:], scl)
        return tokens, StmtShow(ft, e)
    raise SyntaxError(f"Expected `let', `form', 'unlink', or `show' but got `{tokens[0][2]}': {format_loc(tokens[0], scl)}")

def parse_program(tokens: List[tuple], scl: Sequence[str]) -> List[Stmt]:
    stmts = []
    while tokens:
        tokens, stmt = parse_stmt(tokens, scl)
        stmts.append(stmt)
    return stmts

def stringify(expr: SExpr) -> str:
    if isinstance(expr, SExprSymbol):
        return expr.sym
    elif isinstance(expr, SExprTuple):
        return '(' + ' '.join(stringify(i) for i in expr.el) + ')'
    elif isinstance(expr, SExprCall):
        return expr.fun + '[' + stringify(expr.arg) + ']'
    assert False, "unreachable"

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


"""
Syntax:

Symbol ::= {alnum | "_"}+
GRAVE ::= "`"

Let ::= "let" Symbol ":" Expr
Define_Transformation ::= "form" Symbol ":" Expr "->" Expr
Unlink ::= "unlink" Symbol
Show ::= "show" Expr
Stmt ::= Let | Define_Transformation | Unlink | Show

Call ::= Symbol GRAVE? "[" Expr "]"
Tuple ::= "(" Expr* ")"
Expr ::= GRAVE? {Symbol | Call | Tuple}
"""

c = open("tst.ss", "r").read()
l = lexer(c)
scl = c.split("\n")
instructions = parse_program(l, scl)
interpret_program(instructions, scl)
