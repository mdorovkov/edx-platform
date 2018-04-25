#!/bin/bash
set -e

###############################################################################
#
#   unit-tests.sh
#
#   Execute Python unit tests for edx-platform.
#
#   This script is typically called from generic-ci-tests.sh, which defines
#   these environment variables:
#
#   `TEST_SUITE` defines which kind of test to run.
#   Possible values are:
#
#       - "lms-unit": Run the LMS Python unit tests
#       - "cms-unit": Run the CMS Python unit tests
#       - "commonlib-unit": Run Python unit tests from the common/lib directory
#
#   `SHARD` is a number indicating which subset of the tests to build.
#
#       For "lms-unit", the tests are put into shard groups
#       using the 'attr' decorator (e.g. "@attr(shard=1)"). Anything with
#       the 'shard=n' attribute will run in the nth shard. If there isn't a
#       shard explicitly assigned, the test will run in the last shard.
#
#   This script is broken out so it can be run by tox and redirect stderr to
#   the specified file before tox gets a chance to redirect it to stdout.
#
###############################################################################

PAVER_ARGS="-v"
PARALLEL="--processes=-1"

# Skip re-installation of Python prerequisites inside a tox execution.
if [[ -n "$TOXENV" ]]; then
    export NO_PREREQ_INSTALL="True"
fi

case "${TEST_SUITE}" in

    "lms-unit")
        case "$SHARD" in
            "all")
                paver test_system -s lms --disable_capture ${PAVER_ARGS} ${PARALLEL} 2> lms-tests.log
                ;;
            [1-5])
                paver test_system -s lms --disable_capture --eval-attr="shard==$SHARD" ${PAVER_ARGS} ${PARALLEL} 2> lms-tests.${SHARD}.log
                ;;
            6|"noshard")
                paver test_system -s lms --disable_capture --eval-attr='not shard' ${PAVER_ARGS} ${PARALLEL} 2> lms-tests.4.log
                ;;
        esac
        ;;

    "cms-unit")
        paver test_system -s cms --disable_capture ${PAVER_ARGS} 2> cms-tests.log
        ;;

    "commonlib-unit")
        case "$SHARD" in
            "all")
                paver test_lib --disable_capture ${PAVER_ARGS} 2> common-tests.log
                ;;
            1)
                paver test_lib -l common/lib/xmodule --disable_capture --eval-attr="shard==$SHARD" ${PAVER_ARGS} 2> common-tests.log
                ;;
            2|"noshard")
                paver test_lib --disable_capture --eval-attr='not shard' ${PAVER_ARGS} 2> common-tests.log
                ;;
        esac
        ;;
esac
