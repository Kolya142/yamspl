from dataclasses import dataclass
from typing import *
from enum import Enum

# TO NOT BE CONFUSED, `SExpr' is a purely logic type, when `Expr' is a purely parsing type.

class TokenKind(Enum):
    SYMBOL  = 0
    LPAREN  = 1
    RPAREN  = 2
    LBRACK  = 3
    RBRACK  = 4
    ARROW   = 5
    COLON   = 6
    GRAVE   = 7
    STRING  = 8

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

@dataclass
class StmtPrint(Stmt):
    text: str

def stringify(expr: SExpr) -> str:
    if isinstance(expr, SExprSymbol):
        return expr.sym
    elif isinstance(expr, SExprTuple):
        return '(' + ' '.join(stringify(i) for i in expr.el) + ')'
    elif isinstance(expr, SExprCall):
        return expr.fun + '[' + stringify(expr.arg) + ']'
    assert False, "unreachable"

def format_loc(tok: tuple, scl: Sequence[str] | None) -> str:
    if scl != None:
        return f"{tok[1][1]+1}:{tok[1][0]} | {scl[tok[1][1]]}"
    return f"{tok[1][1]+1}:{tok[1][0]}"
