#!/bin/sh

# Only run on Archive actions (TestFlight distribution)
if [ "$CI_XCODEBUILD_ACTION" != "archive" ]; then
    exit 0
fi

mkdir -p TestFlight

OUTPUT_FILE="TestFlight/WhatToTest.en-US.txt"

# PR title (if built from a PR)
if [ -n "$CI_PULL_REQUEST_NUMBER" ]; then
    REPO=$(echo "$CI_PULL_REQUEST_HTML_URL" | sed 's|https://github.com/||' | sed 's|/pull/.*||')

    if [ -n "$GITHUB_TOKEN" ]; then
        PR_RESPONSE=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
            "https://api.github.com/repos/$REPO/pulls/$CI_PULL_REQUEST_NUMBER")
    else
        PR_RESPONSE=$(curl -s \
            "https://api.github.com/repos/$REPO/pulls/$CI_PULL_REQUEST_NUMBER")
    fi

    PR_TITLE=$(echo "$PR_RESPONSE" | jq -r '.title')

    echo "[PR #$CI_PULL_REQUEST_NUMBER] $PR_TITLE" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# Recent 3 commit messages
echo "Recent commits:" >> "$OUTPUT_FILE"
git log --oneline -3 | while read -r line; do
    echo "  - $line" >> "$OUTPUT_FILE"
done
