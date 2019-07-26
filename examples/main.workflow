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
        "KULADO_ACCESS_TOKEN"
    ]
}

workflow "Preview" {
    on = "pull_request"
    resolves = "Kulado Preview (Merged Stack)"
}

action "Kulado Preview (Merged Stack)" {
    uses = "docker://kulado/actions"
    args = [ "preview" ]
    env = {
        "KULADO_CI" = "pr"
    }
    secrets = [
        "KULADO_ACCESS_TOKEN"
    ]
}
