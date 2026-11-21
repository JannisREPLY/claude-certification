source "$LIB"
source "$LAB_DIR/helpers.sh"
require_init
expect_module_fixed
expect_providers_txt
expect_version_txt
expect_plugin_path
pass "providers.txt, version.txt and plugin-path.txt document the installed plugins."
