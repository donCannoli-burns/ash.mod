script "don_master_lib.ash";

/*
  DON MASTER ASH LIB
  ==================
  Standalone, import-safe KoLmafia ASH utility library.

  Design goals
  ------------
  * Safe to import: no visit_url(), buy(), adventure(), cli_execute(),
    set_property(), stash mutation, or choice submission at top level.
  * Namespace new helpers with don_ to avoid collisions with legacy libraries.
  * Prefer live state reads inside functions; avoid cached global character state.
  * Mutating helpers are explicit and return structured results where practical.
  * Keep compatibility helpers small enough to audit.

  Source/pattern review (reimplemented; not vendored/copied):
  * Zarqon / BatBrain + zlib: records, math/string helpers, explicit utility layers.
  * C2Talon / liba + c2t_lib: modern modular library organization.
  * twistedmage assorted libraries: inventory, quest, crafting and general helpers.
  * Prusias / DicsLibrary + pUpdates: typed preferences, valuation, update notes.
  * Ezandora / Choice Override: composable relay/choice helper philosophy.

  This file intentionally does NOT import those libraries.  It is a clean core
  that can coexist with them and can be imported by scripts that do not have
  those third-party dependencies installed.
*/

string DON_MASTER_VERSION = "0.1.0";
string DON_MASTER_NAME = "DON Master ASH Lib";

// ===========================================================================
// RESULT / STATE RECORDS
// ===========================================================================

record don_result {
    boolean ok;
    string message;
};

record don_action_result {
    boolean ok;
    string action;
    string message;
    int before_adventures;
    int after_adventures;
    int turns_spent;
};

record don_item_result {
    boolean ok;
    item thing;
    int requested;
    int before;
    int after;
    int acquired;
    int spent;
    string message;
};

record don_state {
    string player;
    int ascensions;
    int level;
    int adventures;
    int meat;
    int hp;
    int maxhp;
    int mp;
    int maxmp;
    int fullness;
    int fullness_limit;
    int inebriety;
    int inebriety_limit;
    int spleen;
    int spleen_limit;
    familiar fam;
    location loc;
    boolean aftercore;
    boolean overdrunk;
};

record don_price_quote {
    item thing;
    int value;
    string source;
    float age;
};

// ===========================================================================
// LOGGING
// ===========================================================================

string DON_COLOR_INFO = "5F9EA0";
string DON_COLOR_GOOD = "66CDAA";
string DON_COLOR_CAUTION = "FF00FF";
string DON_COLOR_WARNING = "FFA500";
string DON_COLOR_ERROR = "DC143C";
string DON_COLOR_HEADER = "9400D3";

void don_log(string message) { print(message, DON_COLOR_INFO); }
void don_good(string message) { print(message, DON_COLOR_GOOD); }
void don_caution(string message) { print(message, DON_COLOR_CAUTION); }
void don_warning(string message) { print(message, DON_COLOR_WARNING); }
void don_error(string message) { print(message, DON_COLOR_ERROR); }

void don_breaker() {
    print("|= == == == == == == == == == == == == == == == == == == == == == == == == == == = |", DON_COLOR_HEADER);
}

void don_header(string header) {
    don_breaker();
    print("|- " + header + " -|", DON_COLOR_HEADER);
    don_breaker();
}

void don_sub(string sub) {
    print("|= == == == | " + sub + " | == == == == =|", DON_COLOR_GOOD);
}

void don_footer() { don_breaker(); }

// ===========================================================================
// SMALL PURE HELPERS
// ===========================================================================

float don_clamp(float value, float low, float high) {
    return max(low, min(value, high));
}

int don_clamp(int value, int low, int high) {
    return max(low, min(value, high));
}

string don_rnum(int value) {
    return to_string(value, "%,d");
}

string don_bool_word(boolean value) {
    if (value) return "true";
    return "false";
}

boolean don_blank(string value) {
    return value == "";
}

string don_list_add(string list, string value, string glue) {
    if (value == "") return list;
    if (list == "") return value;
    return list + glue + value;
}

string don_list_add(string list, string value) {
    return don_list_add(list, value, ", ");
}

string don_list_remove(string list, string value, string glue) {
    string[int] bits = split_string(list, glue);
    string out = "";
    foreach i, bit in bits {
        if (bit == value || bit == "") continue;
        out = don_list_add(out, bit, glue);
    }
    return out;
}

string don_list_remove(string list, string value) {
    return don_list_remove(list, value, ", ");
}

void don_wait_minutes(int minutes) {
    if (minutes > 0) wait(minutes * 60);
}

// ===========================================================================
// TYPED PREFERENCE HELPERS
// ===========================================================================

boolean don_pref_exists_or_daily(string property) {
    if (property == "") return false;
    if (starts_with(property, "_")) return true;
    return property_exists(property);
}

string don_pref_string(string property) {
    if (!don_pref_exists_or_daily(property)) {
        don_warning("Unknown preference: " + property);
        return "";
    }
    return get_property(property);
}

int don_pref_int(string property) {
    return don_pref_string(property).to_int();
}

float don_pref_float(string property) {
    return don_pref_string(property).to_float();
}

boolean don_pref_bool(string property) {
    return don_pref_string(property).to_boolean();
}

item don_pref_item(string property) {
    return to_item(don_pref_string(property));
}

location don_pref_location(string property) {
    return to_location(don_pref_string(property));
}

familiar don_pref_familiar(string property) {
    return to_familiar(don_pref_string(property));
}

void don_set_pref(string property, string value) {
    set_property(property, value);
}

void don_set_pref(string property, int value) {
    set_property(property, value.to_string());
}

void don_set_pref(string property, boolean value) {
    set_property(property, value.to_string());
}

// ===========================================================================
// LIVE CHARACTER STATE
// ===========================================================================

boolean don_is_buzzed() { return my_inebriety() >= inebriety_limit(); }
boolean don_is_overdrunk() { return my_inebriety() > inebriety_limit(); }
boolean don_is_full() { return my_fullness() >= fullness_limit(); }
boolean don_is_spleen_full() { return my_spleen_use() >= spleen_limit(); }
boolean don_have_adv() { return my_adventures() > 0; }
boolean don_in_aftercore() { return get_property("kingLiberated").to_boolean(); }
boolean don_has_effect(effect ef) { return have_effect(ef) > 0; }

boolean don_muscle_class() { return my_primestat() == $stat[muscle]; }
boolean don_myst_class() { return my_primestat() == $stat[mysticality]; }
boolean don_moxie_class() { return my_primestat() == $stat[moxie]; }

float don_hp_fraction() {
    if (my_maxhp() <= 0) return 0.0;
    return my_hp().to_float() / my_maxhp().to_float();
}

float don_mp_fraction() {
    if (my_maxmp() <= 0) return 0.0;
    return my_mp().to_float() / my_maxmp().to_float();
}

don_state don_snapshot() {
    don_state s;
    s.player = my_name();
    s.ascensions = my_ascensions();
    s.level = my_level();
    s.adventures = my_adventures();
    s.meat = my_meat();
    s.hp = my_hp();
    s.maxhp = my_maxhp();
    s.mp = my_mp();
    s.maxmp = my_maxmp();
    s.fullness = my_fullness();
    s.fullness_limit = fullness_limit();
    s.inebriety = my_inebriety();
    s.inebriety_limit = inebriety_limit();
    s.spleen = my_spleen_use();
    s.spleen_limit = spleen_limit();
    s.fam = my_familiar();
    s.loc = my_location();
    s.aftercore = don_in_aftercore();
    s.overdrunk = don_is_overdrunk();
    return s;
}

void don_print_snapshot() {
    don_state s = don_snapshot();
    don_header("STATE SNAPSHOT");
    print("Player: " + s.player + " | level " + s.level + " | ascensions " + s.ascensions);
    print("Adventures: " + s.adventures + " | Meat: " + don_rnum(s.meat));
    print("HP: " + s.hp + "/" + s.maxhp + " | MP: " + s.mp + "/" + s.maxmp);
    print("Fullness: " + s.fullness + "/" + s.fullness_limit);
    print("Inebriety: " + s.inebriety + "/" + s.inebriety_limit);
    print("Spleen: " + s.spleen + "/" + s.spleen_limit);
    print("Familiar: " + s.fam + " | Location: " + s.loc);
    print("Aftercore: " + don_bool_word(s.aftercore) + " | Overdrunk: " + don_bool_word(s.overdrunk));
    don_footer();
}

// ===========================================================================
// INVENTORY / OWNERSHIP
// ===========================================================================

int don_inventory_amount(item it) { return item_amount(it); }

int don_owned_amount(item it) {
    return item_amount(it) + equipped_amount(it) + closet_amount(it) + storage_amount(it);
}

int don_owned_amount(item it, boolean include_display, boolean include_shop, boolean include_stash) {
    int amount = don_owned_amount(it);
    if (include_display) amount += display_amount(it);
    if (include_shop) amount += shop_amount(it);
    if (include_stash) amount += stash_amount(it);
    return amount;
}

boolean don_have(item it) {
    return don_owned_amount(it) > 0;
}

boolean don_need(item it) {
    return don_owned_amount(it) == 0;
}

boolean don_possess_inventory_closet_equipped(item it) {
    return item_amount(it) > 0 || closet_amount(it) > 0 || have_equipped(it);
}

int don_familiar_equipped_amount(item it) {
    int amount = 0;
    foreach fam in $familiars[] {
        if (!have_familiar(fam)) continue;
        if (familiar_equipped_equipment(fam) == it) amount += 1;
    }
    return amount;
}

int don_true_owned_amount(item it, boolean include_stash) {
    int amount = don_owned_amount(it, true, true, include_stash);
    amount += don_familiar_equipped_amount(it);
    return amount;
}

boolean don_retrieve(int amount, item it) {
    if (amount <= 0) return true;
    if (item_amount(it) >= amount) return true;
    return retrieve_item(amount, it);
}

don_item_result don_acquire(int amount, item it, int max_price) {
    don_item_result result;
    result.thing = it;
    result.requested = amount;
    result.before = item_amount(it);
    result.after = result.before;

    if (amount <= 0) {
        result.ok = true;
        result.message = "Nothing requested.";
        return result;
    }

    if (item_amount(it) < amount) retrieve_item(amount, it);

    int missing = amount - item_amount(it);
    if (missing > 0 && max_price > 0 && can_interact() && is_tradeable(it)) {
        int meat_before = my_meat();
        buy(missing, it, max_price);
        result.spent = max(0, meat_before - my_meat());
    }

    result.after = item_amount(it);
    result.acquired = max(0, result.after - result.before);
    result.ok = result.after >= amount;
    if (result.ok) result.message = "Acquired requested amount of " + it + ".";
    else result.message = "Could not acquire requested amount of " + it + ".";
    return result;
}

don_item_result don_acquire(int amount, item it) {
    return don_acquire(amount, it, 0);
}

boolean don_use_any(int amount, item it) {
    if (amount <= 0) return true;
    if (item_amount(it) < amount && !retrieve_item(amount, it)) return false;
    if (use(amount, it)) return true;
    if (eat(amount, it)) return true;
    if (drink(amount, it)) return true;
    return false;
}

// ===========================================================================
// PRICING / VALUE
// ===========================================================================

int don_value_of_adventure() {
    int voa = get_property("valueOfAdventure").to_int();
    if (voa <= 0) return 5000;
    return voa;
}

don_price_quote don_price(item it, float max_historical_age) {
    don_price_quote q;
    q.thing = it;
    q.age = historical_age(it);

    if (!is_tradeable(it)) {
        q.value = max(0, autosell_price(it));
        q.source = "autosell/untradeable";
        return q;
    }

    if (historical_price(it) > 0 && q.age <= max_historical_age) {
        q.value = historical_price(it);
        q.source = "historical";
        return q;
    }

    int mall = mall_price(it);
    if (mall > 0) {
        q.value = mall;
        q.source = "mall";
        return q;
    }

    if (historical_price(it) > 0) {
        q.value = historical_price(it);
        q.source = "stale historical";
        return q;
    }

    q.value = max(0, autosell_price(it));
    q.source = "autosell fallback";
    return q;
}

don_price_quote don_price(item it) {
    return don_price(it, 7.0);
}

int don_item_value(item it) {
    don_price_quote q = don_price(it);
    return max(q.value, autosell_price(it));
}

boolean don_price_at_most(item it, int max_price) {
    if (max_price <= 0) return false;
    return don_price(it).value <= max_price;
}

int don_profit(item output, item input, int input_count) {
    return don_item_value(output) - (don_item_value(input) * input_count);
}

// ===========================================================================
// FAMILIARS / EQUIPMENT / OUTFITS
// ===========================================================================

boolean don_use_familiar(familiar fam) {
    if (!have_familiar(fam)) return false;
    use_familiar(fam);
    return my_familiar() == fam;
}

boolean don_equip_familiar_default(familiar fam) {
    if (!have_familiar(fam)) return false;
    familiar old = my_familiar();
    use_familiar(fam);
    item gear = familiar_equipment(fam);
    boolean ok = true;

    if (gear != $item[none]) {
        if (!retrieve_item(1, gear)) ok = false;
        else ok = equip($slot[familiar], gear);
    }

    if (old != $familiar[none] && old != fam) use_familiar(old);
    return ok;
}

boolean don_train_familiar(familiar fam, int base_weight_goal) {
    if (!have_familiar(fam)) return false;
    if (familiar_weight(fam) >= base_weight_goal) return true;
    familiar old = my_familiar();
    use_familiar(fam);
    boolean ok = cli_execute("train base " + base_weight_goal);
    if (old != $familiar[none] && old != fam) use_familiar(old);
    return ok && familiar_weight(fam) >= base_weight_goal;
}

boolean don_save_outfit(string name) {
    if (name == "") return false;
    return cli_execute("outfit save " + name);
}

boolean don_wear_outfit(string name) {
    if (name == "") return false;
    return outfit(name);
}

boolean don_unequip(item it) {
    if (!have_equipped(it)) return true;
    return cli_execute("unequip " + it);
}

// ===========================================================================
// EFFECTS / SONGS / RECOVERY
// ===========================================================================

int don_song_limit() {
    int limit = 3;
    if (boolean_modifier("Four Songs")) limit += 1;
    limit += numeric_modifier("Additional Song").to_int();
    return limit;
}

int don_song_count() {
    int count = 0;
    int[effect] active = my_effects();
    foreach ef, turns in active {
        skill source = to_skill(ef);
        if (source != $skill[none] && source.class == $class[Accordion Thief] && source.buff) count += 1;
    }
    return count;
}

boolean don_recover_hp(float target_fraction) {
    target_fraction = don_clamp(target_fraction, 0.0, 1.0);
    int target = ceil(my_maxhp() * target_fraction).to_int();
    if (my_hp() >= target) return true;
    return restore_hp(target);
}

boolean don_recover_mp(float target_fraction) {
    target_fraction = don_clamp(target_fraction, 0.0, 1.0);
    int target = ceil(my_maxmp() * target_fraction).to_int();
    if (my_mp() >= target) return true;
    return restore_mp(target);
}

// ===========================================================================
// QUEST / CHOICE STATE HELPERS
// ===========================================================================

int don_quest_step(string quest_property) {
    string state = get_property(quest_property);
    if (state == "" || state == "unstarted") return -1;
    if (state == "started") return 0;
    if (state == "finished") return 999;
    if (starts_with(state, "step")) return substring(state, 4).to_int();
    return 0;
}

boolean don_quest_started(string quest_property) {
    return don_quest_step(quest_property) >= 0;
}

boolean don_quest_finished(string quest_property) {
    return get_property(quest_property) == "finished";
}

boolean don_quest_at_least(string quest_property, int step) {
    int current = don_quest_step(quest_property);
    if (current == 999) return true;
    return current >= step;
}

int don_choice_id() {
    return get_property("lastChoice").to_int();
}

boolean don_in_choice() {
    return handling_choice();
}

don_result don_choice(int expected_choice, int option) {
    don_result result;
    if (!handling_choice()) {
        result.ok = false;
        result.message = "Not currently handling a choice.";
        return result;
    }

    int actual = don_choice_id();
    if (expected_choice > 0 && actual != expected_choice) {
        result.ok = false;
        result.message = "Choice mismatch: expected " + expected_choice + ", found " + actual + ".";
        return result;
    }

    run_choice(option);
    result.ok = !handling_choice() || don_choice_id() != actual;
    if (result.ok) result.message = "Choice option submitted.";
    else result.message = "Choice submission did not leave/change the current choice.";
    return result;
}

// ===========================================================================
// BOUNDED ADVENTURING / COMMAND EXECUTION
// ===========================================================================

don_action_result don_adventure_bounded(int turns, location loc) {
    don_action_result result;
    result.action = "adventure " + turns + " " + loc;
    result.before_adventures = my_adventures();

    if (turns <= 0) {
        result.ok = true;
        result.after_adventures = my_adventures();
        result.message = "No turns requested.";
        return result;
    }
    if (!can_adventure(loc)) {
        result.ok = false;
        result.after_adventures = my_adventures();
        result.message = "Cannot adventure at " + loc + ".";
        return result;
    }

    int completed = 0;
    while (completed < turns && my_adventures() > 0 && can_adventure(loc)) {
        int before = my_adventures();
        if (!adventure(1, loc)) break;
        completed += 1;
    }

    result.after_adventures = my_adventures();
    result.turns_spent = max(0, result.before_adventures - result.after_adventures);
    result.ok = completed >= turns;
    result.message = "Requested " + turns + " bounded action(s); completed " + completed + " and observed " + result.turns_spent + " adventure(s) spent.";
    return result;
}

don_result don_cli(string command) {
    don_result result;
    if (command == "") {
        result.ok = false;
        result.message = "Empty command.";
        return result;
    }
    result.ok = cli_execute(command);
    if (result.ok) result.message = "Command accepted: " + command;
    else result.message = "Command failed: " + command;
    return result;
}

boolean don_require(boolean condition, string message) {
    if (condition) return true;
    abort(message);
    return false;
}

// ===========================================================================
// ZAP WAND / ROLLOVER / DATE HELPERS
// ===========================================================================

item don_find_wand() {
    item wand = get_zap_wand();
    if (wand != $item[none]) return wand;
    for id from 1268 to 1272 {
        item candidate = to_item(id);
        if (don_owned_amount(candidate) > 0) return candidate;
    }
    return $item[none];
}

boolean don_wand_usable(item wand) {
    if (wand == $item[none]) return false;
    string page = visit_url("wand.php?whichwand=" + wand.id);
    if (contains_text(page, "feels warm")) return false;
    if (contains_text(page, "be careful")) return false;
    return true;
}

int don_minutes_to_rollover() {
    string source = visit_url("charpane.php");
    string roll_marker = "var rollover = ";
    string now_marker = "var rightnow = ";
    int roll_start = index_of(source, roll_marker);
    int now_start = index_of(source, now_marker);
    if (roll_start < 0 || now_start < 0) return -1;

    roll_start += length(roll_marker);
    now_start += length(now_marker);
    int roll_end = index_of(source, ";", roll_start);
    int now_end = index_of(source, ";", now_start);
    if (roll_end < 0 || now_end < 0) return -1;

    int rollover = substring(source, roll_start, roll_end).to_int();
    int rightnow = substring(source, now_start, now_end).to_int();
    return max(0, (rollover - rightnow) / 60);
}

string don_day() {
    return format_date_time("yyyyMMdd", today_to_string(), "EEEE");
}

// ===========================================================================
// LIGHTWEIGHT COMBAT HELPERS
// ===========================================================================

string don_element_color(element el) {
    switch (el) {
        case $element[hot]: return "red";
        case $element[cold]: return "blue";
        case $element[spooky]: return "gray";
        case $element[sleaze]: return "purple";
        case $element[stench]: return "green";
    }
    return "black";
}

string don_default_combat_action() {
    if (have_skill($skill[Saucegeyser]) && my_mp() >= mp_cost($skill[Saucegeyser])) return "skill Saucegeyser";
    return "attack";
}

float don_monster_hp_now() { return monster_hp(); }
float don_monster_attack_now() { return monster_attack(); }
float don_monster_defense_now() { return monster_defense(); }

// ===========================================================================
// SIMPLE LOCAL UPDATE NOTES (pUpdates-inspired, namespaced)
// ===========================================================================

string don_updates_file(string script_name) {
    return "don_master_updates_" + script_name + ".txt";
}

void don_updates_init(string script_name) {
    if (script_name == "") return;
    string[int] updates;
    updates[-1] = "0";
    updates[0] = DON_MASTER_NAME + " update tracking initialized for " + script_name;
    map_to_file(updates, don_updates_file(script_name));
}

void don_updates_add(string script_name, string update_text) {
    if (script_name == "" || update_text == "") return;
    string[int] updates;
    file_to_map(don_updates_file(script_name), updates);
    if (!(updates contains -1)) updates[-1] = "0";
    int version = updates[-1].to_int() + 1;
    updates[-1] = version;
    updates[version] = update_text;
    map_to_file(updates, don_updates_file(script_name));
}

void don_updates_check(string script_name) {
    if (script_name == "") return;
    string[int] updates;
    file_to_map(don_updates_file(script_name), updates);
    if (!(updates contains -1)) return;

    string property = "donMasterUpdates_" + script_name + "_seen";
    int latest = updates[-1].to_int();
    int seen = get_property(property).to_int();
    if (seen >= latest) return;

    don_header(script_name + " updates");
    for i from max(0, seen + 1) to latest {
        if (updates contains i) print(i + " - " + updates[i]);
    }
    set_property(property, latest);
    don_footer();
}

// ===========================================================================
// COMPATIBILITY SHIMS FOR DON_UTIL CALLERS
// ===========================================================================
// These intentionally preserve names commonly used by the existing personal
// scripts while delegating to the safer/dynamic implementations above.

boolean needToAcquireItem(item x) { return don_need(x); }
boolean needToAcquirePullItem(item x) { return available_amount(x) + storage_amount(x) == 0; }
void WaitMinutes(int minutes) { don_wait_minutes(minutes); }
boolean MuscleClass() { return don_muscle_class(); }
boolean MoxieClass() { return don_moxie_class(); }
boolean MysticalityClass() { return don_myst_class(); }

void getanduse(int n, item it) {
    if (!don_use_any(n, it)) don_warning("Could not use/eat/drink " + n + " " + it + ".");
}

boolean save_outfit(string outfitlabel) { return don_save_outfit(outfitlabel); }
void trainfam(familiar pet, int goal) { don_train_familiar(pet, goal); }
int FindWand() { return don_find_wand().id; }
boolean WandUseable(int wand) { return don_wand_usable(to_item(wand)); }
int MinutesToRollover() { return don_minutes_to_rollover(); }
string Day() { return don_day(); }

string saucegeyserAll(int round, monster opp, string text) {
    return don_default_combat_action();
}

// ===========================================================================
// SELF-DESCRIPTION / SMOKE TEST
// ===========================================================================

void don_master_about() {
    don_header(DON_MASTER_NAME + " v" + DON_MASTER_VERSION);
    print("Import-safe standalone utility layer.");
    print("Core areas: state, typed prefs, inventory, pricing, familiar/outfit, recovery, quest/choice, bounded actions, combat helpers, local update notes.");
    print("No third-party library is required merely to import this file.");
    don_footer();
}

boolean don_master_smoke() {
    boolean ok = true;
    don_state s = don_snapshot();
    if (s.player == "") ok = false;
    if (don_clamp(5, 0, 3) != 3) ok = false;
    if (don_clamp(-1, 0, 3) != 0) ok = false;
    if (don_list_add("a", "b") != "a, b") ok = false;
    if (don_bool_word(true) != "true") ok = false;
    if (ok) don_good(DON_MASTER_NAME + " smoke test PASS");
    else don_error(DON_MASTER_NAME + " smoke test FAIL");
    return ok;
}