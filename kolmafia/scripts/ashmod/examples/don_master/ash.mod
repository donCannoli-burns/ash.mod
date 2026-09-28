# ash.mod -- KoLmafia ASH module descriptor
ashmod 1
module don_master
version 0.1.0
entry don_master_lib.ash
smoke don_master_smoke.ash
manifest don_master_manifest.json
readme DON_MASTER_ASHLIB_README.md
namespace don_
importsafe true

file don_master_lib.ash 25939 ee4042f09b730f59cfa45a27c341e56b1162dad438938c8adc9d5f74575e1147
file don_master_smoke.ash 204 7de355dc0a5908150a95eabf3d9262022785b8083e0c80bcf20eacc5a6b37580
file DON_MASTER_ASHLIB_README.md 5949 5889ffbf42b4bff4730449fe88b1bbf8c2a1f923dd6f4563ffc40d3e9473e70d

# Future dependency grammar:
# require <module-id> <version-constraint> <entry-script.ash> [source-url]
