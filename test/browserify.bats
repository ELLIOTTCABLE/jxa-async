load 'common'

@test "that Browserify successfully bundles jxa-async" {
   browserify --require "$TWD:jxa-async"
}

@test "execution of the Browserified bundle within JXA" {
   SCRIPT="console.log( require('jxa-async').VERSION )"

   echo "$SCRIPT" | osaify --require "$TWD:jxa-async" - > bundle.js
   assert_success && assert [ -e bundle.js ]

   run osascript -l JavaScript bundle.js
   assert_success
   assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]$'
}


osaify() {
   BUNDLE=$('browserify' "$@")
   puts 'window = (function(){ return this })();'
   puts "$BUNDLE"
   puts 'ObjC.import("stdlib");$.exit(0)'
}
