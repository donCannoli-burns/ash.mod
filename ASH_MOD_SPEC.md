# `ash.mod` v1 — KoLmafia ASH module descriptor

`ash.mod` is a small declarative module contract for KoLmafia ASH libraries. It gives an ASH project a stable module ID, version, entry script, optional smoke test, file lock metadata, and dependency declarations without pretending KoLmafia already has a native package resolver.

The companion `ashmod.ash` reader uses existing KoLmafia surfaces: ASH `import`, `file_to_array`, and the gCLI `verify` / `call` commands.

## Goals

- one machine-readable module contract per ASH module;
- descriptors remain non-executable;
- module-owned paths are relative to the descriptor directory;
- dependencies can be declared before automatic dependency solving exists;
- validation and execution are separate operations;
- no network fetch or update behavior is hidden in a descriptor.

## Grammar

Blank lines and lines beginning with `#` are ignored.

```text
ashmod 1
module <module-id>
version <version>
entry <relative-script.ash>
smoke <relative-smoke.ash>              # optional
manifest <relative-file>                # optional
readme <relative-file>                  # optional
namespace <prefix>                      # optional
importsafe true|false                   # optional

file <relative-file> <bytes> <sha256>
require <module-id> <constraint> <entry-script.ash> [source-url]
```

Tokens may not contain spaces in v1.

### Path semantics

`entry`, `smoke`, `manifest`, `readme`, and `file` paths are owned by the module and resolve relative to the directory containing that `ash.mod`.

`require ... <entry-script.ash>` is different: the dependency entry is looked up through KoLmafia's normal scripts search path. That lets one installed module depend on another installed module without assuming the dependency lives beneath the caller's directory.

Absolute paths, backslashes, and `..` path traversal are rejected by `ashmod.ash`.

## Execution boundary

An `ash.mod` file cannot contain an arbitrary command. `ashmod.ash` has read-only commands for inspection/validation, and only two execution primitives:

```text
verify <validated module entry>
call <validated module smoke script>
```

Those commands are constructed by the manager from validated `.ash` paths; they are not read as command strings from the descriptor.

## Commands

```text
call ashmod.ash show [descriptor]
call ashmod.ash check [descriptor]
call ashmod.ash files [descriptor]
call ashmod.ash deps [descriptor]
call ashmod.ash graph [descriptor]
call ashmod.ash import [descriptor]
call ashmod.ash verify [descriptor]
call ashmod.ash smoke [descriptor]
call ashmod.ash all [descriptor]
```

The default descriptor is `ash.mod`.

`show`, `check`, `files`, `deps`, `graph`, and `import` do not intentionally mutate KoL state. `verify` asks KoLmafia to parse the declared entry. `smoke` explicitly executes the declared smoke script. `all` performs check → verify → smoke and stops on failure.

## File locks

A `file` directive records byte length and a SHA-256 digest:

```text
file lib/example.ash 1234 0123456789abcdef...
```

v1 validates descriptor syntax and file presence. KoLmafia ASH does not provide the cryptographic primitive used here, so `ashmod.ash` does **not** claim to recompute SHA-256 itself. Hash recomputation remains an external packaging/release check.

## Dependencies

Example:

```text
require zlib ^1 zlib.ash https://github.com/zarqon/kolmafia-zlib
```

In v1, the version constraint is opaque metadata. The reader reports the dependency and checks whether the declared entry can be found. It does not choose versions or download anything.

A future resolver can build on this contract with explicit source pinning, version selection, an `ash.sum`-style lock file, and a separately authorized install/update boundary.

## KoLmafia Git checkout packaging

A repository can keep ordinary project files at its Git root and expose only installable KoLmafia files with a repository `manifest.json`:

```json
{
  "root_directory": "kolmafia"
}
```

Then arrange the install payload below `kolmafia/`, for example:

```text
kolmafia/
└── scripts/
    ├── ash.mod
    ├── ashmod.ash
    └── ashmod_smoke.ash
```

This repository uses that layout.

## Reference fixture

`kolmafia/scripts/ashmod/examples/don_master/` is the reference v1 module. It is based on DON Master ASH Lib `0.1.0` and demonstrates a module-local descriptor with an entry script, smoke test, documentation pointer, manifest pointer, and locked files.