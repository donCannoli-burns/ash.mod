# ash.mod

A tiny **module contract for KoLmafia ASH**, inspired by the role `go.mod` plays for Go projects.

`ash.mod` gives an ASH library a machine-readable identity, version, entry script, optional smoke test, locked-file metadata, and dependency declarations. `ashmod.ash` reads that contract using normal KoLmafia/ASH facilities.

This is deliberately **not** a second hidden package executor. The descriptor is declarative, module inspection is read-only, and v1 does not download dependencies or execute arbitrary commands from metadata.

## Install with KoLmafia

From the KoLmafia gCLI:

```text
git checkout https://github.com/donCannoli-burns/ash.mod.git main
```

The repository uses KoLmafia's `manifest.json` + `root_directory` packaging pattern, so the installable payload under `kolmafia/` is mapped into the KoLmafia directory while the repository documentation stays at the Git root.

After checkout:

```text
verify ashmod.ash
call ashmod.ash check
call ashmod.ash all
```

The default `scripts/ash.mod` describes the `ashmod` manager itself, so those commands form a self-check.

## Quick use

Inspect the installed manager module:

```text
call ashmod.ash show
call ashmod.ash files
call ashmod.ash graph
call ashmod.ash import
```

Run validation only:

```text
call ashmod.ash check
```

Ask KoLmafia to verify the declared entry:

```text
call ashmod.ash verify
```

Run its declared smoke script:

```text
call ashmod.ash smoke
```

Or run the bounded chain:

```text
call ashmod.ash all
```

## Reference DON Master module

A complete fixture is installed at:

```text
scripts/ashmod/examples/don_master/
```

It is built from **DON Master ASH Lib 0.1.0** and the supplied `don_master_manifest.json`, `DON_MASTER_ASHLIB_README.md`, `don_master_lib.ash`, and exact 204-byte `don_master_smoke.ash`.

Inspect it without running the smoke test:

```text
call ashmod.ash show ashmod/examples/don_master/ash.mod
call ashmod.ash check ashmod/examples/don_master/ash.mod
call ashmod.ash files ashmod/examples/don_master/ash.mod
```

Verify the library:

```text
call ashmod.ash verify ashmod/examples/don_master/ash.mod
```

The DON smoke reads character state and expects a logged-in player, so run this only when that is appropriate:

```text
call ashmod.ash smoke ashmod/examples/don_master/ash.mod
```

## What an `ash.mod` looks like

```text
ashmod 1
module my_library
version 0.1.0
entry my_library.ash
smoke my_library_smoke.ash
namespace my_
importsafe true

file my_library.ash 12345 <sha256>

# dependency example
require some_dependency ^1 some_dependency.ash https://github.com/example/some_dependency
```

Module-owned paths are resolved **relative to the descriptor directory**, so a repository can contain multiple independent ASH modules without hard-coding their installed parent path.

## v1 commands

| Command | Intent |
|---|---|
| `show` | Display module identity, descriptor, entrypoints, and counts |
| `check` | Validate descriptor shape and declared file/dependency presence |
| `files` | Display locked file sizes and SHA-256 metadata |
| `deps` | Display dependency declarations and whether entry scripts are present |
| `graph` | Print the one-level module dependency graph |
| `import` | Print the ASH import line for the module entry |
| `verify` | Execute KoLmafia `verify` on the validated entry path |
| `smoke` | Execute `call` on the validated smoke path |
| `all` | `check` → `verify` → `smoke`, stopping on failure |

## Safety / authority boundary

An `ash.mod` descriptor does not carry executable gCLI strings. The only execution commands supported by the v1 reader are constructed internally from validated `.ash` paths:

```text
verify <entry>
call <smoke>
```

The reader rejects absolute paths, backslashes, and `..` traversal. `show`, `check`, `files`, `deps`, `graph`, and `import` do not intentionally mutate KoL state.

The file hashes are lock/provenance metadata. v1 validates their form and validates file presence, but **does not claim to cryptographically recompute SHA-256 inside ASH**.

## Repository layout

```text
.
├── README.md
├── ASH_MOD_SPEC.md
├── manifest.json
└── kolmafia/
    └── scripts/
        ├── ash.mod
        ├── ashmod.ash
        ├── ashmod_smoke.ash
        └── ashmod/
            └── examples/
                └── don_master/
                    ├── ash.mod
                    ├── don_master_lib.ash
                    ├── don_master_smoke.ash
                    ├── don_master_manifest.json
                    └── DON_MASTER_ASHLIB_README.md
```

## Current scope

v1 provides a module descriptor and validator. It intentionally does **not** yet provide:

- dependency version solving;
- automatic network installation;
- automatic update behavior;
- transitive dependency resolution;
- an `ash.sum` lock file;
- SHA-256 recomputation inside ASH.

Those can be added later without making the descriptor itself an execution authority.

See [`ASH_MOD_SPEC.md`](ASH_MOD_SPEC.md) for the format contract.

## Runtime verification

The repository is packaged for KoLmafia checkout and its descriptors/hashes can be checked statically before publication. The authoritative ASH compatibility test is still the installed KoLmafia runtime:

```text
verify ashmod.ash
call ashmod.ash all
```