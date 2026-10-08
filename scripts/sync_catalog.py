#!/usr/bin/env python3
"""Validate the curated catalog and generate the Flutter asset/package queries."""
import argparse
import json
from pathlib import Path
import re
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[1]
check = argparse.ArgumentParser()
check.add_argument('--check', action='store_true')
args = check.parse_args()
projects = json.loads((root / 'catalog/projects.json').read_text())
ids = set()
packages = set()
for project in projects:
    assert re.fullmatch(r'[a-z0-9_-]+', project['id']), 'Invalid project ID'
    assert project['id'] not in ids, 'Duplicate project ID'
    ids.add(project['id'])
    assert re.fullmatch(r'[\w.-]+/[\w.-]+', project['repository']), 'Invalid repository'
    assert project['name'] and project['description'], 'Name and description are required'
    if project.get('website'):
        assert urlparse(project['website']).scheme == 'https', 'Websites must use HTTPS'
    if project.get('icon'):
        assert (root / 'apps/core' / project['icon']).is_file(), 'Icon is missing'
    for key in ('packageId', 'devPackageId'):
        if project.get(key):
            assert re.fullmatch(r'[A-Za-z][\w]*(\.[A-Za-z][\w]*)+', project[key]), 'Invalid Android package ID'
            packages.add(project[key])
asset = root / 'apps/core/assets/catalog.json'
manifest = root / 'apps/core/android/app/src/main/AndroidManifest.xml'
start, end = '<!-- catalog packages:start -->', '<!-- catalog packages:end -->'
block = '\n'.join(f'        <package android:name="{p}" />' for p in sorted(packages))
original = manifest.read_text()
updated = re.sub(re.escape(start) + r'.*?' + re.escape(end), start + '\n' + block + '\n        ' + end, original, flags=re.S)
assert start in original and end in original, 'Manifest catalog markers missing'
outputs = {asset: json.dumps(projects, indent=2) + '\n', manifest: updated}
for path, content in outputs.items():
    if args.check:
        assert path.read_text() == content, f'{path.relative_to(root)} is out of sync; run scripts/sync_catalog.py'
    else:
        path.write_text(content)
print(f'Catalog validated: {len(projects)} projects, {len(packages)} Android packages.')
