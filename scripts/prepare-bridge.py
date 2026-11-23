"""Apply one narrowly scoped compiler-compatibility annotation to pinned upstream source.

Authorization decisions, cooldowns, memory-only sessions and cookie validation are unchanged.
"""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[1]
checkout = root / 'Bridge/.build/checkouts/CodexBar'
revision = subprocess.check_output(['git', '-C', str(checkout), 'rev-parse', 'HEAD'], text=True).strip()
assert revision == '5dd48cab770a326691b25a124d37ffee12c5f7ac', 'Unexpected engine revision'
path = checkout / 'Sources/CodexBarCore/BrowserCookieAccessGate.swift'
source = path.read_text()
anchor = '    static func withAccessFailureObserver<T>('
patched = '    @_optimize(none)\n' + anchor
if patched not in source:
    assert source.count(anchor) == 1, 'Unexpected observer implementation'
    path.chmod(path.stat().st_mode | 0o200)
    path.write_text(source.replace(anchor, patched))
print('Applied pinned TaskLocal observer compiler compatibility annotation')
