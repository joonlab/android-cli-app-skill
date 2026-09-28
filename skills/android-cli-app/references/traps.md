# 함정 4+1 — 에러 전문 · 원인 · 해결

2026년 9월, JDK 조차 없는 맥에서 Galaxy Z Fold8 로 무선 설치까지 가며 만난 것들이다.
네 개가 전부 "최근 바뀐 것"이라 옛 블로그를 그대로 따르면 깨진다.

환경: macOS 26 (Apple Silicon) · Homebrew · Galaxy Z Fold8 / Android 17 (API 37)
최종 조합: openjdk@21 · Gradle 9.7.1 · AGP 9.4.1 · Compose BOM 2026.06.01 · compileSdk 36

---

## 함정 1 — `brew install --cask temurin@21` 이 멈춘다

에러가 안 난다. 출력 0바이트로 멈춘 채 curl 만 살아 있다.

- 원인: temurin 은 cask(pkg 설치)라 `/Library/Java/JavaVirtualMachines` 에 쓰려고 sudo 인증을 요구한다.
  TTY 없는 셸(에이전트가 돌리는 셸)에서는 프롬프트에 답할 수 없어 무한 대기한다.
- 해결: formula 를 쓴다. keg-only 라 sudo 가 필요 없다.

```bash
brew install openjdk@21
```

## 함정 2 — AGP 9 에서 `org.jetbrains.kotlin.android` 를 넣으면 에러

```
> Failed to apply plugin 'org.jetbrains.kotlin.android'
  The 'org.jetbrains.kotlin.android' plugin is no longer required for Kotlin support since AGP 9.0.
```

- 원인: AGP 9.0 부터 Kotlin 지원이 AGP 에 내장됐다. AGP 8.x 기준 예제가 여전히 대부분이다.
- 해결: `kotlin.android` 만 지우고 Compose 플러그인(`org.jetbrains.kotlin.plugin.compose`)은 둔다.
  참고: https://kotl.in/gradle/agp-built-in-kotlin

## 함정 3 — Compose 1.12 는 compileSdk 37 을 요구하는데 android-37 은 stable 에 없다

```
Dependency 'androidx.compose.material:material-ripple-android:1.12.1' requires libraries and
applications that depend on it to compile against version 37 or later of the Android APIs.
```

그래서 `compileSdk = 37` 로 올리면 `Failed to find package 'platforms;android-37'`.
`sdkmanager --list` 에는 android-37 이 보이지만 그건 preview 섹션이다.

- 해결: 프리뷰 SDK 를 끌어오지 말고 Compose 를 내린다. 당시 BOM 매핑:

| BOM | Compose ui | compileSdk 요구 |
|---|---|---|
| 2026.06.01 | 1.11.4 | 36 (채택) |
| 2026.08.00 | 1.12.0 | 37 |
| 2026.09.00 | 1.12.1 | 37 |

확인은 추측하지 말고 pom 을 직접 읽는다(SKILL.md 상단 명령).

## 함정 4 — `gradlew` 가 `org.gradle.java.home` 을 읽기 전에 java 를 찾는다

```
The operation couldn't be completed. Unable to locate a Java Runtime.
```

- 원인: 그 프로퍼티는 Gradle 데몬이 쓸 JDK 다. `gradlew` 셸 스크립트는 그보다 먼저 `JAVA_HOME`/PATH 에서
  java 를 찾는데, keg-only openjdk 는 PATH 에 없다.
- 해결: 실행할 때 `JAVA_HOME` 을 준다. `dev.sh` 가 자동으로 찾아서 export 한다.

---

## 함정 5 — 무선 adb 는 경로가 셋이고, 망 모양에 따라 죽는 게 다르다

| | 무선 디버깅(TLS, 페어링 코드) | `adb tcpip 5555` | VPN(Tailscale 등) 주소:5555 |
|---|---|---|---|
| 폰이 Wi-Fi 클라이언트 | 된다 | 된다 | 된다 |
| 폰이 핫스팟 + Wi-Fi 동시(「Wi-Fi 공유」) | 된다 | 된다 | 된다 |
| 순수 핫스팟(LTE 만 공유) | 안 된다(IP 가 안 잡힘) | 된다(최초 1회 케이블) | 된다 |
| 서로 다른 망 | 안 된다 | 안 된다 | 된다 |
| 폰 재부팅 후 | 페어링 유지(포트는 바뀜) | 리셋 | 된다 |

- **「IP 주소 및 포트: 사용할 수 없음」** 의 흔한 진짜 원인은 그 네트워크에서 무선 디버깅을 허용한 적이
  없어서다. 무선 디버깅을 껐다 켜면 다이얼로그가 뜬다 → **「이 네트워크에서 항상 허용」 체크 후 「허용」 버튼**.
  체크박스와 버튼이 따로라 체크만 하면 안 닫힌다. 네트워크마다 한 번씩 필요하다.
- **포트는 재부팅마다 바뀐다** → `adb mdns services` 의 `_adb-tls-connect._tcp` 로 찾는다.
- **공용·회사 Wi-Fi 는 단말 간 통신을 막는 경우가 많다(AP 클라이언트 격리).** 같은 서브넷이어도
  페어링·접속 둘 다 timeout, ping 100% 손실. adb 옵션으로는 못 뚫는다 → 핫스팟이나 개인 공유기, VPN.
- 순수 핫스팟에서 쓰는 법(케이블 1회):

```bash
adb devices -l                       # unauthorized 면 폰 팝업 승인 전
adb -s <serial> tcpip 5555
GW=$(route -n get default | awk '/gateway/{print $2}')   # 핫스팟이면 폰이 게이트웨이
adb connect "$GW:5555"               # 이후 케이블을 뽑아도 유지
```

`dev.sh connect` 는 mDNS → 게이트웨이:5555 → `PHONE_HOST` 순서로 시도한다.

---

## 그 밖에 알아 두면 시간을 버는 것

1. **코드는 ASCII 경로에.** 한글 경로는 Gradle/Android 툴체인에서 간헐적으로 깨진다.
2. **버전은 maven-metadata 로 실측.** AGP·Kotlin·BOM 은 파괴적 변경이 잦다.
3. **빌드 시각을 앱에 박는다.** 재설치가 진짜 반영됐는지 한눈에 보인다.
4. **폴더블은 디스플레이가 둘이다.** `adb shell screencap` 이 `Multiple displays were found` 경고를 내고,
   커버/메인 중 어느 쪽을 찍는지 보장되지 않는다(`-d <display-id>` 지정).
5. `adb exec-out screencap -p > x.png` 는 경고 문구가 PNG 앞에 섞여 파일이 깨진다 →
   `adb shell screencap -p /sdcard/x.png && adb pull /sdcard/x.png`.

## 정책 메모 — 사이드로드 개발자 검증

2026-09-30 시작되는 개발자 검증은 일부 국가부터 적용되고 전 세계 확대는 2027년 예정이다.
공식 FAQ 는 개발자가 **ADB 로 자기 기기에 설치하는 것은 예외**로 둔다고 적고 있다.
"내가 만들어 내 폰에 넣어 쓰기"는 이 스킬 방식 그대로 가능하다.
https://support.google.com/android-developer-console/answer/16561738
