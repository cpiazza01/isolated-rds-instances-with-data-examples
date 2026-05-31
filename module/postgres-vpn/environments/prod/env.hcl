# Prod — larger instance, deletion protection on, final snapshot kept on destroy.
# Certificates are managed manually (not auto-generated) so private keys are
# never stored in Terraform state. Generate with EasyRSA, import into ACM, then
# set the ARN values below.
#
# To generate and import certificates:
#   1. Install EasyRSA: https://github.com/OpenVPN/easy-rsa
#   2. Build the PKI: easyrsa init-pki && easyrsa build-ca nopass
#   3. Generate server cert: easyrsa build-server-full server nopass
#   4. Generate client cert: easyrsa build-client-full developer nopass
#   5. Import into ACM (both regions if multi-region):
#        aws acm import-certificate --certificate file://pki/issued/server.crt \
#          --private-key file://pki/private/server.key \
#          --certificate-chain file://pki/ca.crt
#   6. Set the returned ARNs below.
#
# NOTE: AWS Client VPN costs ~$0.10/hr per subnet association (~$144/month idle).
# Both destroy guards (prevent_destroy + db_deletion_protection) must be removed
# before running terragrunt destroy on prod.

locals {
  db_instance_class      = "db.t3.small"
  row_count              = 10000
  skip_final_snapshot    = false
  db_deletion_protection = true

  client_vpn_create_certificates       = false
  client_vpn_server_cert_arn           = null   # replace with ACM server cert ARN
  client_vpn_root_cert_arn             = null   # replace with ACM CA cert ARN
  client_vpn_enable_connection_logging = true
}
