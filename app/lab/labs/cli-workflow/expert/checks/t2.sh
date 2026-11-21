source "$LAB_DIR/helpers.sh"
check_replaced 'aws_instance.web["b"]'
pass 'Only aws_instance.web["b"] was replaced.'
