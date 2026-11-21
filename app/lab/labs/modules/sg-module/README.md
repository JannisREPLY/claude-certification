# security-group

Security group with TCP ingress rules (`aws_vpc_security_group_ingress_rule`, one per key of `ingress`).

Inputs:
- `name` (string, required)
- `vpc_id` (string, required)
- `description` (string, default `Managed by Terraform`, since v1.1.0)
- `ingress` (map of `{ port = number, cidr = string }`, default `{}`)

Output: `id`

Changelog:
- v2.0.0: `name` is now used as a name prefix, so several groups can share a name.
- v1.1.0: new input `description`.
- v1.0.0: first release.
