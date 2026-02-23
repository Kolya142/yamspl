from dataclasses import dataclass
from copy import deepcopy
from typing import *
from enum import Enum

# TO NOT BE CONFUSED, `SExpr' is a purely logic type, when `Expr' is a purely parsing type.

_iotac = 0
def iota(rst: bool = False) -> int:
    global _iotac
    if rst:
        _iotac = 0
        return 0
    else:
        _iotac += 1
        return _iotac - 1


iota(True)
class TokenKind(Enum):
    EOF     = iota()
    SYMBOL  = iota()
    LPAREN  = iota()
    RPAREN  = iota()
    LBRACK  = iota()
    RBRACK  = iota()
    ARROW   = iota()
    COLON   = iota()
    GRAVE   = iota()
    STRING  = iota()
    LBRACE  = iota()
    RBRACE  = iota()
    GRAVE_LPAREN = iota()
    EQUAL   = iota()

T = TypeVar('T')

# I hate the Python's iterator thingy

class Peekable(Generic[T]):
    def next(self) -> T | None:
        raise NotImplementedError()
    def peek(self) -> T | None:
        raise NotImplementedError()

class PeekableSequence(Peekable, Generic[T]):
    seq: Sequence[T]
    qi: int
    c: T | None

    def __init__(self, seq: Sequence[T]) -> None:
        self.seq = seq
        self.qi = 0
        self.c = None
    
    def next(self) -> T | None:
        self.qi += 1
        return self.peek()
    def peek(self) -> T | None:
        return self.seq[self.qi] if self.qi < len(self.seq) else None

@dataclass
class Token:
    kind: TokenKind
    row: int
    col: int
    filepath: str = "<string>"
    sym: str | None = None

NITOK = Token(TokenKind.EOF, -1, -1, "<>")

@dataclass
class Expr:
    token: Token

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
class SExpr(Expr):
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
class Stmt:
    token: Token

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
class StmtDefFunc(Stmt):
    name: str
    arg: List[str]
    stmt: List[Stmt]

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

iota(True)
class LocFmtStyle(Enum):
    Grep   = iota()
    Emacs  = iota()
    Editor = iota()

def format_loc(tok: Token, lfs = LocFmtStyle.Emacs) -> str:
    fp  = tok.filepath
    row = tok.row
    col = tok.col
    if lfs == LocFmtStyle.Grep:
        return f"{fp}:{row+1}:{col}: LOC"
    if lfs == LocFmtStyle.Emacs:
        return f"{fp}:{row+1}:{col}: LOC"
    if lfs == LocFmtStyle.Editor:
        return f"{fp}:{row+1}:{col+1}"
    assert False, "unreachable"

