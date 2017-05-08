load '../node_modules/bats-support/load'
load '../node_modules/bats-assert/load'
load '../node_modules/bats-file/load'

puts() { printf %s\\n "$@" ;}
pute() { printf %s\\n "~~ $*" >&2 ;}

TWD="$PWD"

pathadd() {
   if [ -d "$1" ] && [[ ":$PATH:" != *":$1:"* ]]; then
      PATH="$1${PATH:+":$PATH"}"                ; fi ;}

absolute() {
   (cd "$(dirname '$1')" &>/dev/null && printf "%s/%s" "$PWD" "${1##*/}") ;}

pathadd "$(absolute './node_modules/.bin')"

contains() { [ -z "${1##*$2*}" ] && [ -z "$2" -o -n "$1" ] ;}


# Use `temp_make` from `bats-file` to generate a new directory for each test
#---
# FIXME: Pending macOS support in bats-file:
#           <https://github.com/ztombol/bats-file/issues/3>
setup() {
  #temp_dir="$(temp_make --prefix 'jxa-async-')"
   temp_dir="$(mktemp -dt 'jxa-async')" || exit 1
   BATSLIB_FILE_PATH_REM="#${temp_dir}"
   BATSLIB_FILE_PATH_ADD='{temp_dir}'

   BATS_SUITE="$(basename "$BATS_TEST_FILENAME" '.bats')"
   FIXTURE="$BATS_TEST_DIRNAME/fixtures/$BATS_SUITE--$BATS_TEST_NAME"

   cd "$temp_dir"
}
teardown() {
   cd "$TWD"
   temp_del "$temp_dir"
}
