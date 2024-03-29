#!/bin/bash
# This is an entrypoint for our Docker image that does some minimal bootstrapping before executing.

set -e

# If the KULADO_CI variable is set, we'll do some extra things to make common tasks easier.
if [ ! -z "$KULADO_CI" ]; then
    # Capture the PWD before we go and potentially change it.
    ROOT=$(pwd)

    # If the root of the Kulado project isn't the root of the repo, CD into it.
    if [ ! -z "$KULADO_ROOT" ]; then
        cd $KULADO_ROOT
    fi

    # Detect the CI system and configure variables so that we get good Kulado workflow and GitHub App support.
    if [ ! -z "$GITHUB_WORKFLOW" ]; then
        export KULADO_CI_SYSTEM="GitHub"
        export KULADO_CI_BUILD_ID=
        export KULADO_CI_BUILD_TYPE=
        export KULADO_CI_BUILD_URL=
        export KULADO_CI_PULL_REQUEST_SHA="$GITHUB_SHA"

        # For PR events, we want to take the ref of the target branch, not the current. This ensures, for
        # instance, that a PR for a topic branch merging into `master` will use the `master` branch as the
        # target for a preview. Note that for push events, we of course want to use the actual branch.
        if [ "$KULADO_CI" = "pr" ]; then
            # Not all PR events warrant running a preview. Many of them pertain to changes in assignments and
            # ownership, but we only want to run the preview if the action is "opened", "edited", or "synchronize".
            PR_ACTION=$(jq -r ".action" < $GITHUB_EVENT_PATH)
            if [ "$PR_ACTION" != "opened" ] && [ "$PR_ACTION" != "edited" ] && [ "$PR_ACTION" != "synchronize" ]; then
                echo -e "PR event ($PR_ACTION) contains no changes and does not warrant a Kulado Preview"
                echo -e "Skipping Kulado action altogether..."
                exit 0
            fi

            BRANCH=$(jq -r ".pull_request.base.ref" < $GITHUB_EVENT_PATH)
        else
            BRANCH="$GITHUB_REF"
        fi
        BRANCH=$(echo $BRANCH | sed "s/refs\/heads\///g")
    fi

    # Respect the branch mappings file for stack selection. Note that this is *not* required, but if the file
    # is missing, the caller of this script will need to pass `-s <stack-name>` to specify the stack explicitly.
    if [ ! -z "$BRANCH" ]; then
        if [ -e $ROOT/.kulado/ci.json ]; then
            KULADO_STACK_NAME=$(cat $ROOT/.kulado/ci.json | jq -r ".\"$BRANCH\"")
        else
            # If there's no stack mapping file, we are on master, and there's a single stack, use it.
            KULADO_STACK_NAME=$(kulado stack ls | awk 'FNR == 2 {print $1}' | sed 's/\*//g')
        fi

        if [ ! -z "$KULADO_STACK_NAME" ] && [ "$KULADO_STACK_NAME" != "null" ]; then
            kulado stack select $KULADO_STACK_NAME
        else
            echo -e "No stack configured for branch '$BRANCH'"
            echo -e ""
            echo -e "To configure this branch, please"
            echo -e "\t1) Run 'kulado stack init <stack-name>'"
            echo -e "\t2) Associated the stack with the branch by adding"
            echo -e "\t\t{"
            echo -e "\t\t\t\"$BRANCH\": \"<stack-name>\""
            echo -e "\t\t}"
            echo -e "\tto your .kulado/ci.json file"
            echo -e ""
            echo -e "For now, exiting cleanly without doing anything..."
            exit 0
        fi
    fi
fi

# For Google, we need to authenticate with a service principal for certain authentication operations.
if [ ! -z "$GOOGLE_CREDENTIALS" ]; then
    GCLOUD_KEYFILE="$(mktemp).json"
    echo "$GOOGLE_CREDENTIALS" > $GCLOUD_KEYFILE
    gcloud auth activate-service-account --key-file=$GCLOUD_KEYFILE
fi

# Next, lazily install packages if required.
if [ -e package.json ] && [ ! -d node_modules ]; then
    npm install
fi

# Now just pass along all arguments to the Kulado CLI.
OUTPUT=$(sh -c "kulado --non-interactive $*" 2>&1)
EXIT_CODE=$?

echo "#### :tropical_drink: \`kulado ${@:2}\`"
echo "$OUTPUT"

# If the GitHub action stems from a Pull Request event, we may optionally leave a comment if the
# COMMENT_ON_PR is set.
COMMENTS_URL=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.comments_url)
if [ ! -z $COMMENTS_URL ] && [ ! -z $COMMENT_ON_PR ]; then
    if [ -z $GITHUB_TOKEN ]; then
        echo "ERROR: COMMENT_ON_PR was set, but GITHUB_TOKEN is not set."
    else
        COMMENT="#### :tropical_drink: \`kulado ${@:2}\`
\`\`\`
$OUTPUT
\`\`\`"
        PAYLOAD=$(echo '{}' | jq --arg body "$COMMENT" '.body = $body')
        echo "Commenting on PR $COMMENTS_URL"
        curl -s -S -H "Authorization: token $GITHUB_TOKEN" -H "Content-Type: application/json" --data "$PAYLOAD" "$COMMENTS_URL"
    fi
fi

exit $EXIT_CODE
