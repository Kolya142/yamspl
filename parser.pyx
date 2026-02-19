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
            tokens.append((TokenKind.STRING, (sx, y), s))
        elif c == '/' and i+1 < ltext and text[i+1] == '/':
            while i < ltext and text[i] != '\n':
                i += 1
            x = 0
            y += 1
        elif c == '-' and i+1 < ltext and text[i+1] == '>':
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

def parse_stmt(tokens: List[tuple], scl: Sequence[str]) -> Tuple[List[tuple], List[Stmt]]:
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
        return tokens, [StmtLet(ft, name, e)]
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
        return tokens, [StmtDefForm(ft, name, ia, ib)]
    if tokens[0][2] == "unlink":
        if len(tokens) == 1:
            raise SyntaxError(f"Expected symbol but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.SYMBOL:
            raise SyntaxError(f"Expected symbol but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        return tokens[2:], [StmtUnlink(tokens[0], tokens[1][2])]
    if tokens[0][2] == "show":
        ft = tokens[0]
        tokens, e = parse_expr(tokens[1:], scl)
        return tokens, [StmtShow(ft, e)]
    if tokens[0][2] == "include":
        if len(tokens) == 1:
            raise SyntaxError(f"Expected string but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.STRING:
            raise SyntaxError(f"Expected string but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        c = open(tokens[1][2], "r").read()
        l = lexer(c)
        scl = c.split("\n")
        return tokens[2:], parse_program(l, scl)
    if tokens[0][2] == "print":
        if len(tokens) == 1:
            raise SyntaxError(f"Expected string but got EOF: {format_loc(tokens[0], scl)}")
        if tokens[1][0] != TokenKind.STRING:
            raise SyntaxError(f"Expected string but got {tokens[0][0]}: {format_loc(tokens[0], scl)}")
        return tokens[2:], [StmtPrint(tokens[0], tokens[1][2])]
    raise SyntaxError(f"Expected `let', `form', 'unlink', `show', `include', or `print' but got `{tokens[0][2]}': {format_loc(tokens[0], scl)}")

def parse_program(tokens: List[tuple], scl: Sequence[str]) -> List[Stmt]:
    stmts = []
    while tokens:
        tokens, stmt = parse_stmt(tokens, scl)
        stmts.extend(stmt)
    return stmts
