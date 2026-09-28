#!/bin/bash
# 개발 헬퍼 — 빌드 · 무선 설치 · 실행을 한 곳에서
# 설정: gradle.properties 의 appId (필수) + dev.env (선택, dev.env.example 참고)
set -euo pipefail

P="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$P/dev.env" ]; then
  # shellcheck disable=SC1091
  . "$P/dev.env"
fi

# 함정 4: gradlew 는 org.gradle.java.home 을 읽기 «전에» java 를 찾는다. keg-only openjdk 는 PATH 에 없다.
if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
fi
if [ -z "${JAVA_HOME:-}" ]; then
  JAVA_HOME="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
fi
export JAVA_HOME
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

PKG="$(awk -F= '$1=="appId"{print $2}' "$P/gradle.properties" 2>/dev/null | tr -d '[:space:]' || true)"
APK="$P/app/build/outputs/apk/debug/app-debug.apk"

ADB=(adb)
if [ -n "${ADB_SERIAL:-}" ]; then ADB=(adb -s "$ADB_SERIAL"); fi

need_pkg() {
  if [ -z "$PKG" ] || [ "$PKG" = "APP_PACKAGE" ]; then
    echo "gradle.properties 에 appId=<패키지> 를 채우세요" >&2; exit 1
  fi
}

online() { [ -n "$(adb devices | awk 'NR>1 && $2=="device"')" ]; }

# 무선 연결 자동 복구: mDNS(무선 디버깅) → 기본 게이트웨이:5555(폰 핫스팟) → PHONE_HOST:5555(VPN 등)
connect_auto() {
  if online; then echo "이미 연결됨"; adb devices -l; return 0; fi
  local addr gw
  for addr in $(adb mdns services 2>/dev/null | awk '/_adb-tls-connect/{print $NF}'); do
    adb connect "$addr" >/dev/null 2>&1 || true
    if online; then echo "1) mDNS $addr … 연결됨"; return 0; fi
  done
  echo "1) mDNS _adb-tls-connect._tcp … 찾지 못함"
  gw="$(route -n get default 2>/dev/null | awk '/gateway/{print $2}' || true)"
  if [ -n "$gw" ]; then
    adb connect "$gw:5555" >/dev/null 2>&1 || true
    if online; then echo "2) 기본 게이트웨이 $gw:5555 … 연결됨"; return 0; fi
  fi
  echo "2) 기본 게이트웨이:5555 … 응답 없음"
  if [ -n "${PHONE_HOST:-}" ]; then
    adb connect "$PHONE_HOST:5555" >/dev/null 2>&1 || true
    if online; then echo "3) PHONE_HOST $PHONE_HOST:5555 … 연결됨"; return 0; fi
    echo "3) PHONE_HOST $PHONE_HOST:5555 … 응답 없음"
  else
    echo "3) PHONE_HOST … dev.env 에 없음"
  fi
  echo "연결 실패 — 폰의 무선 디버깅을 켜고 ./dev.sh pair <IP:포트> <코드> 부터 하세요" >&2
  return 1
}

case "${1:-run}" in
  pair)    adb pair "$2" "$3" ;;            # ./dev.sh pair <IP:페어링포트> <6자리>
  connect)
    if [ -n "${2:-}" ]; then adb connect "$2"; else connect_auto; fi ;;
  build)   "$P/gradlew" -p "$P" assembleDebug ;;
  install) "${ADB[@]}" install -r "$APK" ;;
  run)
    need_pkg
    "$P/gradlew" -p "$P" assembleDebug
    "${ADB[@]}" install -r "$APK"
    # 설치만 하면 Doze 중엔 서비스가 안 뜬다(Android 12+ 백그라운드 FGS 제한) → 한 번 연다
    "${ADB[@]}" shell am start -n "$PKG/.MainActivity"
    echo "폰에서 실행했습니다: $PKG" ;;
  log)
    need_pkg
    pid="$("${ADB[@]}" shell pidof "$PKG" | tr -d '\r' || true)"
    if [ -z "$pid" ]; then echo "$PKG 가 실행 중이 아닙니다" >&2; exit 1; fi
    "${ADB[@]}" logcat --pid="$pid" ;;
  devices) adb devices -l ;;
  doctor)
    echo "JAVA_HOME    = $JAVA_HOME"
    "$JAVA_HOME/bin/java" -version 2>&1 | head -1 || echo "  java 없음 — brew install openjdk@21"
    echo "ANDROID_HOME = $ANDROID_HOME"
    command -v adb >/dev/null && adb version | head -1 || echo "  adb 없음 — platform-tools 설치"
    echo "appId        = ${PKG:-(없음)}"
    [ -f "$P/local.properties" ] && echo "local.properties 있음" || echo "local.properties 없음 — local.properties.example 참고" ;;
  *) echo "사용: ./dev.sh [pair|connect|build|install|run|log|devices|doctor]" ;;
esac
