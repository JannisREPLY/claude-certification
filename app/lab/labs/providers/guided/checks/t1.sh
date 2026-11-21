source "$LIB"
source "$LAB_DIR/helpers.sh"
expect_init_works
pass "terraform init works and the AWS constraint is unchanged."
