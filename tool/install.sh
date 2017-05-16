#!/usr/bin/env sh

# Usage:
# ------
# This script installs `jxa-async`.
#
# `install.sh` can be invoked either locally (from a source-code clone of the library), or remotely
# (via `curl`).  In either case, there are two ways to include the `jxa-async` shim into your JXA
# scripts — using JXA's built-in [`Library` feature][1], or including it into a script-bundle you're
# already constructing using [Browserify][2] or similar.
#
# ### Script Library: `--Library`
# If you're not already bundling your script, the easiest way is `Library()`. JXA theoretically
# looks for Script Libraries in several places, but [in practice][3] it should be placed in
# `~/Library/Script Libraries`; this will make `jxa-async` available to any JXA script running as
# your current user. The install-script will do this for you by default.
#
#     # Use one command to download the latest version and install it to
#     # '~/Library/Script Libraries':
#     sh <( curl -Lf https://git.io/jxa-async )
#     sh <( curl -Lf https://git.io/jxa-async ) --Library
#
#     # Or, if you cloned the source-code locally, use `npm install` to build and
#     # install to '~/Library/Script Libraries' from the current directory:
#     ./tool/install.sh
#     ./tool/install.sh --Library
#
#     # You can also tell the script to install the Script Library for all users (not
#     # recommended!):
#     sudo ALL_USERS=yes ./tool/install.sh
#
# When installed thusly, `jxa-async`'s `shim()` may be invoked on the first line of your JXA script
# as follows:
#
#     Library('Async').shim(this)
#
# ### CommonJS: `--cjs`
# If you're using Browserify or webpack or another bundling-tool, preprocessor, or similar, it may
# be easier to allow your existing bundling-tools to consume `jxa-async`. Note, however, that
# there's no `require()` in raw JXA, so this approach is only feasible when your tooling *provides*
# `require()`.
#
#     # You can simply use your `npm`-compatible package-manager to install the
#     # CommonJS module:
#     yarn install jxa-async
#
#     # Alternatively, use `install.sh` to download the latest version to the
#     # subdirectory './jxa-async':
#     sh <( curl -Lf https://git.io/jxa-async ) --cjs
#
# Then you can use your bundler's runtime-tooling to access `shim()`. (Depending on how your bundler
# works, be careful to ensure that no other package's source-code is evaluated before you've done
# so!)
#
# Example: using Browserify, you might use `browserify --require './vendor/jxa-async:jxa-async'`,
# then,
#
#     require('jxa-async').shim(this)
#
#
# [1]: <https://developer.apple.com/library/content/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/Articles/OSX10-10.html#//apple_ref/doc/uid/TP40014508-CH109-SW14>
#     "JavaScript for Automation documentation — Libraries"
# [2]: <https://github.com/dtinth/JXA-Cookbook/wiki/Importing-Scripts#commonjs--browserify>
#     "JXA Cookbook — Importing Scripts — CommonJS + Browserify"
# [3]: <http://stackoverflow.com/questions/35389058/why-wont-osa-library-path-not-work-as-documented-for-jxa/35528626#35528626>
#     "Why won't OSA_LIBRARY_PATH not work as documented for JXA?"


# We wrap the entire script in a big function which we only call at the very end, in order to
# protect against the possibility of the connection dying mid-script. This protects us against the
# problem described in this blog post:
#     <http://blog.existentialize.com/dont-pipe-to-your-shell.html>
#--
# (Approach copied from <https://install.sandstorm.io>:
#     <https://sandstorm.io/news/2015-09-24-is-curl-bash-insecure-pgp-verified-install>)
_() {


# ### Setup & helpers
unset term_in term_in print_commands                                          \
      effective_user_name                                                     \
      is_root is_sudo reexec_as

puts() { printf %s\\n "$@" ;}
pute() { printf %s\\n "~~ $*" >&2 ;}
argq() { [ $# -gt 0 ] && printf "'%s' " "$@" ;}

[ -t 0 ] && term_in=yes
[ -t 1 ] && term_out=yes
[ -z "${0%%*.sh}" ]        && sh_file=yes
[ -z "${0%%/dev/fd/*}" ]   && fd_input=yes

effective_user_name="$(id -un)"

# Prompts the user for a yes-or-no answer; needs a $1. a string and $2. a default value. Ignores
# redirection, reads directly from /dev/tty.
yn() {
   printf %s "$1 "

   if [ -z "$term_in" ] && [ -z "$term_out" ]; then
      printf \\n
      puts "~~ (NON-INTERACTIVE, defaulting to ‘${2}’.)"
      case "$2" in
         [Yy]*) return 0                                                      ;;
         [Nn]*) return 1                                                      ;;
      esac

   else
      while true; do
         read answer </dev/tty
         case "${answer:-$2}" in
            [Yy]*) return 0                                                   ;;
            [Nn]*) return 1                                                   ;;
            *)     printf %s "Please enter ‘YES’ or ‘NO’: "                   ;;
         esac
      done
   fi
}

canonical_location="https://raw.githubusercontent.com/ELLIOTTCABLE/jxa-async/Stable/tool/install.sh"


# FIXME: This should support *excluded* modules with a minus, for parity with `node-debug`:
#           <https://github.com/visionmedia/debug>
if echo "$DEBUG" | grep -qE '(^|,\s*)(\*|jxa-async(:(scripts|\*))?)($|,)'; then
   pute "Script debugging enabled (in: install.sh)."
   DEBUG_SCRIPTS=yes
   VERBOSE="${VERBOSE:-7}"
fi

[ -z "${SILENT##[NFnf]*}${QUIET##[NFnf]*}" ] && [ "${VERBOSE:-4}" -gt 6 ] && print_commands=yes
go() { [ -z ${print_commands+0} ] || puts '`` '"$(argq "$@")" >&2 ; "$@" || exit $? ;}

[ -n "$DEBUG_SCRIPTS" ] && puts \
   "\$0:                   '${0}'"                                            \
   "Args:                 $(argq "$@")"                                       \
   "Terminal input:        ${term_in:--no}"                                   \
   "Terminal output:       ${term_out:--no}"                                  \
   "Evaluated via pipe:    ${sh_file:--yes}"                                  \
   "Evaluated via fd:      ${fd_input:--no}"                                  \
   ""                                                                         \
   "Effective user-name:  '${effective_user_name}'"                           \
   "\`sudo\` user:          '${SUDO_USER}'"                                   \
   "" >&2

[ -n "$DEBUG_SCRIPTS" ] && [ "${VERBOSE:-4}" -gt 8 ] && \
   pute "Environment variables:" && env >&2


# ### Reasonableness-checking
# First, JXA only remotely makes sense on a Mac; and this script uses BSD-derivative commands
# hereafter:
if [ "$(uname -s)" != "Darwin" ]; then
   puts 'FATAL: `jxa-async` can only be meaningfully installed on macOS.' && exit 10       ;fi

# Second, we're going to do some courtesy-checks on the user's level of permissions.  This is
# obviously not *secure*, but it's not intended to be — it's to help educate new programmers, and
# help avoid dumb absent-minded errors.
if [ -z "${IGNORE_USER##[NFnf]*}" ]; then
   [ "$(id -u)" = 0 ]   && is_root=yes
   [ -n "$SUDO_USER" ]  && is_sudo=yes

   if [ -n "$is_root" ] && [ -n "$is_sudo" ]; then
      puts "!! YOU APPEAR TO BE RUNNING THIS SCRIPT WITH ROOT PRIVILEGES."
      puts "  (The author considers this to be ill-advised.)"
      puts ""
      puts "   Discard permissions and return to ‘${SUDO_USER}’ (YES), or remain as root (no)?"
      if yn '>' YES; then
         reexec_as="$SUDO_USER"
      else
         [ -n "$DEBUG_SCRIPTS" ] && pute "User confirmed installing as root!"
      fi

   elif [ -n "$is_sudo" ]; then
      puts "!! You appear to be running the script as ‘${effective_user_name}’ instead of as"
      puts "   yourself (‘${SUDO_USER}’). Was this an accident (yes), or should I"
      puts "   continue and install to ‘${HOME}’ (NO)?"
      if yn '>' NO; then
         reexec_as="$SUDO_USER"
      else
         [ -n "$DEBUG_SCRIPTS" ] && pute "User confirmed installing as '${effective_user_name}'."
      fi
   fi

   if [ -n "$reexec_as" ]; then
      export DEBUG_SCRIPTS VERBOSE                                            \
         IGNORE_USER=yes

      if [ -n "$sh_file" ]; then
         [ -n "$DEBUG_SCRIPTS" ] && pute "Re-evaluating local script as '${reexec_as}'."
         go exec sudo -Eu "$reexec_as" /usr/bin/env sh "$0"

      else
         [ -n "$DEBUG_SCRIPTS" ] && pute "Re-evaluating remote script as '${reexec_as}'."
         go curl -Lf "$canonical_location" |                                  \
            go exec sudo -Eu "$reexec_as" /usr/bin/env sh "$@"
      fi

   fi
else
   [ -n "$DEBUG_SCRIPTS" ] && pute "Ignoring current user / permissions ..."
fi

#  Now that we know the whole script has downloaded, run it.
}; _ "$@"
