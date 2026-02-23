"$!include common.pyx"
"$!include logic.pyx"
"$!include parser.pyx"
"$!include interpretator.pyx"
import sys

if len(sys.argv) != 2:
    print(f"{sys.argv[0]}: Usage: <script file>", file=sys.stderr)
    sys.exit(1)

c = open(sys.argv[1], "r").read()
l = lexer(c, sys.argv[1])
instructions = parse_program(ParseEnv(PeekableSequence(l)))
interpret_program(instructions)
