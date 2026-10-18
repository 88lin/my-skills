#!/usr/bin/env node
// Real Git fixtures; no network and no writes outside a disposable temp directory.
import assert from 'node:assert/strict'
import { execFileSync, spawnSync } from 'node:child_process'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { test, after } from 'node:test'

const cli = fileURLToPath(new URL('./img2threejs.mjs', import.meta.url))
const root = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'img2threejs-test-')))
after(() => fs.rmSync(root, { recursive: true, force: true }))
const realGit = execFileSync('which', ['git'], { encoding: 'utf8' }).trim()
const repo = path.join(root, 'source')
fs.mkdirSync(repo)
const gitEnv = { ...process.env, GIT_CONFIG_NOSYSTEM: '1', GIT_CONFIG_GLOBAL: '/dev/null',
  GIT_AUTHOR_NAME: 'Test', GIT_AUTHOR_EMAIL: 'test@example.invalid',
  GIT_COMMITTER_NAME: 'Test', GIT_COMMITTER_EMAIL: 'test@example.invalid' }
function git(...args) {
  return execFileSync(realGit, args, { cwd: repo, env: gitEnv, encoding: 'utf8' }).trim()
}
git('init', '--quiet')
const commits = {}
for (const version of ['1.5.2', '2.0.0-beta.2', '2.0.0-beta.10', '2.0.0']) {
  fs.writeFileSync(path.join(repo, 'SKILL.md'), `---\nname: img2threejs\nversion: ${version}\n---\nfixture ${version}\n`)
  fs.mkdirSync(path.join(repo, 'forge'), { recursive: true })
  fs.writeFileSync(path.join(repo, 'forge', 'fixture.py'), `VERSION = '${version}'\n`)
  git('add', '.')
  git('commit', '--quiet', '-m', version)
  git('tag', `v${version}`)
  commits[version] = git('rev-parse', 'HEAD')
}
const tools = path.join(root, 'tools')
fs.mkdirSync(tools)
// Only redirect the remote URL; fetch, checkout, SHA and status use the real Git binary.
fs.writeFileSync(path.join(tools, 'git'), `#!${process.execPath}\nimport { spawnSync } from 'node:child_process';\nconst args = process.argv.slice(2).map(a => a === 'https://github.com/img2threejs/img2threejs.git' ? process.env.FIXTURE_REPO : a);\nconst result = spawnSync(process.env.REAL_GIT, args, {stdio:'inherit'});\nprocess.exit(result.status ?? 1);\n`, { mode: 0o755 })
// Extensionless executables default to CommonJS outside a package.
fs.writeFileSync(path.join(tools, 'package.json'), '{"type":"module"}')
let sequence = 0
function home(hosts = ['claude']) {
  const dir = path.join(root, `home-${sequence++}`)
  fs.mkdirSync(dir)
  for (const host of hosts) fs.mkdirSync(host === 'opencode' ? path.join(dir, 'xdg', 'opencode') : path.join(dir, `.${host}`), { recursive: true })
  return dir
}
function skills(dir, host = 'claude') {
  return host === 'opencode' ? path.join(dir, 'xdg', 'opencode', 'skills') : path.join(dir, `.${host}`, 'skills')
}
function run(dir, ...args) {
  return spawnSync(process.execPath, [cli, ...args], { encoding: 'utf8', timeout: 20000,
    env: { ...gitEnv, HOME: dir, XDG_CONFIG_HOME: path.join(dir, 'xdg'),
      PATH: `${tools}${path.delimiter}${process.env.PATH}`, FIXTURE_REPO: repo, REAL_GIT: realGit } })
}
function success(result) {
  assert.equal(result.status, 0, result.stderr || result.error?.message)
}
function installed(dir, host = 'claude') {
  const link = path.join(skills(dir, host), 'img2threejs')
  assert.ok(fs.lstatSync(link).isSymbolicLink())
  return fs.realpathSync(link)
}

test('unknown commands and missing values fail without a host', () => {
  const dir = home([])
  assert.equal(run(dir, 'unknown').status, 3)
  assert.equal(run(dir, 'install', '--host').status, 3)
  assert.equal(run(dir, 'install', '--ref', '--dry-run').status, 3)
})

test('branches, short SHAs and malformed tags are refused', () => {
  const dir = home()
  for (const ref of ['main', '123abcd', 'v01.2.3', 'v2.0.0-beta..1', 'v2.0.0-01']) {
    assert.equal(run(dir, 'install', '--ref', ref).status, 2, ref)
  }
  assert.ok(!fs.existsSync(path.join(dir, '.img2threejs')))
})

test('no detected hosts or an unknown host is refused', () => {
  assert.equal(run(home([]), 'install').status, 2)
  assert.equal(run(home(), 'install', '--host', 'invalid').status, 3)
})

test('dry-run is offline and does not modify the home', () => {
  const dir = home()
  const before = fs.readdirSync(dir)
  success(run(dir, 'install', '--dry-run'))
  assert.deepEqual(fs.readdirSync(dir), before)
  assert.ok(!fs.existsSync(skills(dir)))
})

test('explicit host installs the full pinned skill without linking other hosts', () => {
  const dir = home(['claude', 'codex', 'hermes', 'opencode'])
  success(run(dir, 'install', '--host', 'claude'))
  const target = installed(dir)
  assert.match(fs.readFileSync(path.join(target, 'SKILL.md'), 'utf8'), /version: 2\.0\.0\n/)
  assert.equal(fs.readFileSync(path.join(target, 'forge', 'fixture.py'), 'utf8'), "VERSION = '2.0.0'\n")
  assert.equal(execFileSync(realGit, ['rev-parse', 'HEAD'], { cwd: target, encoding: 'utf8' }).trim(), commits['2.0.0'])
  for (const host of ['codex', 'hermes', 'opencode']) assert.ok(!fs.existsSync(skills(dir, host)))
})

test('all four hosts share one checkout; reinstallation is idempotent', () => {
  const dir = home(['claude', 'codex', 'hermes', 'opencode'])
  success(run(dir, 'install'))
  const target = installed(dir)
  for (const host of ['codex', 'hermes', 'opencode']) assert.equal(installed(dir, host), target)
  success(run(dir, 'install'))
  assert.equal(installed(dir), target)
  assert.deepEqual(fs.readdirSync(path.join(dir, '.img2threejs', 'releases')), [commits['2.0.0']])
  const report = run(dir, 'doctor')
  success(report)
  assert.match(report.stdout, /managed →/)
})

test('update advances a pinned checkout and refuses tag or SHA downgrades', () => {
  const dir = home()
  success(run(dir, 'install', '--ref', 'v1.5.2'))
  success(run(dir, 'update'))
  const target = installed(dir)
  for (const ref of ['v1.5.2', commits['1.5.2']]) {
    const result = run(dir, 'update', '--ref', ref)
    assert.equal(result.status, 2, result.stderr)
    assert.match(result.stderr, /downgrade/)
    assert.equal(installed(dir), target)
  }
  assert.ok(!fs.readdirSync(path.join(dir, '.img2threejs', 'releases')).some(n => n.startsWith('.staging-')))
})

test('prerelease precedence uses numeric identifiers and stable beats prerelease', () => {
  const dir = home()
  success(run(dir, 'install', '--ref', 'v2.0.0-beta.2'))
  success(run(dir, 'update', '--ref', 'v2.0.0-beta.10'))
  assert.equal(run(dir, 'update', '--ref', 'v2.0.0-beta.2').status, 2)
  success(run(dir, 'update', '--ref', commits['2.0.0']))
  assert.equal(run(dir, 'update', '--ref', 'v2.0.0-beta.10').status, 2)
})

test('unmanaged directories and symlinks are preserved; no hosts partially installed', () => {
  for (const kind of ['directory', 'symlink']) {
    const dir = home(['claude', 'codex'])
    fs.mkdirSync(skills(dir, 'codex'), { recursive: true })
    const link = path.join(skills(dir, 'codex'), 'img2threejs')
    if (kind === 'directory') {
      fs.mkdirSync(link)
      fs.writeFileSync(path.join(link, 'keep'), 'user data')
    } else fs.symlinkSync(path.join(dir, 'nonexistent'), link)
    assert.equal(run(dir, 'install').status, 2)
    assert.ok(!fs.existsSync(skills(dir)))
    if (kind === 'directory') assert.equal(fs.readFileSync(path.join(link, 'keep'), 'utf8'), 'user data')
    else assert.equal(fs.readlinkSync(link), path.join(dir, 'nonexistent'))
    assert.ok(!fs.existsSync(path.join(dir, '.img2threejs')))
  }
})

test('a missing ref preserves the existing installation and cleans staging', () => {
  const dir = home()
  success(run(dir, 'install'))
  const target = installed(dir)
  assert.equal(run(dir, 'update', '--ref', 'v99.0.0').status, 1)
  assert.equal(installed(dir), target)
  assert.deepEqual(fs.readdirSync(path.join(dir, '.img2threejs', 'releases')), [commits['2.0.0']])
})

test('local edits in an existing managed release are never overwritten', () => {
  const dir = home()
  success(run(dir, 'install'))
  const target = installed(dir)
  fs.writeFileSync(path.join(target, 'forge', 'fixture.py'), 'user edit\n')
  assert.equal(run(dir, 'install').status, 2)
  assert.equal(fs.readFileSync(path.join(target, 'forge', 'fixture.py'), 'utf8'), 'user edit\n')
})
