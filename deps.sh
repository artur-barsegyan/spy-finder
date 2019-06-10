#!/bin/sh
# Call this scripts to install spy-finder's dependencies

set -e

tarantoolctl rocks make ./spy-finder-scm-1.rockspec
