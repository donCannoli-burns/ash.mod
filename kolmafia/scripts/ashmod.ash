script "ashmod.ash";

/*
  ashmod.ash
  ==========
  Minimal, KoLmafia-native module descriptor reader for ash.mod v1.

  Design:
  * module identity/version/entry metadata for ASH libraries;
  * module-owned paths resolve relative to the descriptor directory;
  * no mutation on import or on show/check/files/deps/graph/import;
  * verify/smoke construct only fixed gCLI verbs from validated .ash paths;
  * dependencies are declared and presence-checked in v1, not downloaded.
*/

record ashmod_file_record {
    string path;
    int bytes;
    string sha256;
};

record ashmod_require_record {
    string module_id;
    string constraint;
    string entry;
    string source;
};

string[string] ASHMOD_FIELDS;
ashmod_file_record[int] ASHMOD_FILES;
ashmod_require_record[int] ASHMOD_REQUIRES;
string[int] ASHMOD_ERRORS;
string ASHMOD_DESCRIPTOR_PATH = "";
string ASHMOD_BASE_DIR = "";

string ashmod_trim(string value) {
    int first = 0;
    int last = length(value);

    while (first < last) {
        string c = char_at(value, first);
        if (c != " " && c != "\t" && c != "\r" && c != "\n") break;
        first = first + 1;
    }

    while (last > first) {
        string c = char_at(value, last - 1);
        if (c != " " && c != "\t" && c != "\r" && c != "\n") break;
        last = last - 1;
    }

    return substring(value, first, last);
}

string[int] ashmod_tokens(string value) {
    string[int] raw = split_string(ashmod_trim(value), " ");
    string[int] out;
    foreach i, token in raw {
        token = ashmod_trim(token);
        if (token == "") continue;
        out[count(out)] = token;
    }
    return out;
}

void ashmod_error(string message) {
    ASHMOD_ERRORS[count(ASHMOD_ERRORS)] = message;
}

boolean ashmod_is_hex(string value) {
    if (length(value) != 64) return false;
    string allowed = "0123456789abcdefABCDEF";
    for i from 0 to length(value) - 1 {
        if (!contains_text(allowed, char_at(value, i))) return false;
    }
    return true;
}

boolean ashmod_safe_path(string path) {
    if (path == "") return false;
    if (starts_with(path, "/")) return false;
    if (contains_text(path, "..")) return false;
    if (contains_text(path, "\\")) return false;

    string allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-";
    for i from 0 to length(path) - 1 {
        if (!contains_text(allowed, char_at(path, i))) return false;
    }
    return true;
}

boolean ashmod_safe_script_path(string path) {
    return ashmod_safe_path(path) && ends_with(to_lower_case(path), ".ash");
}

string ashmod_dirname(string path) {
    int last_slash = -1;
    for i from 0 to length(path) - 1 {
        if (char_at(path, i) == "/") last_slash = i;
    }
    if (last_slash < 0) return "";
    return substring(path, 0, last_slash + 1);
}

string ashmod_resolve_owned_path(string path) {
    if (ASHMOD_BASE_DIR == "") return path;
    return ASHMOD_BASE_DIR + path;
}

boolean ashmod_nonempty_file(string path) {
    if (!ashmod_safe_path(path)) return false;
    string[int] lines = file_to_array(path);
    return count(lines) > 0;
}

boolean ashmod_load(string mod_path) {
    clear(ASHMOD_FIELDS);
    clear(ASHMOD_FILES);
    clear(ASHMOD_REQUIRES);
    clear(ASHMOD_ERRORS);
    ASHMOD_DESCRIPTOR_PATH = "";
    ASHMOD_BASE_DIR = "";

    if (!ashmod_safe_path(mod_path)) {
        ashmod_error("Unsafe module descriptor path: " + mod_path);
        return false;
    }

    string[int] lines = file_to_array(mod_path);
    if (count(lines) == 0) {
        ashmod_error("Module descriptor is missing or empty: " + mod_path);
        return false;
    }

    ASHMOD_DESCRIPTOR_PATH = mod_path;
    ASHMOD_BASE_DIR = ashmod_dirname(mod_path);

    foreach line_no, raw in lines {
        string line = ashmod_trim(raw);
        if (line == "" || starts_with(line, "#")) continue;

        string[int] parts = ashmod_tokens(line);
        if (count(parts) == 0) continue;

        string directive = to_lower_case(parts[0]);

        if (directive == "file") {
            if (count(parts) != 4) {
                ashmod_error("Malformed file directive at line " + (line_no + 1) + ".");
                continue;
            }

            ashmod_file_record rec;
            rec.path = parts[1];
            rec.bytes = parts[2].to_int();
            rec.sha256 = parts[3];

            if (!ashmod_safe_path(rec.path))
                ashmod_error("Unsafe file path at line " + (line_no + 1) + ": " + rec.path);
            if (rec.bytes < 0)
                ashmod_error("Negative byte count at line " + (line_no + 1) + ".");
            if (!ashmod_is_hex(rec.sha256))
                ashmod_error("Invalid SHA-256 at line " + (line_no + 1) + ".");

            ASHMOD_FILES[count(ASHMOD_FILES)] = rec;
            continue;
        }

        if (directive == "require") {
            if (count(parts) < 4 || count(parts) > 5) {
                ashmod_error("Malformed require directive at line " + (line_no + 1) + ".");
                continue;
            }

            ashmod_require_record req;
            req.module_id = parts[1];
            req.constraint = parts[2];
            req.entry = parts[3];
            if (count(parts) == 5) req.source = parts[4];

            if (!ashmod_safe_script_path(req.entry))
                ashmod_error("Unsafe dependency entry path at line " + (line_no + 1) + ": " + req.entry);

            ASHMOD_REQUIRES[count(ASHMOD_REQUIRES)] = req;
            continue;
        }

        if (count(parts) != 2) {
            ashmod_error("Malformed directive at line " + (line_no + 1) + ": " + directive);
            continue;
        }

        if (ASHMOD_FIELDS contains directive) {
            ashmod_error("Duplicate directive at line " + (line_no + 1) + ": " + directive);
            continue;
        }

        ASHMOD_FIELDS[directive] = parts[1];
    }

    return count(ASHMOD_ERRORS) == 0;
}

boolean ashmod_validate_loaded() {
    if (!(ASHMOD_FIELDS contains "ashmod"))
        ashmod_error("Missing required directive: ashmod");
    else if (ASHMOD_FIELDS["ashmod"] != "1")
        ashmod_error("Unsupported ash.mod format: " + ASHMOD_FIELDS["ashmod"]);

    if (!(ASHMOD_FIELDS contains "module") || ASHMOD_FIELDS["module"] == "")
        ashmod_error("Missing required directive: module");

    if (!(ASHMOD_FIELDS contains "version") || ASHMOD_FIELDS["version"] == "")
        ashmod_error("Missing required directive: version");

    if (!(ASHMOD_FIELDS contains "entry")) {
        ashmod_error("Missing required directive: entry");
    } else if (!ashmod_safe_script_path(ASHMOD_FIELDS["entry"])) {
        ashmod_error("Unsafe entry script path: " + ASHMOD_FIELDS["entry"]);
    } else {
        string entry_path = ashmod_resolve_owned_path(ASHMOD_FIELDS["entry"]);
        if (!ashmod_nonempty_file(entry_path))
            ashmod_error("Entry script is missing or empty: " + entry_path);
    }

    if (ASHMOD_FIELDS contains "smoke") {
        if (!ashmod_safe_script_path(ASHMOD_FIELDS["smoke"])) {
            ashmod_error("Unsafe smoke script path: " + ASHMOD_FIELDS["smoke"]);
        } else {
            string smoke_path = ashmod_resolve_owned_path(ASHMOD_FIELDS["smoke"]);
            if (!ashmod_nonempty_file(smoke_path))
                ashmod_error("Smoke script is missing or empty: " + smoke_path);
        }
    }

    if (ASHMOD_FIELDS contains "manifest") {
        if (!ashmod_safe_path(ASHMOD_FIELDS["manifest"])) {
            ashmod_error("Unsafe manifest path: " + ASHMOD_FIELDS["manifest"]);
        } else {
            string manifest_path = ashmod_resolve_owned_path(ASHMOD_FIELDS["manifest"]);
            if (!ashmod_nonempty_file(manifest_path))
                ashmod_error("Manifest is missing or empty: " + manifest_path);
        }
    }

    if (ASHMOD_FIELDS contains "readme") {
        if (!ashmod_safe_path(ASHMOD_FIELDS["readme"])) {
            ashmod_error("Unsafe readme path: " + ASHMOD_FIELDS["readme"]);
        } else {
            string readme_path = ashmod_resolve_owned_path(ASHMOD_FIELDS["readme"]);
            if (!ashmod_nonempty_file(readme_path))
                ashmod_error("README is missing or empty: " + readme_path);
        }
    }

    if (ASHMOD_FIELDS contains "importsafe") {
        string flag = to_lower_case(ASHMOD_FIELDS["importsafe"]);
        if (flag != "true" && flag != "false")
            ashmod_error("importsafe must be true or false.");
    }

    foreach i, rec in ASHMOD_FILES {
        string owned_path = ashmod_resolve_owned_path(rec.path);
        if (!ashmod_nonempty_file(owned_path))
            ashmod_error("Declared file is missing or empty: " + owned_path);
    }

    // Dependency entries are KoLmafia scripts-search paths, not module-local paths.
    foreach i, req in ASHMOD_REQUIRES {
        if (!ashmod_nonempty_file(req.entry))
            ashmod_error("Missing dependency entry: " + req.module_id + " -> " + req.entry);
    }

    return count(ASHMOD_ERRORS) == 0;
}

void ashmod_print_errors() {
    foreach i, message in ASHMOD_ERRORS
        print("ashmod: ERROR: " + message, "red");
}

void ashmod_show() {
    print("ASH module: " + ASHMOD_FIELDS["module"] + "@" + ASHMOD_FIELDS["version"], "blue");
    print("  descriptor:  " + ASHMOD_DESCRIPTOR_PATH);
    print("  format:      " + ASHMOD_FIELDS["ashmod"]);
    print("  entry:       " + ashmod_resolve_owned_path(ASHMOD_FIELDS["entry"]));

    if (ASHMOD_FIELDS contains "namespace")
        print("  namespace:   " + ASHMOD_FIELDS["namespace"]);
    if (ASHMOD_FIELDS contains "importsafe")
        print("  import-safe: " + ASHMOD_FIELDS["importsafe"]);
    if (ASHMOD_FIELDS contains "smoke")
        print("  smoke:       " + ashmod_resolve_owned_path(ASHMOD_FIELDS["smoke"]));
    if (ASHMOD_FIELDS contains "manifest")
        print("  manifest:    " + ashmod_resolve_owned_path(ASHMOD_FIELDS["manifest"]));
    if (ASHMOD_FIELDS contains "readme")
        print("  readme:      " + ashmod_resolve_owned_path(ASHMOD_FIELDS["readme"]));

    print("  files:       " + count(ASHMOD_FILES));
    print("  requires:    " + count(ASHMOD_REQUIRES));
}

void ashmod_show_files() {
    if (count(ASHMOD_FILES) == 0) {
        print("No locked files declared.");
        return;
    }

    foreach i, rec in ASHMOD_FILES {
        print(ashmod_resolve_owned_path(rec.path) + "  bytes=" + rec.bytes + "  sha256=" + rec.sha256);
    }
    print("NOTE: v1 validates checksum syntax/presence only; SHA-256 recomputation is external.");
}

void ashmod_show_deps() {
    if (count(ASHMOD_REQUIRES) == 0) {
        print("No module dependencies.");
        return;
    }

    foreach i, req in ASHMOD_REQUIRES {
        string line = req.module_id + " " + req.constraint + " -> " + req.entry;
        if (req.source != "") line = line + " [" + req.source + "]";
        if (ashmod_nonempty_file(req.entry)) line = line + " [present]";
        else line = line + " [MISSING]";
        print(line);
    }
}

void ashmod_graph() {
    string root = ASHMOD_FIELDS["module"] + "@" + ASHMOD_FIELDS["version"];
    if (count(ASHMOD_REQUIRES) == 0) {
        print(root + " (no dependencies)");
        return;
    }

    print(root);
    foreach i, req in ASHMOD_REQUIRES
        print("  -> " + req.module_id + " " + req.constraint + " (" + req.entry + ")");
}

void ashmod_print_import() {
    print("import <" + ashmod_resolve_owned_path(ASHMOD_FIELDS["entry"]) + ">;");
}

boolean ashmod_verify() {
    string entry = ashmod_resolve_owned_path(ASHMOD_FIELDS["entry"]);
    if (!ashmod_safe_script_path(entry)) {
        print("ashmod: refusing unsafe entry path.", "red");
        return false;
    }

    print("ashmod: verify " + entry, "blue");
    return cli_execute("verify " + entry);
}

boolean ashmod_smoke() {
    if (!(ASHMOD_FIELDS contains "smoke")) {
        print("ashmod: no smoke script declared.", "red");
        return false;
    }

    string smoke = ashmod_resolve_owned_path(ASHMOD_FIELDS["smoke"]);
    if (!ashmod_safe_script_path(smoke)) {
        print("ashmod: refusing unsafe smoke path.", "red");
        return false;
    }

    print("ashmod: call " + smoke, "blue");
    return cli_execute("call " + smoke);
}

void ashmod_help() {
    print("ashmod.ash - ash.mod v1 reader");
    print("");
    print("Usage: call ashmod.ash <command> [path/to/ash.mod]");
    print("");
    print("Read-only commands:");
    print("  show    display module identity and entrypoints");
    print("  check   validate descriptor shape and declared file/dependency presence");
    print("  files   list locked files and SHA-256 metadata");
    print("  deps    list dependency declarations and presence");
    print("  graph   print one-level dependency graph");
    print("  import  print the ASH import line for the module entry");
    print("");
    print("Explicit execution commands:");
    print("  verify  run: verify <validated entry>");
    print("  smoke   run: call <validated smoke script>");
    print("  all     check, then verify, then smoke");
    print("");
    print("Module-owned paths are relative to the descriptor directory.");
    print("Dependency entry paths are resolved through KoLmafia's scripts search path.");
    print("Default descriptor path: ash.mod");
}

void main(string command) {
    string[int] args = ashmod_tokens(command);
    if (count(args) == 0) {
        ashmod_help();
        return;
    }

    string action = to_lower_case(args[0]);
    string mod_path = "ash.mod";
    if (count(args) >= 2) mod_path = args[1];

    if (action == "help" || action == "-h" || action == "--help") {
        ashmod_help();
        return;
    }

    if (!ashmod_load(mod_path)) {
        ashmod_print_errors();
        return;
    }

    if (!ashmod_validate_loaded()) {
        ashmod_print_errors();
        return;
    }

    if (action == "show") {
        ashmod_show();
        return;
    }

    if (action == "check") {
        ashmod_show();
        print("ashmod: CHECK PASS", "green");
        return;
    }

    if (action == "files") {
        ashmod_show_files();
        return;
    }

    if (action == "deps") {
        ashmod_show_deps();
        return;
    }

    if (action == "graph") {
        ashmod_graph();
        return;
    }

    if (action == "import") {
        ashmod_print_import();
        return;
    }

    if (action == "verify") {
        if (ashmod_verify()) print("ashmod: VERIFY PASS", "green");
        else print("ashmod: VERIFY FAIL", "red");
        return;
    }

    if (action == "smoke") {
        if (ashmod_smoke()) print("ashmod: SMOKE COMMAND COMPLETED", "green");
        else print("ashmod: SMOKE COMMAND FAILED", "red");
        return;
    }

    if (action == "all") {
        ashmod_show();
        print("ashmod: CHECK PASS", "green");

        if (!ashmod_verify()) {
            print("ashmod: ALL STOPPED AT VERIFY", "red");
            return;
        }

        if (!ashmod_smoke()) {
            print("ashmod: ALL STOPPED AT SMOKE", "red");
            return;
        }

        print("ashmod: ALL PASS", "green");
        return;
    }

    print("ashmod: unknown command: " + action, "red");
    ashmod_help();
}
