import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('news', Path(__file__).resolve().parents[1] / 'news.py')
news = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(news)


def release(tag, **extra):
    return dict(tag_name=tag, name='Release ' + tag, body='# Original\n\n`do not execute`\n',
                html_url='https://github.com/omacom/omarchy/releases/tag/' + tag,
                published_at='2026-10-01T12:00:00Z', draft=False, prerelease=False, **extra)


class NewsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.version = '4.0.6-1'
        self.channel = 'stable'
        self.data = [release('v4.0.7'), release('v4.0.6'), release('v4.0.5'), release('v4.1.0-rc1')]
        self.detect = patch.object(news, 'detect', side_effect=lambda args: self.channel if args else self.version)
        self.fetch = patch.object(news, 'fetch_releases', side_effect=lambda: self.data)
        self.detect.start()
        self.fetch_mock = self.fetch.start()
        self.addCleanup(self.detect.stop)
        self.addCleanup(self.fetch.stop)

    def feed(self, **kwargs):
        return news.feed(cache_dir=self.root / 'cache', state_dir=self.root / 'state', **kwargs)

    def test_version_ordering(self):
        versions = ['4.0.9', '4.0.10-alpha.1', '4.0.10-alpha.2', '4.0.10-beta1',
                    '4.0.10-rc.2', '4.0.10-rc.10', '4.0.10', '4.1.0', '5.0.0']
        keys = list(map(news.version_key, versions))
        self.assertEqual(keys, sorted(keys))
        self.assertEqual(news.version_key('v4.0.6'), news.version_key('4.0.6-1'))
        self.assertEqual(news.version_key('4.0.6-rc1-2'), news.version_key('4.0.6-rc1'))
        self.assertIsNone(news.version_key('unknown'))
        self.assertLess(news.version_key('4.0.6-1', arch=False), news.version_key('4.0.6'))
        self.assertLess(news.version_key('4.0.6-rc10'), news.version_key('4.0.6-rc2'))

    def test_status_and_first_run(self):
        result = self.feed()
        self.assertIsNone(result['previousVersion'])
        self.assertEqual([r['status'] for r in result['releases']], ['available', 'installed', 'history', 'preview'])
        self.assertFalse(any(r['justInstalled'] for r in result['releases']))
        self.assertEqual(result['releases'][0]['body'], self.data[0]['body'])
        self.assertIn('not proof', result['statusNote'])
        for channel in ('edge', 'unknown'):
            self.channel = channel
            self.assertEqual(self.feed()['releases'][0]['status'], 'preview')
        self.version = None
        self.assertTrue(all(r['status'] == 'preview' for r in self.feed()['releases']))

    def test_persistent_transition_range(self):
        self.version = '4.0.4-1'
        self.feed()
        self.version = '4.0.6-1'
        for refresh in (False, True, False):
            result = self.feed(refresh=refresh)
            self.assertEqual(result['previousVersion'], '4.0.4-1')
            self.assertEqual([r['tag'] for r in result['releases'] if r['justInstalled']], ['v4.0.6', 'v4.0.5'])
        self.version = '4.0.5-1'
        self.assertFalse(any(r['justInstalled'] for r in self.feed()['releases']))

    def test_read_revisions(self):
        self.assertTrue(self.feed()['releases'][0]['unread'])
        self.assertFalse(self.feed(read_tag='v4.0.7')['releases'][0]['unread'])
        self.assertFalse(self.feed()['releases'][0]['unread'])
        self.data[0]['body'] += '\nUpdated notes'
        self.assertTrue(self.feed(refresh=True)['releases'][0]['unread'])
        self.assertIn('not found', self.feed(read_tag='missing')['error'])

    def test_read_all_persists_and_only_marks_current_revisions(self):
        self.assertTrue(all(r['unread'] for r in self.feed()['releases']))
        result = self.feed(read_all=True)
        self.assertFalse(any(r['unread'] for r in result['releases']))
        self.assertFalse(any(r['unread'] for r in self.feed()['releases']))
        self.data[0]['body'] += '\nRevised'
        self.data.append(release('v4.2.0'))
        result = self.feed(refresh=True)
        self.assertEqual([r['tag'] for r in result['releases'] if r['unread']], ['v4.0.7', 'v4.2.0'])

    def test_cache_and_stale_fallback(self):
        first = self.feed()
        self.feed()
        self.assertEqual(self.fetch_mock.call_count, 1)
        self.fetch_mock.side_effect = OSError('offline')
        stale = self.feed(refresh=True)
        self.assertEqual(first['releases'], stale['releases'])
        self.assertEqual(first['fetchedAt'], stale['fetchedAt'])
        self.assertIn('stale cache', stale['error'])
        (self.root / 'cache/releases.json').unlink()
        self.assertEqual(self.feed()['releases'], [])

    def test_expired_cache(self):
        self.feed()
        path = self.root / 'cache/releases.json'
        cached = news.load_json(path)
        cached['timestamp'] -= news.TTL + 1
        news.atomic_json(path, cached)
        self.feed()
        self.assertEqual(self.fetch_mock.call_count, 2)

    def test_validation(self):
        rows = [release('v1.0.0')]
        for url in ('http://github.com/omacom/omarchy/releases/tag/v2',
                    'https://github.com.evil/omacom/omarchy/releases/tag/v2',
                    'https://github.com/other/repo/releases/tag/v2',
                    'https://github.com/omacom/omarchy/releases/tag/../bad'):
            item = release('v2.0.0')
            item['html_url'] = url
            rows.append(item)
        draft = release('v3.0.0')
        draft['draft'] = True
        rows.append(draft)
        self.assertEqual(len(news.releases_from(rows)), 1)

    def test_atomic_state_failure_preserves_old(self):
        path = self.root / 'state.json'
        news.atomic_json(path, {'old': True})
        with patch.object(news.os, 'replace', side_effect=OSError('failure')):
            with self.assertRaises(OSError):
                news.atomic_json(path, {'new': True})
        self.assertEqual(news.load_json(path), {'old': True})
        self.assertEqual(list(self.root.iterdir()), [path])

    def test_cli_errors_are_json(self):
        import contextlib
        import io
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            news.main(['no-such-command'])
        self.assertTrue(json.loads(out.getvalue())['error'])

    def test_lock_and_persisted_state(self):
        with patch.object(news.fcntl, 'flock', wraps=news.fcntl.flock) as lock:
            self.feed(read_tag='v4.0.7')
        self.assertEqual(lock.call_args.args[1], news.fcntl.LOCK_EX)
        state = news.load_json(self.root / 'state/state.json')
        self.assertEqual(state['observed'], '4.0.6-1')
        self.assertIsNone(state['previous'])
        self.assertEqual(len(state['read']['v4.0.7']), 64)

    def test_http_timeout_and_payload_bound(self):
        # Stop the fixture patch temporarily to exercise only mocked HTTP.
        self.fetch.stop()
        from unittest.mock import MagicMock
        response = MagicMock()
        response.__enter__.return_value = response
        response.read.return_value = b'x' * (news.MAX_BYTES + 1)
        with patch.object(news.urllib.request, 'urlopen', return_value=response) as request:
            with self.assertRaisesRegex(ValueError, 'size limit'):
                news.fetch_releases()
        self.assertEqual(request.call_args.kwargs['timeout'], 8)
        response.read.assert_called_once_with(news.MAX_BYTES + 1)


if __name__ == '__main__':
    unittest.main()
