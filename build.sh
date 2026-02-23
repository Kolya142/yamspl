set -e

if [ ! -e pyx ]; then
    echo ------ GETTING pyx ------
    git clone https://github.com/Kolya142/pyx pyx;
    (cd pyx; python3 stage0/pyx_compiler.py pyx_compiler.py pyx_compiler.pyx);
    echo "*" > pyx/.gitignore;
fi

python3 pyx/pyx_compiler.py main.py main.pyx
mypy main.py
