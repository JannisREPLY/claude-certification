source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_module_fixed
expect_providers_txt
expect_version_txt
pass "providers.txt and version.txt document the installed plugins."
