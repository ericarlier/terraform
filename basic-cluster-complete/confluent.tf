# --------------------------------------------------------
# This 'random_id' will make whatever you create (names, etc)
# unique in your account.
# --------------------------------------------------------
resource "random_id" "id" {
    byte_length = 4
}

# ------------------------------------------------------
# ENVIRONMENT
# ------------------------------------------------------
resource "confluent_environment" "env" {
    display_name = "${local.env_name}"
}
# ------------------------------------------------------
# SCHEMA REGISTRY
# ------------------------------------------------------
data "confluent_schema_registry_region" "sr_region" {
    cloud = "${local.csp}"
    region = "${local.sr_region}"
    package = "ESSENTIALS"
}
resource "confluent_schema_registry_cluster" "sr" {
    package = data.confluent_schema_registry_region.sr_region.package
    environment {
        id = confluent_environment.env.id 
    }
    region {
        id = data.confluent_schema_registry_region.sr_region.id
    }
}

# --------------------------------------------------------
# Cluster
# --------------------------------------------------------
resource "confluent_kafka_cluster" "simple_cluster" {
    display_name = "${local.cluster_name}"
    availability = "SINGLE_ZONE"
    cloud = "${local.csp}"
    region = "${local.region}"
    basic {}
    environment {
        id = confluent_environment.env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}

# --------------------------------------------------------
# Service Accounts
# --------------------------------------------------------
resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-${random_id.id.hex}"
    description = "Provisioner User"
}
resource "confluent_service_account" "ksql" {
    display_name = "ksql-user-${random_id.id.hex}"
    description = "KSQL User"
}
resource "confluent_service_account" "connectors" {
    display_name = "connector-sa-${random_id.id.hex}"
    description = "Connectors SA"
}
# ------------------------------------------------------
# ROLE BINDINGS
# ------------------------------------------------------
resource "confluent_role_binding" "app_manager_env_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.env.resource_name
}
resource "confluent_role_binding" "ksql_cluster_admin" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.simple_cluster.rbac_crn
}
resource "confluent_role_binding" "ksql_sr_resource_owner" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr.resource_name, "subject=*")
}
# ------------------------------------------------------
# ACLS
# ------------------------------------------------------
resource "confluent_kafka_acl" "connectors_source_acl_describe_cluster" {
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    resource_type = "CLUSTER"
    resource_name = "kafka-cluster"
    pattern_type = "LITERAL"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "DESCRIBE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.simple_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_create_topic" {
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    resource_type = "TOPIC"
    resource_name = "datagen_"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "CREATE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.simple_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}
resource "confluent_kafka_acl" "connectors_source_acl_write" {
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    resource_type = "TOPIC"
    resource_name = "datagen_"
    pattern_type = "PREFIXED"
    principal = "User:${confluent_service_account.connectors.id}"
    operation = "WRITE"
    permission = "ALLOW"
    host = "*"
    rest_endpoint = confluent_kafka_cluster.simple_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_keys.id
        secret = confluent_api_key.app_manager_keys.secret
    }
}

# ------------------------------------------------------
# API KEYS
# ------------------------------------------------------
resource "confluent_api_key" "app_manager_keys" {
    display_name = "app-manager-${local.cluster_name}-key-${random_id.id.hex}"
    description = "Key for app manager"
    owner {
        id = confluent_service_account.app_manager.id 
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.simple_cluster.id 
        api_version = confluent_kafka_cluster.simple_cluster.api_version
        kind = confluent_kafka_cluster.simple_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_env_admin
    ]
}
resource "confluent_api_key" "ksql_keys" {
    display_name = "ksql-user-${local.cluster_name}-key-${random_id.id.hex}"
    description = "Key for KSQL User"
    owner {
        id = confluent_service_account.ksql.id 
        api_version = confluent_service_account.ksql.api_version
        kind = confluent_service_account.ksql.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.simple_cluster.id 
        api_version = confluent_kafka_cluster.simple_cluster.api_version
        kind = confluent_kafka_cluster.simple_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin,
        confluent_role_binding.ksql_sr_resource_owner
    ]
}
resource "confluent_api_key" "connector_keys" {
    display_name = "connectors-api-key-${random_id.id.hex}"
    description = "Key for Connectors"
    owner {
        id = confluent_service_account.connectors.id 
        api_version = confluent_service_account.connectors.api_version
        kind = confluent_service_account.connectors.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.simple_cluster.id 
        api_version = confluent_kafka_cluster.simple_cluster.api_version
        kind = confluent_kafka_cluster.simple_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic,
        confluent_kafka_acl.connectors_source_acl_write
    ]
}
# ------------------------------------------------------
# KSQL
# ------------------------------------------------------
resource "confluent_ksql_cluster" "ksql_cluster" {
    display_name = "ksql-cluster-demo"
    csu = 1
    environment {
        id = confluent_environment.env.id
    }
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    credential_identity {
        id = confluent_service_account.ksql.id
    }
    depends_on = [
        confluent_role_binding.ksql_cluster_admin,
        confluent_role_binding.ksql_sr_resource_owner,
        confluent_api_key.ksql_keys,
        confluent_schema_registry_cluster.sr
    ]
}
# ------------------------------------------------------
# CONNECT
# ------------------------------------------------------
resource "confluent_connector" "datagen_pageviews" {
    environment {
        id = confluent_environment.env.id 
    }
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    status = "RUNNING"
    config_nonsensitive = {
        "name" : "datagen_ccloud_pageviews"
        "connector.class": "DatagenSource"
        "kafka.topic" : "datagen_pageviews"
        "output.data.format" : "AVRO"
        "quickstart" : "PAGEVIEWS"
        "max.interval": "500"
        "iterations": "1000000000"
        "tasks.max" : "1"
        "kafka.auth.mode": "SERVICE_ACCOUNT"
        "kafka.service.account.id" = "${confluent_service_account.connectors.id}"
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic,
        confluent_kafka_acl.connectors_source_acl_write,
        confluent_api_key.connector_keys,
    ]
}

resource "confluent_connector" "datagen_users" {
    environment {
        id = confluent_environment.env.id 
    }
    kafka_cluster {
        id = confluent_kafka_cluster.simple_cluster.id
    }
    status = "RUNNING"
    config_nonsensitive = {
        "name" : "datagen_ccloud_users"
        "connector.class": "DatagenSource"
        "kafka.topic" : "datagen_users"
        "output.data.format" : "PROTOBUF"
        "quickstart" : "USERS"
        "max.interval": "2000"
        "iterations": "1000000000"
        "tasks.max" : "1"
        "kafka.auth.mode": "SERVICE_ACCOUNT"
        "kafka.service.account.id" = "${confluent_service_account.connectors.id}"
    }
    depends_on = [
        confluent_kafka_acl.connectors_source_acl_create_topic,
        confluent_kafka_acl.connectors_source_acl_write,
        confluent_api_key.connector_keys,
        aws_instance.postgres_db_instance,
        aws_eip.postgres_db_eip
    ]
}
