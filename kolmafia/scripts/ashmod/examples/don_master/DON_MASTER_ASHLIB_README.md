# DON Master ASH Lib

`don_master_lib.ash` is a standalone, import-safe KoLmafia ASH utility layer built to replace the common pattern of importing several overlapping legacy helper libraries into every personal script.

## Install

Copy `don_master_lib.ash` into KoLmafia's `scripts/` directory, then import it from another ASH script:

```ash
import <don_master_lib.ash>;
```

Recommended local checks:

```text
verify don_master_lib.ash
call don_master_smoke.ash
```

## Design rules

1. **Importing the library does not intentionally mutate KoL state.** There are no top-level `visit_url`, `buy`, `adventure`, `set_property`, `cli_execute`, stash, or choice actions.
2. **Live state is read at call time.** Character state is not cached into global booleans that silently go stale.
3. **New public helpers use the `don_` namespace.** This makes the library much safer to use beside ZLib, DicsLibrary, BatBrain, old QuestLib/FunctionLib scripts, or newer libraries.
4. **Mutating operations look like mutations.** Examples: `don_acquire`, `don_choice`, `don_adventure_bounded`, `don_cli`, `don_set_pref`.
5. **Important mutations return structured results where practical.** Callers can inspect `ok`, messages, before/after values, turns, and Meat spent instead of trusting only a printed string.
6. **Compatibility shims are intentionally small.** Common old Don utility names remain available, but new code should prefer the namespaced API.

## Major sections

| Area | Primary API |
|---|---|
| Logging | `don_log`, `don_good`, `don_warning`, `don_header` |
| Pure helpers | `don_clamp`, `don_rnum`, `don_list_add`, `don_list_remove` |
| Preferences | `don_pref_string/int/float/bool/item/location/familiar`, `don_set_pref` |
| State | `don_snapshot`, `don_print_snapshot`, `don_is_overdrunk`, `don_have_adv` |
| Inventory | `don_owned_amount`, `don_true_owned_amount`, `don_retrieve`, `don_acquire`, `don_use_any` |
| Value | `don_price`, `don_item_value`, `don_profit`, `don_value_of_adventure` |
| Familiar/outfit | `don_use_familiar`, `don_train_familiar`, `don_save_outfit`, `don_wear_outfit` |
| Recovery/effects | `don_has_effect`, `don_song_count`, `don_song_limit`, `don_recover_hp/mp` |
| Quest/choice | `don_quest_step`, `don_quest_at_least`, `don_choice` |
| Execution | `don_adventure_bounded`, `don_cli`, `don_require` |
| Wand/time | `don_find_wand`, `don_wand_usable`, `don_minutes_to_rollover`, `don_day` |
| Combat primitives | `don_default_combat_action`, monster stat reads, elemental display helper |
| Update notes | `don_updates_init`, `don_updates_add`, `don_updates_check` |

## Compatibility shims

Current aliases retained for older Don scripts:

```text
needToAcquireItem
needToAcquirePullItem
WaitMinutes
MuscleClass
MoxieClass
MysticalityClass
getanduse
save_outfit
trainfam
FindWand
WandUseable
MinutesToRollover
Day
saucegeyserAll
```

The intent is to migrate callers gradually rather than break every personal script at once.

## Source-pattern map

This artifact is a new implementation. It does **not** vendor the listed projects into one copied file. Their architectures and public patterns were reviewed to decide what belongs in a modern master utility layer.

| Reviewed source | Pattern carried forward |
|---|---|
| BatBrain.ash | Records, explicit combat/state helpers, calculated values instead of magic globals |
| zlib.ash | Small broadly reusable helpers, formatting/list/math utilities |
| C2Talon/liba | Narrow modern modules and avoiding a single implicit global-state blob |
| C2Talon/c2t_lib | General personal-script utility coverage with current KoLmafia idioms |
| FunctionLib.ash | Inventory/familiar/general convenience layer |
| SmashLib.ash | Value/crafting-oriented utility concept; master lib exposes generic valuation instead of reproducing old smash tables |
| helper.ash | Common player-state conveniences |
| QuestLib.ash | Quest state normalization and small quest predicates |
| sims_lib.ash | Reusable personal automation helpers, but without hidden import-time actions |
| Prusias pUpdates | Tiny local change/update stream per script |
| DicsLibrary.ash | Typed property access, ownership/value thinking, live state reads |
| Choice-Override | Composable choice/relay support and explicit boundaries between presentation and action |
| relay_zlib_manager.ash | Human-manageable settings philosophy; a separate UI can be layered on this library later |

## Why BatBrain itself was not folded into the core

BatBrain is a combat reasoning engine, not merely a helper file. Pulling its complete historical combat model into a generic library would create a large second authority for modern combat mechanics and substantial symbol/dependency collision risk. The master library therefore takes the *architecture*—records, explicit calculations, combat primitives—but leaves deep combat modeling to a dedicated combat module.

That gives a cleaner future split:

```text
don_master_lib.ash        generic utility/state/value/execution primitives
       ↓
don_combat_lib.ash        optional modern BatBrain-like combat reasoning
       ↓
don_quest_lib.ash         optional high-level quest orchestration
       ↓
personal scripts          chowDown / yeti / farming / ascension workflows
```

## Migration example

Old:

```ash
if (needToAcquireItem($item[bucket of wine])) buy(1, $item[bucket of wine], 15000);
```

New:

```ash
don_item_result wine = don_acquire(1, $item[bucket of wine], 15000);
if (!wine.ok) abort(wine.message);
```

The second form gives the caller an explicit result and keeps the price ceiling next to the acquisition request.

## Runtime authority

The artifact was structurally checked here, but the authoritative compatibility check is your installed KoLmafia runtime. Run `verify don_master_lib.ash` locally. If your runtime reports a changed/deprecated built-in, adjust that wrapper in one place instead of patching every consuming script.