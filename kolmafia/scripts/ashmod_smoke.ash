script "ashmod_smoke.ash";
import <ashmod.ash>;

void main() {
    if (!ashmod_load("ash.mod")) {
        ashmod_print_errors();
        abort("ashmod self smoke could not load ash.mod");
    }

    if (!ashmod_validate_loaded()) {
        ashmod_print_errors();
        abort("ashmod self smoke validation failed");
    }

    if (!(ASHMOD_FIELDS contains "module") || ASHMOD_FIELDS["module"] != "ashmod")
        abort("ashmod self smoke loaded the wrong module");

    print("ashmod: SELF SMOKE PASS", "green");
}
