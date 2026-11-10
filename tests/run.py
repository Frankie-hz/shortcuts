import pathlib
import sys

from lupa import luajit21

root = pathlib.Path(__file__).resolve().parent.parent
lua = luajit21.LuaRuntime()
lua.globals().ADDON_DIR = root.as_posix()
failures = lua.execute((root / 'tests' / 'harness.lua').read_text(encoding='utf-8'))
sys.exit(int(failures > 0))
