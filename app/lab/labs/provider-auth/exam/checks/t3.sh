source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_module_fixed
expect_providers_txt
expect_plugin_path
pass "providers.txt and plugin-path.txt document the installed plugins."
