#!/usr/bin/env python3
"""Read-only release news. Upstream Markdown is data, never commands."""
import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request

API = 'https://api.github.com/repos/omacom/omarchy/releases?per_page=50'
TTL = 1800
MAX_BYTES = 2 * 1024 * 1024


def version_key(value, arch=True):
    """Numeric core, SemVer prerelease ordering; ignore Arch numeric pkgrel."""
    if not isinstance(value, str):
        return None
    value = value.strip()
    if arch:
        value = re.sub(r'-\d+(?:\.\d+)?$', '', value)
    match = re.fullmatch(r'v?(\d+)\.(\d+)\.(\d+)(?:-([a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*))?(?:\+[a-zA-Z0-9.-]+)?', value)
    if not match:
        return None
    major, minor, patch, pre = match.groups()
    tokens = pre.split('.') if pre else []
    suffix = tuple((0, int(t)) if t.isdigit() else (1, t) for t in tokens)
    return (int(major), int(minor), int(patch), 1 if pre is None else 0, suffix)


def iso(timestamp):
    return dt.datetime.fromtimestamp(timestamp, dt.timezone.utc).isoformat().replace('+00:00', 'Z')


def atomic_json(path, data):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.' + path.name + '.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, ensure_ascii=False)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def load_json(path):
    try:
        with open(path) as stream:
            data = json.load(stream)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def safe_url(url):
    if not isinstance(url, str) or any(ord(c) < 33 for c in url):
        return False
    try:
        parsed = urllib.parse.urlsplit(url)
    except ValueError:
        return False
    prefix = '/omacom/omarchy/releases/tag/'
    return (parsed.scheme == 'https' and parsed.netloc == 'github.com'
            and parsed.path.startswith(prefix) and len(parsed.path) > len(prefix)
            and not parsed.query and not parsed.fragment
            and not any(part in ('.', '..') for part in urllib.parse.unquote(parsed.path).split('/')))


def releases_from(data):
    if not isinstance(data, list):
        raise ValueError('GitHub returned an invalid release list')
    result = []
    for item in data[:50]:
        if not isinstance(item, dict) or item.get('draft', False):
            continue
        tag = item.get('tag_name')
        if not isinstance(tag, str) or not tag or not safe_url(item.get('html_url')):
            continue
        if not isinstance(item.get('published_at'), str):
            continue
        body = item.get('body')
        title = item.get('name')
        if body is not None and not isinstance(body, str):
            continue
        if title is not None and not isinstance(title, str):
            continue
        result.append({'tag': tag, 'title': title or tag, 'date': item['published_at'],
                       'url': item['html_url'], 'body': body or '',
                       'prerelease': bool(item.get('prerelease', False))})
    return result


def fetch_releases():
    request = urllib.request.Request(API, headers={'Accept': 'application/vnd.github+json',
                                                  'User-Agent': 'omarchy-news'})
    with urllib.request.urlopen(request, timeout=8) as response:
        payload = response.read(MAX_BYTES + 1)
    if len(payload) > MAX_BYTES:
        raise ValueError('GitHub response exceeded size limit')
    data = json.loads(payload)
    releases_from(data)  # Validate before caching.
    return data


def detect(args):
    try:
        result = subprocess.run(['omarchy', 'version'] + args, capture_output=True,
                                text=True, timeout=3, check=True)
        return result.stdout.strip() or None
    except (OSError, subprocess.SubprocessError):
        return None


def digest(release):
    content = [release[k] for k in ('tag', 'title', 'date', 'url', 'body')]
    return hashlib.sha256(json.dumps(content, ensure_ascii=False).encode()).hexdigest()


def empty_feed(error=''):
    return {'installedVersion': None, 'previousVersion': None, 'channel': 'unknown',
            'fetchedAt': None, 'error': error, 'releases': [],
            'statusNote': 'Availability is unverified until a stable installed version and channel are known.',
            'limitNote': 'Only the first 50 GitHub releases are fetched; older releases may be omitted.'}


def feed(refresh=False, read_tag=None, cache_dir=None, state_dir=None, read_all=False):
    cache_dir = Path(cache_dir or Path(os.environ.get('XDG_CACHE_HOME', Path.home() / '.cache')) / 'omarchy-news')
    state_dir = Path(state_dir or Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'omarchy-news')
    state_dir.mkdir(parents=True, exist_ok=True)
    # One lock covers read/modify/write of state AND cache across monitor processes.
    with open(state_dir / 'news.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        return _feed_locked(refresh, read_tag, cache_dir, state_dir, read_all)


def _feed_locked(refresh, read_tag, cache_dir, state_dir, read_all=False):
    output = empty_feed()
    errors = []
    installed = detect([])
    channel = detect(['channel']) or 'unknown'
    output.update(installedVersion=installed, channel=channel)
    state = load_json(state_dir / 'state.json')
    if not isinstance(state.get('read'), dict):
        state['read'] = {}
    if installed and version_key(installed) is not None:
        if state.get('observed') != installed:
            state['previous'] = state.get('observed')
            state['observed'] = installed
    previous = state.get('previous')
    output['previousVersion'] = previous if isinstance(previous, str) else None
    current_key, previous_key = version_key(installed), version_key(previous)
    if channel == 'stable' and current_key:
        output['statusNote'] = 'Available means a newer published stable release, not proof that a package mirror is ready.'
    else:
        output['statusNote'] = 'Availability cannot be proven on edge/unknown channels or without a known installed version; unmatched newer releases are previews.'
    cache = load_json(cache_dir / 'releases.json')
    stamp = cache.get('timestamp')
    try:
        releases = releases_from(cache.get('data'))
        valid_cache = isinstance(stamp, (int, float)) and 0 <= stamp <= time.time()
        if not valid_cache:
            releases = []
    except (ValueError, TypeError):
        valid_cache, releases = False, []
    if refresh or not valid_cache or time.time() - stamp >= TTL:
        try:
            data = fetch_releases()
            releases = releases_from(data)
            stamp = time.time()
            valid_cache = True
            atomic_json(cache_dir / 'releases.json', {'timestamp': stamp, 'data': data})
        except Exception as exc:
            errors.append('Release fetch/cache failed: ' + str(exc) + ('; using stale cache.' if valid_cache else '.'))
    if valid_cache:
        output['fetchedAt'] = iso(stamp)
    found = False
    for release in releases:
        key = version_key(release['tag'], arch=False)
        prerelease = release.pop('prerelease') or (key is not None and key[3] == 0)
        if key is not None and current_key is not None and key == current_key:
            status = 'installed'
        elif prerelease:
            status = 'preview'
        elif key is not None and current_key is not None and key < current_key:
            status = 'history'
        elif key is not None and current_key is not None and channel == 'stable':
            status = 'available'
        else:
            status = 'preview'
        revision = digest(release)
        if read_all or release['tag'] == read_tag:
            state['read'][release['tag']] = revision
            found = True
        release.update(status=status, unread=state['read'].get(release['tag']) != revision,
                       justInstalled=bool(key is not None and previous_key is not None
                                          and current_key is not None and previous_key < key <= current_key))
    if read_tag is not None and not found:
        errors.append('Release tag not found in the cached/fetched release window: ' + read_tag)
    output['releases'] = releases
    atomic_json(state_dir / 'state.json', state)
    output['error'] = ' '.join(errors)
    return output


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise ValueError(message)


def main(argv=None):
    try:
        parser = Parser(description=__doc__)
        commands = parser.add_subparsers(dest='command', required=True, parser_class=Parser)
        commands.add_parser('feed').add_argument('--refresh', action='store_true')
        commands.add_parser('read').add_argument('tag')
        commands.add_parser('read-all')
        args = parser.parse_args(argv)
        output = feed(refresh=getattr(args, 'refresh', False), read_tag=getattr(args, 'tag', None),
                      read_all=args.command == 'read-all')
    except Exception as exc:
        output = empty_feed(str(exc))
    print(json.dumps(output, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main())
