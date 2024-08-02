variable "project" {
  type = string
}

locals {
  project = var.project
  # 連携作成時に使用する名前を設定してください（任意）
  test_federation_name = "test-federation"

  # 以下の値は変更しないでください
  test_aws_account = "000000000000"
}

provider "google" {
  project = local.project
}

resource "google_iam_workload_identity_pool" "pool" {
  workload_identity_pool_id = "${local.test_federation_name}-pool"
}

resource "google_iam_workload_identity_pool_provider" "test_private" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "${local.test_federation_name}-provider"
  display_name                       = "${local.test_federation_name}-provider"
  description                        = "test からのWorkload Identity連携"
  disabled                           = false
  attribute_mapping                  = {
    "google.subject"        = "assertion.arn"
    "attribute.aws_account" = "assertion.account"
  }
  aws {
    account_id = local.test_aws_account
  }
}

resource "google_service_account" "test_private_service_account" {
  account_id = local.test_federation_name
  display_name = local.test_federation_name
}

data "google_iam_policy" "service_account_wi_user" {
  binding {
    role = "roles/iam.workloadIdentityUser"

    members = [
      "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.pool.name}/attribute.aws_account/${local.test_aws_account}",
    ]
  }
}

resource "google_service_account_iam_policy" "admin_account_iam" {
  service_account_id = google_service_account.test_private_service_account.name
  policy_data        = data.google_iam_policy.service_account_wi_user.policy_data
}

resource "google_project_iam_member" "service_account_instance_admin" {
  project = local.project
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.test_private_service_account.email}"
}
