#!/usr/bin/env python3
"""Exercise the cache key with committed source changes and real gitlinks."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('core-build-key.py').resolve()


class CoreBuildKeyTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        self.git('init', '-q')
        self.git('config', 'user.name', 'Cache fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.env = dict(os.environ, CORE='smstang', BOARD='console138k',
                        TANGCORE_VARIANT='standard', GOWIN_VERSION='1.9.11.03',
                        GOWIN_SHA256='test-checksum', BUILD_RECIPE_VERSION='1',
                        RUNNER_OS='Linux', RUNNER_ARCH='X64',
                        GITHUB_OUTPUT=str(self.root / 'outputs'),
                        GITHUB_STEP_SUMMARY=str(self.root / 'summary'))
        self.commit('src/top.v', 'module top; endmodule\n')

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.source), *args])

    def commit(self, path, text):
        target = self.source / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
        self.git('add', '.')
        self.git('commit', '-qm', 'cache fixture')

    def key(self, **changes):
        Path(self.env['GITHUB_OUTPUT']).write_text('')
        subprocess.run(['python3', str(SCRIPT), str(self.source)],
                       env=dict(self.env, **changes), check=True,
                       stdout=subprocess.DEVNULL)
        return Path(self.env['GITHUB_OUTPUT']).read_text()

    def test_non_build_changes(self):
        before = self.key()
        for path in ('sim/test.v', 'tools/helper.py', 'docs/guide.txt',
                     'README.md', 'file with spaces.md'):
            with self.subTest(path=path):
                self.commit(path, 'non-build change\n')
                self.assertEqual(self.key(), before)

    def test_sources_and_submodules(self):
        before = self.key()
        self.commit('src/top.v', 'module top; wire changed; endmodule\n')
        self.assertNotEqual(self.key(), before)
        before = self.key()
        self.git('update-index', '--add', '--cacheinfo',
                 '160000,' + '1' * 40 + ',vendor')
        self.git('commit', '-qm', 'gitlink fixture')
        self.assertNotEqual(self.key(), before)
        before = self.key()
        self.git('update-index', '--cacheinfo', '160000,' + '2' * 40 + ',vendor')
        self.git('commit', '-qm', 'changed gitlink fixture')
        self.assertNotEqual(self.key(), before)

    def test_platform_toolchain_and_recipe(self):
        before = self.key()
        for name in ('CORE', 'BOARD', 'TANGCORE_VARIANT', 'GOWIN_VERSION',
                     'GOWIN_SHA256', 'BUILD_RECIPE_VERSION', 'RUNNER_OS', 'RUNNER_ARCH'):
            with self.subTest(name=name):
                self.assertNotEqual(self.key(**{name: 'changed'}), before)


if __name__ == '__main__':
    unittest.main()
