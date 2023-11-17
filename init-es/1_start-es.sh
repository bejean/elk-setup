#!/usr/bin/env bash

set -eu
set -o pipefail

source "${BASH_SOURCE[0]%/*}"/env.sh

bin/elasticsearch -d -p pid

