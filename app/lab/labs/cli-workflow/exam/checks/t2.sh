source "$LAB_DIR/helpers.sh"
check_replaced "aws_instance.web[1]"
pass "Only aws_instance.web[1] was replaced."
