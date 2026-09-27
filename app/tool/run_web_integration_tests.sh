#!/usr/bin/env bash

set -euo pipefail

app_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_root"

chrome="${CHROME_EXECUTABLE:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "$chrome" ]]; then
  echo "Chrome executable not found: $chrome" >&2
  echo "Set CHROME_EXECUTABLE to the browser binary you want to test." >&2
  exit 1
fi

chrome_version="$("$chrome" --version | sed -E 's/.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
if [[ ! "$chrome_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Could not determine Chrome version from: $("$chrome" --version)" >&2
  exit 1
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64) platform="mac-arm64" ;;
  Darwin-x86_64) platform="mac-x64" ;;
  *)
    echo "Unsupported host for automatic ChromeDriver download: $(uname -s)-$(uname -m)" >&2
    echo "Install a matching ChromeDriver manually and set CHROMEDRIVER." >&2
    exit 1
    ;;
esac

driver="${CHROMEDRIVER:-$app_root/.tools/chromedriver/$chrome_version/chromedriver}"
if [[ ! -x "$driver" ]]; then
  if [[ -n "${CHROMEDRIVER:-}" ]]; then
    echo "CHROMEDRIVER is not executable: $driver" >&2
    exit 1
  fi

  tmp_dir="$app_root/.tools/tmp"
  mkdir -p "$tmp_dir"
  archive="$(mktemp "$tmp_dir/chromedriver.XXXXXX").zip"
  extract_dir="$(mktemp -d "$tmp_dir/chromedriver_extract.XXXXXX")"
  trap 'rm -f "$archive"; rm -rf "$extract_dir"' EXIT
  url="https://storage.googleapis.com/chrome-for-testing-public/$chrome_version/$platform/chromedriver-$platform.zip"

  echo "Downloading ChromeDriver $chrome_version for $platform..."
  curl --fail --location --silent --show-error "$url" --output "$archive"
  unzip -q "$archive" -d "$extract_dir"
  mkdir -p "$(dirname "$driver")"
  cp "$extract_dir/chromedriver-$platform/chromedriver" "$driver"
  chmod +x "$driver"
  xattr -d com.apple.quarantine "$driver" 2>/dev/null || true
fi

driver_version="$($driver --version | sed -E 's/.* ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
if [[ "${chrome_version%%.*}" != "${driver_version%%.*}" ]]; then
  echo "ChromeDriver $driver_version does not match Chrome $chrome_version." >&2
  echo "Set CHROMEDRIVER to a matching binary or remove the cached driver." >&2
  exit 1
fi

port="${DRIVER_PORT:-4444}"
while lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do
  port=$((port + 1))
done

mkdir -p "$app_root/.tools"
log_file="$app_root/.tools/chromedriver.log"

echo "Using Chrome $chrome_version with ChromeDriver $driver_version on port $port."
"$driver" --port="$port" >"$log_file" 2>&1 &
driver_pid=$!
trap 'kill "$driver_pid" 2>/dev/null || true' EXIT INT TERM

for _ in {1..50}; do
  if curl --silent --fail "http://127.0.0.1:$port/status" >/dev/null; then
    break
  fi
  sleep 0.1
done

if ! curl --silent --fail "http://127.0.0.1:$port/status" >/dev/null; then
  echo "ChromeDriver did not start. Log: $log_file" >&2
  exit 1
fi

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart \
  -d web-server \
  --driver-port="$port" \
  --browser-name=chrome \
  --chrome-binary="$chrome" \
  --headless
