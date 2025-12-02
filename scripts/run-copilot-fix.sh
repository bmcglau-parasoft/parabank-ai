#!/bin/bash

MVN=
GIT_TYPE=GitHub
GIT_PULL_REQUEST_ID=
GIT_PROJECT=XTEST
GIT_OWNER="bmcglau-parasoft"
GIT_REPO="parabank-ai"
GIT_BASEURL="https://api.github.com"
GIT_USER="bmcglau-parasoft"

SA_CONFIG="builtin://Demo Configuration"
SA_SETTINGS="scripts/jtestcli.properties"
TESTGEN_SETTINGS="scripts/testgen.properties"

function print_usage() {
	echo "Must be run from root folder of Parabank-AI repo"
	echo ""
	echo "  Usage:  run-copilot-fix.sh --pull-request <id> --git-auth <token> [<options>]"
	echo ""
	echo "Options:  --pull-request <id>               The ID of the pull-request on Github or Bitbucket"
	echo "          --git-base-url <url>              Overrides base URL for pull-request API calls"
	echo "          --git-type <GitHub|BitBucket>     Default: GitHub"
	echo "          --git-owner <github_owner>        Only used for GitHub"
	echo "          --git-project <bitbucket_project> Only used for BitBucket"
	echo "          --git-repo <repository_name>      Name of the repository"
	echo "          --git-auth <token>                Overrides token for making pull-request API calls"
	echo "                                            If using GitHub, should be in format 'Bearer <token>'"
	echo "                                            Must provide permissions to make editing calls to pull-requests"
	echo "          --git-user <username>             Username for interacting with pull-request API"
	echo "                                            Must match the auth token"
	echo "          --sa-config <configuration>       Jtest configuration to use when performing static analysis"
	echo "                                            Default: 'builtin://Demo Configuration'"
	echo "          --sa-settings <settings>          Path to the .properties file for Jtest settings"
	echo "          --testgen-settings <settings>     Path to the .properties file for Jtest bulk creation"
	echo "          --maven-path <path>               Path to maven home - bin/mvn should be relative to this directory"
}
function missingArg () {
	echo "ERROR:  missing argument for:  $1"
	print_usage
	exit 1
}

while (( "$#" ))
do
	case "$1" in
		--help )			print_usage; exit 0 ;;
		--pull-request )	GIT_PULL_REQUEST_ID="${2// }";	shift 2 || missingArg --pull-request ;;
		--git-type )		GIT_TYPE="${2// }";				shift 2 || missingArg --git-type
			if [[ "$GIT_TYPE" == "BitBucket" ]]; then
				GIT_BASEURL="https://trove.parasoft.com/rest/api/latest/projects"
				GIT_USER="jenkins-git"
			fi
			;;
		--git-project )		 GIT_PROJECT="${2// }";		 shift 2 || missingArg --git-project  ;;
		--git-owner )		 GIT_OWNER="${2// }";		 shift 2 || missingArg --git-owner	  ;;
		--git-repo )		 GIT_REPO="${2// }";		 shift 2 || missingArg --git-repo	  ;;
		--git-base-url )	 GIT_BASEURL="${2// }";		 shift 2 || missingArg --git-base-url ;;
		--git-auth )		 GIT_AUTH="${2// }";		 shift 2 || missingArg --git-auth	  ;;
		--git-user )		 GIT_USER="${2// }";		 shift 2 || missingArg --git-user	  ;;
		--sa-config )		 SA_CONFIG="${2// }";		 shift 2 || missingArg --sa-config	  ;;
		--sa-settings )		 SA_SETTINGS="${2// }";		 shift 2 || missingArg --sa-settings  ;;
		--testgen-settings ) TESTGEN_SETTINGS="${2// }"; shift 2 || missingArg --testgen-settings  ;;
		--maven-path )       MVN_PATH="${2// }/bin/mvn"; shift 2 || missingArg --maven-path
			if [[ -f "$MVN_PATH" ]]; then
				MVN="$MVN_PATH"
			else
				echo "mvn not found at $MVN_PATH"
				exit 1
			fi
			shift 2
			;;
		* )
			echo "ERROR:  parameter not understood:  $1"
			print_usage
			exit 1
			;;
	esac
done

if [[ -z "$GIT_PULL_REQUEST_ID" ]]; then
	echo "ERROR: Missing --pull-request arg"
	print_usage
	exit 1
fi

if [[ -z "$GIT_AUTH" ]]; then
	echo "ERROR: Missing --git-auth arg"
	print_usage
	exit 1
fi

if [[ -z "$MVN" || ! -f "$MVN" ]]; then
	MVN=$(which mvn)
	if [[ ! -f "$MVN" ]]; then
		echo "ERROR: Maven not found"
		exit 1
	fi
fi
echo "Maven found at $MVN"
"$MVN" --version

STATUS=ok
SUMMARY="# Analysis Summary"$'\n'

set -x

case "$GIT_TYPE" in
	BitBucket )		source ./scripts/bitbucket.sh	;;
	GitHub )		source ./scripts/github.sh		;;
	* )
		echo "ERROR: --git-type $GIT_TYPE not supported."
		print_usage
		exit 1
		;;
esac

start_review
if [[ -d .jtest ]]; then
	echo "Cleaning .jtest folder"
	rm -rf .jtest
fi

# Perform SA on modified files and generate report.xml
echo ""
echo "=====[ Performing static analysis on modified files ]====="
echo ""
SUMMARY+="## Static Analysis"$'\n'
"$MVN" clean package jtest:jtest -Dmaven.test.skip=true -Djtest.config="$SA_CONFIG" -Djtest.settings="$SA_SETTINGS"
SUMMARY+="1. Jtest performed analysis on modified files using the \"$SA_CONFIG\" configuration"$'\n'
PROJECT_NAME=$(jq -r '.name' target/jtest/jtest.data.json)
echo "Found project name $PROJECT_NAME"

# Configure environment variables and ask CoPilot CLI to fix violations using Jtest MCP server to get the violations, docs etc. For successful fixes, add a commit for each one.
NUM_VIOLATIONS=$(cat target/jtest/report.xml | sed -n "s/.*Goals tsks=\"\([0-9]\+\)\".*/\1/p")
if [[ -z "$NUM_VIOLATIONS" ]]; then
	NUM_VIOLATIONS=0
fi
echo "Jtest found $NUM_VIOLATIONS violations"
SUMMARY+="2. Jtest found $NUM_VIOLATIONS violations"$'\n'

if [[ -n "$NUM_VIOLATIONS" ]]; then
	echo ""
	echo "=====[ Ask Copilot CLI to fix violations and commit them ]====="
	echo ""
	export BASELINE_REPORT=target/jtest/report.xml
	#export JTEST_HOME="C:/Program Files/Parasoft/jtest-2025.2.0"      # Should be set by the job, or on the workstation ENV
	export JTEST_SETTINGS="$SA_SETTINGS"
	
	rm -rf scripts/copilot_summary.md
	copilot -p "Using @scripts/copilot-instructions.md, fix violations" --model claude-sonnet-4.5 --allow-all-tools --allow-all-paths --log-dir .copilot/logs/
	
	if [[ -f scripts/copilot_summary.md ]]; then
		SUMMARY+="3. Summary from Copilot CLI:"$'\n'
		SUMMARY+=$(cat scripts/copilot_summary.md)
		SUMMARY+=$'\n'
	else 
		SUMMARY+="3. ** No summary from Copilot CLI! **"$'\n'
	fi

	# If there's any local commits to add to the pull-request, push them now
	NEEDS_PUSH=$(git status | grep -c -e 'is ahead of ')
	if [[ -n "$NEEDS_PUSH" ]]; then
		echo "Pushing changes to update pull-request"
		git push
		SUMMARY+="4. Fixes added to pull-request"$'\n'
		STATUS=review
	else
		echo "No violation fixes to submit"
		SUMMARY+="4. No fixes to push"$'\n'
	fi
else
	echo "No violations for Copilot to fix"
	SUMMARY+="3. No violations for Copilot to fix"$'\n'
	SUMMARY+="4. No fixes to push"$'\n'
fi

# Run impacted tests with Jtest
# TODO: Make this a TIA run
echo ""
echo "=====[ Run Junit tests ]====="
echo ""
"$MVN" test -P run-tia -Dmaven.test.failure.ignore=true
SUMMARY+="## Junit test execution"$'\n'
if [[ -f "target/reports/surefire.html" ]]; then
	rm -rf scripts/test_failures.md
	rm -rf scripts/test_results.md
	copilot -p "Examine the Surefire report at @target/reports/surefire.html. Create a simple markdown report containing the test name and failure message for each error or failure, plus the total number of tests that ran, passed, or failed. If there were any failures, write this report to scripts/test_failures.md; otherwise, write the report to scripts/test_results.md." --model claude-sonnet-4.5 --allow-all-tools --allow-all-paths --log-dir .copilot/logs/
	if [[ -f "scripts/test_failures.md" ]]; then
		echo "There are test failures. The pull-request will be marked as 'Needs Work'."
		COMMENT=$(cat scripts/test_failures.md)
		SUMMARY+="$COMMENT"$'\n'
		STATUS=needsWork
	else
		if [[ -f "scripts/test_results.md" ]]; then
			COMMENT=$(cat scripts/test_results.md)
			SUMMARY+="$COMMENT"$'\n'
		else
			echo "ERROR: No test summary found!"
			SUMMARY+="** No summary from Copilot CLI! **"$'\n'
		fi
	fi
else
	echo "ERROR: No single surefire report was found at target/reports/surefire.html."
	echo "       Make sure you have maven-surefire-report-plugin added to your pom.xml"
	SUMMARY+="** No surefire report was found for executed tests! **$'\n'"
fi

# Perform Jtest CLI bulk test creation for modified source files. Commit changes and push to add to pull-request.
echo ""
echo "=====[ Create Junit tests for modified or new code ]====="
echo ""
get_modified_resources
"$MVN" jtest:jtest -Djtest.config="builtin://Create Unit Tests" -Djtest.settings="$TESTGEN_SETTINGS" -Djtest.resources="$RESOURCES"
SUMMARY+="## Test creation for modified code"$'\n'

MODIFIED=$(git diff --name-only HEAD -- "*.java")
if [[ ! -z "$MODIFIED" ]]; then
	echo "Modified java code detected - adding to pull-request"
	git add "*.java"
	git commit -m "Parasoft Jtest: Adding Junit tests for modified code $PULL_REQUEST_ID"
	git push
	SUMMARY+="Tests were committed to this pull-request"$'\n'
	if [[ "$STATUS" == "ok" ]]; then
		STATUS=review
	fi
else
	SUMMARY+="No tests were added"$'\n'
fi

echo ""
echo ""
echo "=====[ Adding summary comment and updating status ]====="
finish_review "$SUMMARY" "$STATUS"

echo ""
echo "=====[ Done ]====="
