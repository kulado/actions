# Kulado GitHub Actions

Kulado's GitHub Actions deploy apps and infrastructure to your cloud of choice, using just your favorite language
and GitHub. This includes previewing, validating, and collaborating on proposed deployments in the context of Pull
Requests, and triggering deployments or promotions between different environments by merging or directly committing code.

## Getting Started

To get started with Kulado's GitHub Actions, check out our documentation: [https://kulado.io/github](https://kulado.io/github)

## Demos and Examples

To see some examples of this in action, see the following links:

* [Our introductory blog post](https://blog.kulado.com/continuous-delivery-to-any-cloud-using-github-actions-and-kulado)
* [Dockerized Ruby on Rails, in Kubernetes, with hosted Cloud SQL](https://github.com/kulado/actions-example-gke-rails)
* [Short 90 second video from GitHub Universe Keynote](https://www.youtube.com/watch?v=59SxB2uY9E0)
* [Short 90 second video on GitOps and Pull Request workflows](https://www.youtube.com/watch?v=MKbDVDBuKUA)
* [Longer 7 minute video exploring the ins and outs of Kulado GitHub Actions in practice](https://www.youtube.com/watch?v=1Et2TkuxqJg)

## Cloud Providers

Below are some quick tips on using Kulado's GitHub Actions support with your cloud provider. This typically
entails configuring a service principal for unattended access, storing the resulting credentials using
[GitHub Secrets](https://developer.github.com/actions/creating-workflows/storing-secrets/), and consuming
them using [the `secrets` attribute](
https://developer.github.com/actions/creating-workflows/workflow-configuration-options/#actions-attributes)
on your workflow's action.

> If your cloud of choice isn't listed, that doesn't necessarily mean Kulado doesn't support it; please see
> [Kulado's QuickStart page](https://kulado.io/quickstart) for more complete documentation.

### Amazon Web Services (AWS)

For AWS, you'll need to create or use or use an existing IAM user for your action. Please see
[the Kulado documentation page](https://kulado.io/quickstart/aws/setup.html#environment-variables) for pointers
to the relevant AWS documentation for doing this.

As soon as you have an AWS user in hand, you'll set the environment variables `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` using GitHub Secrets, and then consume them in your action:

```
workflow "Update" {
    on = "push"
    resolves = [ "Kulado Deploy (Current Stack)" ]
}

action "Kulado Deploy (Current Stack)" {
    uses = "docker://kulado/actions"
    args = [ "up" ]
    env = {
        "KULADO_CI" = "up"
    }
    secrets = [
        "KULADO_ACCESS_TOKEN",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY"
    ]
}
```

Failure to configure this correctly will lead to an error message.

### Microsoft Azure

For Azure, you'll need to create or use an existing Azure Service Principal for your action. Please see
[the Kulado documentation page](https://kulado.io/quickstart/azure/setup.html#service-principal-authentication) for
pointers to the relevant Azure documentation for doing this.

As soon as you have a service principal in hand, you'll set the environment variables `ARM_SUBSCRIPTION_ID`,
`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, and `ARM_TENANT_ID` using GitHub Secrets, and consume them in your action:

```
workflow "Update" {
    on = "push"
    resolves = [ "Kulado Deploy (Current Stack)" ]
}

action "Kulado Deploy (Current Stack)" {
    uses = "docker://kulado/actions"
    args = [ "up" ]
    env = {
        "KULADO_CI" = "up"
    }
    secrets = [
        "KULADO_ACCESS_TOKEN",
        "ARM_SUBSCRIPTION_ID",
        "ARM_CLIENT_ID",
        "ARM_CLIENT_SECRET",
        "ARM_TENANT_ID"
    ]
}
```

Failure to configure this correctly will lead to the error message `Error building AzureRM Client: Azure CLI
Authorization Profile was not found. Please ensure the Azure CLI is installed and then log-in with 'az login'`.

### Google Cloud Platform

For GCP, you'll need to create or use or use an existing service account key. Please see
[the Kulado documentation page](https://kulado.io/quickstart/gcp/setup.html) for pointers
to the relevant GCP documentation for doing this.

As soon as you have credentials in hand, you'll set the environment variable `GOOGLE_CREDENTIALS` to contain the
credentials JSON using GitHub Secrets, and then consume it in your action:

```
workflow "Update" {
    on = "push"
    resolves = [ "Kulado Deploy (Current Stack)" ]
}

action "Kulado Deploy (Current Stack)" {
    uses = "docker://kulado/actions"
    args = [ "up" ]
    env = {
        "KULADO_CI" = "up"
    }
    secrets = [
        "KULADO_ACCESS_TOKEN",
        "GOOGLE_CREDENTIALS"
    ]
}
```

Failure to configure this correctly will lead to an error message.
