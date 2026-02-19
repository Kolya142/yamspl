"$!include common.pyx"
"$!include logic.pyx"
"$!include parser.pyx"
"$!include interpretator.pyx"
import sys

if len(sys.argv) != 2:
    print(f"{sys.argv[0]}: Usage: <script file>", file=sys.stderr)
    sys.exit(1)

c = open(sys.argv[1], "r").read()
l = lexer(c)
scl = c.split("\n")
instructions = parse_program(l, scl)
interpret_program(instructions, scl)
