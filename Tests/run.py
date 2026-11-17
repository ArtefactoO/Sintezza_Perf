"""Run Lua 5.1 syntax and isolated mocks using the supplied Lupa installation."""
import argparse
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', required=True, help='Directory containing lupa 2.6')
parser.add_argument('--suite', default='core', choices=['core', 'phase2', 'developer', 'developerui', 'ui', 'phase2ui', 'theme', 'startup', 'startupwindow', 'layers', 'all', 'syntax'])
args = parser.parse_args()
sys.path.insert(0, args.runtime)
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
compile_lua = lua.eval('function(source, name) local f, err = loadstring(source, name); if not f then error(err) end return true end')
for path in sorted(root.rglob('*.lua')):
    if any(part.startswith('.') for part in path.relative_to(root).parts):
        continue
    compile_lua(path.read_text(encoding='utf-8-sig'), '@' + str(path))
print('Lua 5.1 syntax: PASS')
for suite in (['core', 'phase2', 'ui', 'phase2ui', 'developer', 'developerui', 'theme', 'startup', 'startupwindow', 'layers'] if args.suite == 'all' else [args.suite]):
    if suite == 'syntax':
        continue
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.globals().ADDON_ROOT = root.as_posix()
    runtime.execute((root / 'Tests' / (suite + '.lua')).read_text(encoding='utf-8'))
