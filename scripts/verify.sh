#!/usr/bin/env bash
# Build and test without starting Spring or connecting to Discord.
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
baseline=false
if [[ "${1:-}" == "--baseline" ]]; then
  baseline=true
  shift
fi
if (( $# )); then
  echo "Usage: scripts/verify.sh [--baseline]" >&2
  exit 2
fi

if [[ "$baseline" == false ]] && ! find "$repo_dir/src/test" -type f -name '*Test.java' -print -quit 2>/dev/null | rg -q .; then
  echo "No test classes found. Use --baseline only to inspect the initial repository." >&2
  exit 1
fi

cd -- "$repo_dir"
git diff --check
reports_dir="$repo_dir/target/surefire-reports"
if command -v mvn >/dev/null && command -v java >/dev/null; then
  mvn --batch-mode --no-transfer-progress -Dstyle.color=never clean verify
elif command -v docker >/dev/null; then
  # Mount only a disposable source snapshot; do not expose .env or a running bot.
  snapshot_dir="$(mktemp -d "${TMPDIR:-/tmp}/discord-mcp-verify.XXXXXX")"
  trap 'rm -rf -- "$snapshot_dir"' EXIT
  cp -- pom.xml "$snapshot_dir/"
  cp -R -- src "$snapshot_dir/"
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    --mount "type=bind,source=$snapshot_dir,target=/workspace" \
    --workdir /workspace \
    --env MAVEN_CONFIG=/tmp/maven \
    --entrypoint mvn \
    maven:3.9.6-amazoncorretto-17 \
    --batch-mode --no-transfer-progress -Dstyle.color=never \
    -Duser.home=/tmp -Dmaven.repo.local=/tmp/m2 clean verify
  # Discard old reports so a previous successful run cannot mask missing tests.
  rm -rf -- "$repo_dir/target/harness"
  mkdir -p target/harness
  cp -R -- "$snapshot_dir/target/." target/harness/
  reports_dir="$repo_dir/target/harness/surefire-reports"
else
  echo "Install Java 17 + Maven, or use Docker." >&2
  exit 1
fi

if [[ "$baseline" == true ]]; then
  echo "Baseline build passed. Existing test coverage may be absent."
else
  python3 - "$reports_dir" <<'PY'
import sys
from pathlib import Path
from xml.etree import ElementTree

reports = Path(sys.argv[1])
files = list(reports.glob('TEST-*.xml'))
tests = failures = errors = skipped = 0
for report in files:
    suite = ElementTree.parse(report).getroot()
    tests += int(suite.get('tests', 0))
    failures += int(suite.get('failures', 0))
    errors += int(suite.get('errors', 0))
    skipped += int(suite.get('skipped', 0))
if tests - skipped <= 0 or failures or errors:
    sys.exit(f'Invalid test results: tests={tests}, skipped={skipped}, failures={failures}, errors={errors}')
print(f'Verification passed: {tests} tests, {skipped} skipped; reports: {reports}')
PY
fi
