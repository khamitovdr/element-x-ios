#!/bin/sh

# Return on failures
# Fail when expanding unset variables
# Trace each command before executing it
set -eEu

install_xcode_cloud_brew_dependencies () {
    brew update && brew install xcodegen pkl getsentry/tools/sentry-cli
}

setup_github_actions_environment() {
    xcode_select_for_github_actions
    
    unset HOMEBREW_NO_INSTALL_FROM_API
    export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

    # FORK-CI (2026-07-16): homebrew/core's xcodegen 2.46.0 bottle is broken —
    # its manifest points at the 2.45.4 blob, so the pour creates Cellar/xcodegen/2.45.4
    # and brew dies with "Cellar/xcodegen/2.46.0 is not a directory" (verified by
    # inspecting the bottle tar). Install xcodegen from the official release zip
    # instead. Remove this block and re-add xcodegen to the brew line once
    # `brew install xcodegen` pours cleanly again.
    curl -fsSL -o /tmp/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip
    unzip -oq /tmp/xcodegen.zip -d /tmp/xcodegen-dist
    sudo mkdir -p /usr/local/bin /usr/local/share
    sudo rm -rf /usr/local/share/xcodegen
    sudo cp -R /tmp/xcodegen-dist/xcodegen/share/xcodegen /usr/local/share/
    sudo install /tmp/xcodegen-dist/xcodegen/bin/xcodegen /usr/local/bin/xcodegen
    xcodegen --version

    brew update && brew install swiftlint swiftformat git-lfs pkl a7ex/homebrew-formulae/xcresultparser
}

setup_github_actions_translations_environment() {
    xcode_select_for_github_actions
    
    unset HOMEBREW_NO_INSTALL_FROM_API
    export HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1

    brew update && brew install swiftgen mint localazy/tools/localazy

    mint install Asana/locheck
}

xcode_select_for_github_actions() {
    # We need to select it globally for other processes like xcresultparser and our custom tools to use the same Xcode version.
    sudo xcode-select -s /Applications/Xcode_26.5.0.app
}

generate_what_to_test_notes() {
    if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
        TESTFLIGHT_DIR_PATH=TestFlight
        TESTFLIGHT_NOTES_FILE_NAME=WhatToTest.en-US.txt
        
        LATEST_TAG=""
        if [ "$CI_WORKFLOW" = "Release" ]; then
            # Use -v to invert grep, searching for non-nightlies
            LATEST_TAG=$(git tag --sort=-creatordate | grep -v 'nightly' | head -n1)
        elif [ "$CI_WORKFLOW" = "Nightly" ]; then
            LATEST_TAG=$(git tag --sort=-creatordate | grep 'nightly' | head -n1)
        fi

        if [[ -z "$LATEST_TAG" ]]; then
            echo "generate_what_to_test_notes: Failed fetching previous tag"
            return 0 # Continue even though this failed
        fi

        echo "generate_what_to_test_notes: latest tag is $LATEST_TAG"

        mkdir $TESTFLIGHT_DIR_PATH

        NOTES="$(git log --pretty='- %an: %s' "$LATEST_TAG"..HEAD)"

        echo "generate_what_to_test_notes: Generated notes:\n"$NOTES""

        echo "$NOTES" > $TESTFLIGHT_DIR_PATH/$TESTFLIGHT_NOTES_FILE_NAME
    fi
}

fetch_unshallow_repository() {
    # Xcode Cloud shallow clones the repo. We need to deepen it to fetch tags, commit history and be able to rebase main on develop at the end of releases.
    git fetch --unshallow --quiet
}
