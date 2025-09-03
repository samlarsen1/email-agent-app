# email-agent-app


# GCloud Vertex Test

This project demonstrates the use of GCloud Vertex AI for machine learning workflows.

## Prerequisites

Before setting up this project, ensure you have completed the setup steps in the [chromebook-setup](https://github.com/samlarsen1/chromebook-setup) project. This will install the necessary dependencies and tools required for this project.

## Setup    

* `cp terraform.tfvars.example terraform.tfvars`
* Edit the default project_id with your own project id
* `terraform init`

## Development

Use `pre-commit` during development to check for misconfiguraitons in cloud resources.pre-commit run --all-files

`terraform validate`
`terraform plan`