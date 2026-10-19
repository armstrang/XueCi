#!/bin/sh
# Development only: set up the pinned Flutter SDK in a Claude cloud session, which cannot reach Flutter's download
# servers or pub.dev. The workflow .github/workflows/flutter-sdk.yml (push to tools/flutter-sdk) packs the SDK and
# the pub cache into the pre-release "dev-flutter-sdk"; this downloads and unpacks it to /opt/flutter + /opt/pub-cache.
#
#   sh mobile/tool/cloud_sdk.sh && . /opt/flutter-env.sh
#   cd mobile && FLUTTER_ROOT=/opt/flutter dart pub get --offline
#   flutter analyze --no-pub        flutter test --no-pub        (always --no-pub: pub.dev is unreachable)
set -e
R=armstrang/XueCi
D=/opt/flutter-dl
mkdir -p $D
gh api repos/$R/releases --jq '.[] | select(.tag_name=="dev-flutter-sdk") | .assets[] | [.id,.name] | @tsv' > $D/ids.txt
while read id name; do gh api -H 'Accept: application/octet-stream' repos/$R/releases/assets/$id > "$D/$name"; done < $D/ids.txt
(cd $D && sha256sum -c SHA256SUMS)
cat $D/flutter-sdk.tar.xz.part* | xz -d -T0 | tar -x -C /opt
xz -d -T0 < $D/pub-cache.tar.xz | tar -x -C /opt
rm -rf $D
# the packed tool resolved its packages on the CI runner; point them at this pub cache
sed -i 's#file:///home/runner/.pub-cache#file:///opt/pub-cache#g' /opt/flutter/packages/flutter_tools/.dart_tool/package_config.json /opt/flutter/packages/flutter_tools/.dart_tool/package_graph.json
# the Gradle wrapper is left out of the pack (no Android builds here); placeholders keep the tool from fetching it
G=/opt/flutter/bin/cache/artifacts/gradle_wrapper
mkdir -p $G/gradle/wrapper && touch $G/gradlew $G/gradlew.bat $G/gradle/wrapper/gradle-wrapper.jar
git config --global --add safe.directory /opt/flutter
cat > /opt/flutter-env.sh <<'X'
export PATH=/opt/flutter/bin:$PATH
export PUB_CACHE=/opt/pub-cache
export FLUTTER_ROOT=/opt/flutter
export FLUTTER_SUPPRESS_ANALYTICS=true
export CI=true
export BOT=true
export PUB_ENVIRONMENT=flutter_bot
X
echo "Flutter ready: . /opt/flutter-env.sh"
