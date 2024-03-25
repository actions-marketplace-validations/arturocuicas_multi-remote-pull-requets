#!/bin/sh

set -e
set -x

# Parse YAML array using yq
repositories=$(yq e '.repositories' .github/repositories.yaml)

if [ -z "$INPUT_SOURCE_FOLDER" ]
then
  echo "Source folder must be defined"
  return -1
fi

if [ $INPUT_DESTINATION_HEAD_BRANCH == "main" ] || [ $INPUT_DESTINATION_HEAD_BRANCH == "master"]
then
  echo "Destination head branch cannot be 'main' nor 'master'"
  return -1
fi

if [ -z "$INPUT_PULL_REQUEST_REVIEWERS" ]
then
  PULL_REQUEST_REVIEWERS=$INPUT_PULL_REQUEST_REVIEWERS
else
  PULL_REQUEST_REVIEWERS='-r '$INPUT_PULL_REQUEST_REVIEWERS
fi

for repository in $repositories
do

    CLONE_DIR=$(mktemp -d)

    export GITHUB_TOKEN=$API_TOKEN_GITHUB
    git config --global user.email "$INPUT_USER_EMAIL"
    git config --global user.name "$INPUT_USER_NAME"

    git clone "https://$API_TOKEN_GITHUB@github.com/$repository.git" "$CLONE_DIR"

    mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER/
    cp -r $INPUT_SOURCE_FOLDER "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/"

    cd "$CLONE_DIR"
    git checkout -b "$INPUT_DESTINATION_HEAD_BRANCH"
    git add .

    if git status | grep -q "Changes to be committed"

    then
      git commit --message "Update from https://github.com/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
      git push -u origin HEAD:$INPUT_DESTINATION_HEAD_BRANCH
      gh pr create -t "$INPUT_TITLE" \
                   -b "$INPUT_BODY" \
                   -B $INPUT_DESTINATION_BASE_BRANCH \
                   -H $INPUT_DESTINATION_HEAD_BRANCH \
                      $PULL_REQUEST_REVIEWERS
    else
      echo "No changes detected"
    fi

    cd ..
done