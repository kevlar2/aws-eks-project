# OPA policy for 2048 EKS infrastructure
# Evaluated against terraform plan JSON output via conftest
#
# Usage: conftest test tfplan.json --policy policies/opa/terraform.rego
package main

import rego.v1

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

# All planned resource changes (create or update)
resources contains rc if {
	some rc in input.resource_changes
	rc.change.actions[_] != "delete"
}

# Get a resource by type
resources_by_type(t) := {rc |
	some rc in resources
	rc.type == t
}

# ---------------------------------------------------------------
# Tagging: every taggable resource must have required tags
# ---------------------------------------------------------------
# Use the exact tag keys produced by our Terraform modules
required_tags := {"Environment", "Project", "CostCenter"}

deny contains msg if {
	some rc in resources
	tags := object.get(rc.change.after, "tags", null)
	tags != null
	count(tags) > 0
	some tag in required_tags
	not tag_present(tags, tag)
	msg := sprintf("Resource %s (%s) is missing required tag '%s'", [rc.address, rc.type, tag])
}

# Exact match on tag key
tag_present(tags, key) if {
	_ = tags[key]
}

# ---------------------------------------------------------------
# EKS: cluster must not have public+private both disabled
# ---------------------------------------------------------------
deny contains msg if {
	some rc in resources_by_type("aws_eks_cluster")
	vpc := rc.change.after.vpc_config[0]
	vpc.endpoint_public_access == false
	vpc.endpoint_private_access == false
	msg := sprintf("EKS cluster %s has both public and private endpoint access disabled — cluster will be unreachable", [rc.address])
}

# ---------------------------------------------------------------
# EKS: node group must have at least 2 desired nodes for HA
# ---------------------------------------------------------------
deny contains msg if {
	some rc in resources_by_type("aws_eks_node_group")
	scaling := rc.change.after.scaling_config[0]
	scaling.desired_size < 2
	msg := sprintf("EKS node group %s has desired_size < 2 (%d) — insufficient for high availability", [rc.address, scaling.desired_size])
}

# ---------------------------------------------------------------
# EKS: node group min_size must not be 0 (prevents scale-to-zero accidents)
# ---------------------------------------------------------------
warn contains msg if {
	some rc in resources_by_type("aws_eks_node_group")
	scaling := rc.change.after.scaling_config[0]
	scaling.min_size == 0
	msg := sprintf("EKS node group %s has min_size=0 — cluster could scale to zero nodes", [rc.address])
}

# ---------------------------------------------------------------
# VPC: subnets must not map public IPs on private subnets
# Private subnets are identified by having map_public_ip_on_launch = false,
# so this rule catches accidental flips on subnets named "private"
# ---------------------------------------------------------------
warn contains msg if {
	some rc in resources_by_type("aws_subnet")
	rc.change.after.map_public_ip_on_launch == true
	contains(rc.address, "private")
	msg := sprintf("Subnet %s is named 'private' but has map_public_ip_on_launch=true", [rc.address])
}

# ---------------------------------------------------------------
# Security groups: deny unrestricted egress on all protocols
# (0.0.0.0/0 with ip_protocol=-1 is common but flagged as a warning)
# ---------------------------------------------------------------
warn contains msg if {
	some rc in resources_by_type("aws_vpc_security_group_egress_rule")
	rc.change.after.cidr_ipv4 == "0.0.0.0/0"
	rc.change.after.ip_protocol == "-1"
	msg := sprintf("Security group egress rule %s allows all traffic to 0.0.0.0/0 — consider restricting", [rc.address])
}

# ---------------------------------------------------------------
# S3: state bucket must have versioning enabled
# ---------------------------------------------------------------
deny contains msg if {
	some rc in resources_by_type("aws_s3_bucket_versioning")
	config := rc.change.after.versioning_configuration[0]
	config.status != "Enabled"
	msg := sprintf("S3 bucket versioning %s is not enabled — required for state file protection", [rc.address])
}

# ---------------------------------------------------------------
# S3: state bucket must block public access
# ---------------------------------------------------------------
deny contains msg if {
	some rc in resources_by_type("aws_s3_bucket_public_access_block")
	after := rc.change.after
	not after.block_public_acls
	msg := sprintf("S3 bucket %s does not block public ACLs", [rc.address])
}

deny contains msg if {
	some rc in resources_by_type("aws_s3_bucket_public_access_block")
	after := rc.change.after
	not after.block_public_policy
	msg := sprintf("S3 bucket %s does not block public policy", [rc.address])
}

# ---------------------------------------------------------------
# IAM: roles must not use wildcard (*) in assume_role_policy principal
# ---------------------------------------------------------------
deny contains msg if {
	some rc in resources_by_type("aws_iam_role")
	policy_json := rc.change.after.assume_role_policy
	policy := json.unmarshal(policy_json)
	some stmt in policy.Statement
	principals := object.get(stmt, "Principal", {})
	principal_has_wildcard(principals)
	msg := sprintf("IAM role %s has wildcard (*) in assume_role_policy — overly permissive", [rc.address])
}

principal_has_wildcard(p) if {
	p == "*"
}

principal_has_wildcard(p) if {
	some _, v in p
	v == "*"
}

principal_has_wildcard(p) if {
	some _, v in p
	is_array(v)
	v[_] == "*"
}
