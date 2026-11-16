source "$LIB"
grep -q '"~> 5.0"' main.tf || fail "The root module's AWS constraint was changed."
mkdir "$CHECK_TMP/w" && cp -r . "$CHECK_TMP/w" && cd "$CHECK_TMP/w" && rm -rf .terraform
out=$(terraform init -backend=false -input=false -no-color 2>&1) || fail "terraform init still fails:"$'\n'"$(grep -A6 'Error' <<< "$out" | head -n 12)"
pass "terraform init works."
