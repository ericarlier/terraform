terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.53"
        }
        confluent = {
            source = "confluentinc/confluent"
            version = "1.28.0"
        }
    }
}
provider "confluent" {
    # Set through env vars as:
    # CONFLUENT_CLOUD_API_KEY="CLOUD-KEY"
    # CONFLUENT_CLOUD_API_SECRET="CLOUD-SECRET"
}

