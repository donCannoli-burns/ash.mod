script "don_master_smoke.ash";
import <don_master_lib.ash>;

void main() {
    don_master_about();
    if (!don_master_smoke()) abort("DON Master ASH Lib smoke test failed.");
    don_print_snapshot();
}
