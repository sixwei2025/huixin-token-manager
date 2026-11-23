"""Package the app with UTF-8 filenames and executable modes, without workstation metadata."""
from pathlib import Path
import os
import stat
import sys
import zipfile

app, output = map(Path, sys.argv[1:])
assert app.is_dir() and app.suffix == '.app'
with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in [app, *sorted(app.rglob('*'))]:
        name = app.name + ('/' + path.relative_to(app).as_posix() if path != app else '')
        if path.is_symlink():
            entry = zipfile.ZipInfo(name)
            entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(entry, os.readlink(path).encode('utf-8'))
        else:
            archive.write(path, name + ('/' if path.is_dir() else ''))
print('Packaged app with UTF-8 names and executable permissions')
