def lexer(text: str, filepath: str) -> Sequence[Token]:
    tokens: List[Token] = []
    i = 0
    ltext = len(text)
    x = 0
    y = 0
    while i < ltext:
        c = text[i]
        if c == '(':
            tokens.append(Token(TokenKind.LPAREN, y, x, filepath))
            x += 1
        elif c == ')':
            tokens.append(Token(TokenKind.RPAREN, y, x, filepath))
            x += 1
        elif c == '[':
            tokens.append(Token(TokenKind.LBRACK, y, x, filepath))
            x += 1
        elif c == ']':
            tokens.append(Token(TokenKind.RBRACK, y, x, filepath))
            x += 1
        elif c == '{':
            tokens.append(Token(TokenKind.LBRACE, y, x, filepath))
            x += 1
        elif c == '}':
            tokens.append(Token(TokenKind.RBRACE, y, x, filepath))
            x += 1
        elif c == ':':
            tokens.append(Token(TokenKind.COLON,  y, x, filepath))
            x += 1
        elif c == '=':
            tokens.append(Token(TokenKind.EQUAL,  y, x, filepath))
            x += 1
        elif c == '`':
            if i + 1 < ltext and text[i + 1] == '[':
                tokens.append(Token(TokenKind.GRAVE_LPAREN, y, x, filepath))
                x += 1
                i += 1
            else:
                tokens.append(Token(TokenKind.GRAVE, y, x, filepath))
            x += 1
        elif c == '\'':
            s = ""
            x += 1
            i += 1
            sx = x
            while i < ltext and text[i] != '\'' and text[i] != '\n':
                if text[i] == '\\':
                    i += 1
                    x += 1
                    if i >= ltext:
                        raise SyntaxError(f"Unexpected EOF after string at {y+1}:{x}")
                    if text[i] == '\\':
                        s += '\\'
                    elif text[i] == 'n':
                        s += '\n'
                    elif text[i] == '\'':
                        s += '\''
                    elif text[i] == 't':
                        s += '\t'
                    elif text[i] == 'v':
                        s += '\v'
                    elif text[i] == 'e':
                        s += '\x1b'
                    elif text[i] == 'x':
                        assert False, "TBD"
                    else:
                        s += '\\'+text[i]
                else:
                    s += text[i]
                i += 1
                x += 1
            if i >= ltext:
                raise SyntaxError(f"Expected `\\'' but got EOF after string at {y+1}:{x}")
            if text[i] != '\'':
                raise SyntaxError(f"Expected `\\'' but got `{text[i]}' after string at {y+1}:{x}")
            x += 1
            tokens.append(Token(TokenKind.STRING, y, sx, filepath, s))
        elif c == '/' and i+1 < ltext and text[i+1] == '/':
            while i < ltext and text[i] != '\n':
                i += 1
            x = 0
            y += 1
        elif c == '-' and i+1 < ltext and text[i+1] == '>':
            tokens.append(Token(TokenKind.ARROW, y, x, filepath))
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
            tokens.append(Token(TokenKind.SYMBOL, y, sx, filepath, s))
        elif c == '\n':
            y += 1
            x = 0
        elif c.isspace():
            x += 1
        else:
            raise SyntaxError(f"Unexpected symbol `{c}' at {y+1}:{x}")
        i += 1    
    tokens.append(Token(TokenKind.EOF, y, x, filepath))
    return tokens


class ParseEnv:
    tokens: Peekable[Token]

    def __init__(self, tokens: Peekable[Token]) -> None:
        self.tokens = tokens

    def peek(self) -> Token:
        a = self.tokens.peek()
        assert a is not None, "Hmm... Very suspicious"
        return a

    def next(self) -> Token:
        a = self.peek()
        if a.kind == TokenKind.EOF:
            return a
        b = self.tokens.next()
        assert b is not None, "Hmm... Very suspicious"
        return b

    def expect(self, kind: TokenKind) -> Token:
        k = self.peek()
        if k.kind != kind:
            raise SyntaxError(f"Expected {kind} but got {k.kind}: {format_loc(k)}")
        self.next()
        return k

def parse_tuple(e: ParseEnv, ft: Token) -> Expr:
    n = []
    while True:
        x = parse_expr(e)
        if x is None:
            break
        n.append(x)
    return ExprTuple(ft, n)

def parse_expr(e: ParseEnv) -> Expr | None:
    k = e.peek()
    kk = k.kind
    if kk == TokenKind.GRAVE:
        ft = e.next()
        sentence = parse_expr(e)
        if sentence is None:
            raise SyntaxError(f"Expected expression at {format_loc(ft)}")
        return ExprQuote(k, sentence)
    if kk == TokenKind.SYMBOL:
        assert k.sym != None
        kkk = e.next()
        kkkk = kkk.kind
        if kkkk == TokenKind.GRAVE_LPAREN:
            ft = e.next()
            arg = parse_expr(e)
            if arg is None:
                raise SyntaxError(f"Expected expression at {format_loc(ft)}")
            e.expect(TokenKind.RBRACK)
            return ExprCTCall(k, k.sym, arg)
        if kkkk == TokenKind.LBRACK:
            ft = e.next()
            arg = parse_expr(e)
            if arg is None:
                raise SyntaxError(f"Expected expression at {format_loc(ft)}")
            e.expect(TokenKind.RBRACK)
            return ExprCall(k, k.sym, arg)
        return ExprSymbol(k, k.sym)
    if kk == TokenKind.LPAREN:
        e.next()
        t = parse_tuple(e, k)
        e.expect(TokenKind.RPAREN)
        return t
    return None

# Dirty code. Yay!!

def parse_stmt(e: ParseEnv) -> List[Stmt] | None:
    k = e.peek()
    if k.kind != TokenKind.SYMBOL:
        return None
    ks = k.sym
    e.next()
    if ks == "let":
        name = e.expect(TokenKind.SYMBOL).sym
        assert name != None
        e.expect(TokenKind.EQUAL)
        ft = e.peek()
        d = parse_expr(e)
        if d is None:
            raise SyntaxError(f"Expected expression at {format_loc(ft)}")
        return [StmtLet(k, name, d)]
    if ks == "form":
        name = e.expect(TokenKind.SYMBOL).sym
        assert name is not None
        e.expect(TokenKind.COLON)
        ft = e.peek()
        a = parse_expr(e)
        if a is None:
            raise SyntaxError(f"Expected expression at {format_loc(ft)}")
        e.expect(TokenKind.ARROW)
        ft = e.peek()
        b = parse_expr(e)
        if b is None:
            raise SyntaxError(f"Expected expression at {format_loc(ft)}")
        ia, ib = interpret_expr(a, True, a.token), interpret_expr(b, True, b.token)
        if name not in meta_transformations:
            meta_transformations[name] = []
        meta_transformations[name].append((ia, ib))

        # if inst.name in symbols:
        #     if symbols[inst.name][1] is not None:
        #         raise RuntimeError(f"Failed to define transformation `{inst.name}' at {format_loc(inst.token)}\nThis name is already taken by a symbol at {format_loc(symbols[inst.name][1])}")
        #     else:
        #         raise RuntimeError(f"Failed to define transformation `{inst.name}' at {format_loc(inst.token)}\nThis name is already taken by a symbol at Somewhere")
        if name not in transformations:
            transformations[name] = []
        transformations[name].append((ia, ib, ft))
        return []  # StmtDefForm(ft, name, ia, ib)] Unnecessary
    if ks == "unlink":
        name = e.expect(TokenKind.SYMBOL).sym
        assert name is not None
        return [StmtUnlink(k, name)]
    if ks == "show":
        ft = e.peek()
        t = parse_expr(e)
        if t is None:
            raise SyntaxError(f"Expected expression at {format_loc(ft)}")
        return [StmtShow(k, t)]
    if ks == "print":
        text = e.expect(TokenKind.STRING).sym
        assert text is not None
        return [StmtPrint(k, text)]
    if ks == "include":
        p = e.expect(TokenKind.STRING).sym
        assert p is not None
        c = open(p, "r").read()
        l = lexer(c, p)
        scl = c.split("\n")
        r = ParseEnv(PeekableSequence(l))
        return parse_program(r)
    if ks == "func":
        name = e.expect(TokenKind.SYMBOL).sym
        assert name is not None
        e.expect(TokenKind.EQUAL)
        e.expect(TokenKind.LPAREN)
        args = []
        while True:
            k = e.peek()
            if k.kind != TokenKind.SYMBOL:
                break
            assert k.sym is not None
            args.append(k.sym)
            e.next()
        e.expect(TokenKind.RPAREN)
        e.expect(TokenKind.LBRACE)
        body = parse_program(e)
        e.expect(TokenKind.RBRACE)
        return [StmtDefFunc(k, name, args, body)]
    return None

def parse_program(e: ParseEnv) -> List[Stmt]:
    stmts = []
    while True:
        stmt = parse_stmt(e)
        if stmt is None:
            break
        stmts.extend(stmt)
    return stmts
