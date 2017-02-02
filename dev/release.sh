#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

function exit_with_usage {
  cat << EOF

release - Creates build distributions from a git commit hash or from HEAD.

SYNOPSIS

usage: release.sh [--release-prepare | --release-publish | --release-snapshot]

DESCRIPTION

Use maven infrastructure to create a project release package and publish
to staging release location (https://oss.sonatype.org/service/local/staging/deploy/maven2)
and maven staging release repository.

--release-prepare --releaseVersion="1.0.0" --developmentVersion="1.1.0-SNAPSHOT" [--releaseRc="rc1"] [--tag="v1.0.0"] [--gitCommitHash="a874b73"]
Execute maven release:prepare and upload the release candidate distribution
to the staging release location (i.e. git repository).

--release-publish --gitCommitHash="a874b73"
Publish the maven artifacts of a release to the Sonatype maven central repository (staging).

--release-snapshot [--gitCommitHash="a874b73"]
Publish the maven snapshot artifacts to Sonatype maven central repository (snapshot).

OPTIONS

--releaseVersion     - Release identifier used when publishing
--developmentVersion - Release identifier used for next development cycle
--releaseRc          - Release RC identifier used when publishing, default 'rc1'
--tag                - Release Tag identifier used when taging the release, default 'v$releaseVersion'
--gitCommitHash      - Release tag or commit to build from, default master HEAD
--dryRun             - Dry run only, mostly used for testing.

A GPG passphrase is expected as an environment variable. You need GPG tools to
create your key and upload to the public server.

GPG_PASSPHRASE - Passphrase for GPG key used to sign release

EXAMPLES

release.sh --release-prepare --releaseVersion="1.0.0" --developmentVersion="1.1.0-SNAPSHOT"
release.sh --release-prepare --releaseVersion="1.0.0" --developmentVersion="1.1.0-SNAPSHOT" --releaseRc="rc1" --tag="v1.0.0"
release.sh --release-prepare --releaseVersion="1.0.0" --developmentVersion="1.1.0-SNAPSHOT" --releaseRc="rc1" --tag="v1.0.0"  --gitCommitHash="7283ab6" --dryRun

release.sh --release-publish --gitCommitHash="7283ab6"
release.sh --release-publish --gitTag="v1.0.0rc1"

release.sh --release-snapshot
release.sh --release-snapshot --gitCommitHash="7283ab6"

EOF
  exit 1
}

set -e

if [ $# -eq 0 ]; then
  exit_with_usage
fi


# Process each provided argument configuration
while [ "${1+defined}" ]; do
  IFS="=" read -ra PARTS <<< "$1"
  case "${PARTS[0]}" in
    --release-prepare)
      GOAL="release-prepare"
      RELEASE_PREPARE=true
      shift
      ;;
    --release-publish)
      GOAL="release-publish"
      RELEASE_PUBLISH=true
      shift
      ;;
    --release-snapshot)
      GOAL="release-snapshot"
      RELEASE_SNAPSHOT=true
      shift
      ;;
    --gitCommitHash)
      GIT_REF="${PARTS[1]}"
      shift
      ;;
    --gitTag)
      GIT_TAG="${PARTS[1]}"
      shift
      ;;
    --releaseVersion)
      RELEASE_VERSION="${PARTS[1]}"
      shift
      ;;
    --developmentVersion)
      DEVELOPMENT_VERSION="${PARTS[1]}"
      shift
      ;;
    --releaseRc)
      RELEASE_RC="${PARTS[1]}"
      shift
      ;;
    --tag)
      RELEASE_TAG="${PARTS[1]}"
      shift
      ;;
    --dryRun)
      DRY_RUN="-DdryRun=true"
      shift
      ;;

    *help* | -h)
      exit_with_usage
     exit 0
     ;;
    -*)
     echo "Error: Unknown option: $1" >&2
     exit 1
     ;;
    *)  # No more options
     break
     ;;
  esac
done

# This is needed to release the maven plugin
if [[ -z "$GPG_PASSPHRASE" ]]; then
    echo 'The environment variable GPG_PASSPHRASE is not set. Enter the passphrase to'
    echo 'unlock the GPG signing key that will be used to sign the release!'
    echo
    stty -echo && printf "GPG passphrase: " && read GPG_PASSPHRASE && printf '\n' && stty echo
fi

if [[ "$RELEASE_PREPARE" == "true" && -z "$RELEASE_VERSION" ]]; then
    echo "ERROR: --releaseVersion must be passed as an argument to run this script"
    exit_with_usage
fi

if [[ "$RELEASE_PREPARE" == "true" && -z "$DEVELOPMENT_VERSION" ]]; then
    echo "ERROR: --developmentVersion must be passed as an argument to run this script"
    exit_with_usage
fi

if [[ "$RELEASE_PUBLISH" == "true"  ]]; then
    if [[ "$GIT_REF" && "$GIT_TAG" ]]; then
        echo "ERROR: Only one argumented permitted when publishing : --gitCommitHash or --gitTag"
        exit_with_usage
    fi
    if [[ -z "$GIT_REF" && -z "$GIT_TAG" ]]; then
        echo "ERROR: --gitCommitHash OR --gitTag must be passed as an argument to run this script"
        exit_with_usage
    fi
fi

if [[ "$RELEASE_PUBLISH" == "true" && "$DRY_RUN" ]]; then
    echo "ERROR: --dryRun not supported for --release-publish"
    exit_with_usage
fi

if [[ "$RELEASE_SNAPSHOT" == "true" && "$DRY_RUN" ]]; then
    echo "ERROR: --dryRun not supported for --release-publish"
    exit_with_usage
fi

# Commit ref to checkout when building
# Change here if you need a different branch
GIT_REF=${GIT_REF:-master}

if [[ "$RELEASE_PUBLISH" == "true" && "$GIT_TAG" ]]; then
    GIT_REF="tags/$GIT_TAG"
fi

BASE_DIR=$(pwd)

MVN="mvn"
PUBLISH_PROFILES="-Pdistribution"

if [ -z "$RELEASE_RC" ]; then
  RELEASE_RC="rc1"
fi

if [ -z "$RELEASE_TAG" ]; then
  RELEASE_TAG="v$RELEASE_VERSION-$RELEASE_RC"
fi

# Github location
RELEASE_STAGING_LOCATION="https://github.com/cloudant-labs/kafka-connect-cloudant"

echo "  "
echo "-------------------------------------------------------------"
echo "------- Release preparation with the following parameters ---"
echo "-------------------------------------------------------------"
echo "Executing           ==> $GOAL"
echo "Git reference       ==> $GIT_REF"
echo "release version     ==> $RELEASE_VERSION"
echo "development version ==> $DEVELOPMENT_VERSION"
echo "rc                  ==> $RELEASE_RC"
echo "tag                 ==> $RELEASE_TAG"
if [ "$DRY_RUN" ]; then
   echo "dry run ?           ==> true"
fi
echo "  "
echo "Deploying to :"
echo $RELEASE_STAGING_LOCATION
echo "  "

function checkout_code {
    # Checkout code
    rm -rf target
    mkdir target
    cd target
    rm -rf kafka-connect-cloudant
    git clone git@github.com:cloudant-labs/kafka-connect-cloudant.git
    cd kafka-connect-cloudant
    git checkout $GIT_REF
    git_hash=`git rev-parse --short HEAD`
    echo "Checked out Kafka Connect Cloudant git hash $git_hash"

    git clean -d -f -x

    cd "$BASE_DIR" #return to base dir
}

if [[ "$RELEASE_PREPARE" == "true" ]]; then
    echo "Preparing release $RELEASE_VERSION"
    # Checkout code
    checkout_code
    cd target/kafka-connect-cloudant

    # Build and prepare the release
    $MVN $PUBLISH_PROFILES release:clean release:prepare $DRY_RUN -Darguments="-Dgpg.passphrase=\"$GPG_PASSPHRASE\" -DskipTests" -DreleaseVersion="$RELEASE_VERSION" -DdevelopmentVersion="$DEVELOPMENT_VERSION" -Dtag="$RELEASE_TAG"

    cd .. #exit kafka-connect-cloudant

    cd "$BASE_DIR" #exit target

    exit 0
fi

### ?? Is this to publidh to the maven repo?
if [[ "$RELEASE_PUBLISH" == "true" ]]; then
    echo "Preparing release $RELEASE_VERSION"
    # Checkout code
    checkout_code
    cd target/kafka-connect-cloudant

    #Deploy
    mvn $PUBLISH_PROFILES -DaltDeploymentRepository=sonatype-nexus-staging::default::https://oss.sonatype.org/service/local/staging/deploy/maven2 clean package gpg:sign install:install deploy:deploy -DskiptTests -Dmaven.test.skip=true -Darguments="-DskipTests" -Dgpg.passphrase=$GPG_PASSPHRASE

    mvn clean

    cd "$BASE_DIR" #exit target

    exit 0
fi


if [[ "$RELEASE_SNAPSHOT" == "true" ]]; then
    # Checkout code
    checkout_code
    cd target/kafka-connect-cloudant

    CURRENT_VERSION=$($MVN help:evaluate -Dexpression=project.version \
    | grep -v INFO | grep -v WARNING | grep -v Download)

    # Publish Kafka Connect Cloudant Snapshots to Maven snapshot repo
    echo "Deploying Kafka Connect Cloudant SNAPSHOT at '$GIT_REF' ($git_hash)"
    echo "Publish version is $CURRENT_VERSION"
    if [[ ! $CURRENT_VERSION == *"SNAPSHOT"* ]]; then
        echo "ERROR: Snapshots must have a version containing SNAPSHOT"
        echo "ERROR: You gave version '$CURRENT_VERSION'"
        exit 1
    fi

    #Deploy
    $MVN $PUBLISH_PROFILES -DaltDeploymentRepository=sonatype-nexus-staging::default::https://oss.sonatype.org/content/repositories/snapshots clean package gpg:sign install:install deploy:deploy -DskiptTests -Dmaven.test.skip=true -Darguments="-DskipTests" -Dgpg.passphrase=$GPG_PASSPHRASE

    cd "$BASE_DIR" #exit target
    exit 0
fi


cd "$BASE_DIR" #return to base dir
rm -rf target
echo "ERROR: wrong execution goals"
exit_with_usage
