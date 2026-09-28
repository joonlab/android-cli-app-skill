---
name: android-cli-app
description: >-
  Android Studio 없이 CLI 툴체인(openjdk + Gradle + cmdline-tools)만으로 Kotlin/Compose 안드로이드 앱을
  새로 만들고, 빌드해서, 케이블 없이 무선으로 폰에 설치한다. 프로젝트 스캐폴딩·버전 조합 실측 방법·
  `dev.sh` 개발 루프·무선 adb 설치까지. 반드시 이 스킬을 사용하라 — 사용자가 "안드로이드 앱 만들어",
  "APK 빌드해줘", "Kotlin 앱", "Compose 앱", "폰에 앱 깔아줘"(새로 만드는 경우), "안드로이드 프로젝트
  만들어줘", "gradle 빌드 안 돼", "AGP 에러", "compileSdk 에러" 같은 요청을 하거나, 안드로이드 앱을
  새로 시작·빌드·배포해야 하는 모든 상황에서. Android Studio 를 깔라고 답하지 말 것 — CLI 로 35분이면 된다.
---

# android-cli-app — Studio 없이 앱 만들어 무선 설치

> 검증 환경: macOS 26 (Apple Silicon) · Galaxy Z Fold8 (Android 17 / API 37) · 백지에서 무선 설치까지 **35분**

## 가장 먼저 — 버전을 이 문서에서 베끼지 마라

**AGP·Kotlin·Compose 는 2026년 들어 파괴적 변경이 잦다.** 아래 「검증된 조합」은
**2026-09-20 시점의 실측값**이고, 지금은 틀렸을 수 있다. 반드시 실측하고 시작한다.

```bash
# ① stable 채널에 실제로 설치 가능한 platform 은?  (목록에 보인다고 설치되는 게 아니다 — preview 섹션 주의)
sdkmanager --sdk_root="$ANDROID_HOME" --list | sed -n '/Available Packages/,$p' | grep "platforms;android-3"

# ② 그 BOM 이 끌어오는 Compose 버전은?  (compileSdk 요구사항이 여기서 갈린다)
curl -s "https://dl.google.com/android/maven2/androidx/compose/compose-bom/<BOM>/compose-bom-<BOM>.pom" \
  | grep -A2 "<artifactId>ui</artifactId>"

# ③ 라이브러리 최신 버전
curl -s "https://dl.google.com/android/maven2/androidx/activity/activity-compose/maven-metadata.xml" | tail -20
```

**규칙: 의존성이 요구하는 compileSdk > stable 채널 최신이면 → 의존성을 내린다.**
프리뷰 SDK 를 끌어오지 말 것. (기기가 이미 그 Android 버전이어도 무관하다 — compileSdk 는 빌드 시점 API 다)

<details>
<summary>2026-09-20 검증된 조합 (참고값 · 그대로 쓰지 말고 확인할 것)</summary>

| | 버전 | 비고 |
|---|---|---|
| JDK | openjdk@21 (brew **formula**) | cask 는 안 된다(아래 함정 1) |
| Gradle | 9.7.1 | |
| AGP | 9.4.1 | |
| Kotlin | 2.4.20 (AGP 내장) | **`kotlin.android` 플러그인을 넣으면 죽는다**(함정 2) |
| Compose BOM | 2026.06.01 (Compose 1.11.4) | 2026.08.00+ 은 compileSdk 37 요구 → 당시 stable 에 없었다 |
| activity-compose | 1.12.4 | 1.13.0 도 37 요구 |
| compileSdk / targetSdk / minSdk | 36 / 36 / 30 | |
</details>

## 백지 맥에서 툴체인 설치 (Android Studio 불필요, 합계 1GB 미만)

```bash
brew install openjdk@21 gradle                 # formula — sudo 불필요
brew install --cask android-commandlinetools
export ANDROID_HOME="$HOME/Library/Android/sdk"
# platform-tools(adb) 는 직접 받는 게 빠르다 (~10MB)
curl -sL -o /tmp/pt.zip https://dl.google.com/android/repository/platform-tools-latest-darwin.zip
unzip -oq /tmp/pt.zip -d "$ANDROID_HOME"
yes | sdkmanager --sdk_root="$ANDROID_HOME" --licenses
sdkmanager --sdk_root="$ANDROID_HOME" "platforms;android-36" "build-tools;36.1.0"   # 번호는 ①로 실측
```

## 함정 4개 — 전부 「최근에 바뀐 것」이라 옛 블로그를 따르면 깨진다

| # | 증상 | 원인 · 해결 |
|---|---|---|
| 1 | `brew install --cask temurin@21` 이 **출력 0바이트로 영영 멈춤** | cask 는 pkg 라 **sudo 인증창**을 띄우는데 TTY 가 없다 → **formula** 를 쓴다: `brew install openjdk@21` |
| 2 | `The 'org.jetbrains.kotlin.android' plugin is no longer required` | **AGP 9.0부터 Kotlin 지원이 AGP 에 내장**됐다. 인터넷 예제 대부분(AGP 8.x)이 이 플러그인을 넣으라고 하는데 **9.x 에서는 넣으면 빌드가 죽는다** → 제거, Compose 플러그인만 남긴다 |
| 3 | `AAR metadata … requires compileSdk 37` 인데 `android-37` 설치 불가 | 목록에 보이는 android-37 은 **preview 섹션**이다. stable 최신을 확인하고 **의존성(BOM)을 내린다** |
| 4 | `gradlew` 가 `Unable to locate a Java Runtime` (`org.gradle.java.home` 을 써 뒀는데도) | 그 프로퍼티는 **Gradle 데몬**용이고, `gradlew` 셸 스크립트는 그보다 **먼저** java 를 찾는다. keg-only openjdk 는 PATH 에 없다 → 실행 시 `export JAVA_HOME=...` (`dev.sh` 가 처리) |

무선 adb 함정(핫스팟·공용 Wi-Fi·「이 네트워크에서 항상 허용」)과 에러 전문은 `references/traps.md`.

## 스캐폴딩

템플릿: `assets/` — 복사하고 `APPNAME`·`APP_PACKAGE`·`*_VERSION` 을 채운다.

```
<프로젝트>/
├── settings.gradle.kts   · build.gradle.kts   · gradle.properties   (appId 는 여기 한 곳)
├── local.properties      ← sdk.dir (git 에 올리지 말 것 · local.properties.example 참고)
├── dev.env               ← 선택: 폰 주소·시리얼 (git 에 올리지 말 것 · dev.env.example 참고)
├── dev.sh                ← 빌드·설치·실행 한 줄
└── app/
    ├── build.gradle.kts
    └── src/main/AndroidManifest.xml · java/<패키지 경로>/MainActivity.kt
```

**경로는 ASCII 로.** Gradle·Android 툴체인이 한글 경로에서 간헐적으로 깨진다
(`~/develop/<이름>` 같은 곳에 두고, 문서 폴더에는 심링크를 건다).

**Compose 가 꼭 필요한가 먼저 묻는다.** UI 가 거의 없는 도구성 앱(서비스·퀵 타일·공유 시트 위주)이면
의존성 0 으로 가는 게 낫다 — APK 가 29MB → 2.6MB 가 된다(실측).

자세한 파일별 내용: `references/scaffold.md`

## 개발 루프

```bash
./dev.sh connect    # 무선 연결 자동 복구 (mDNS → 게이트웨이:5555 → dev.env 의 PHONE_HOST)
./dev.sh run        # 빌드 → 무선 설치 → 실행  ← 제일 많이 쓴다
./dev.sh log        # 이 앱 로그만
./dev.sh devices    # 연결 확인
```

**재설치가 진짜 반영됐는지 눈으로 확인**하려고 템플릿은 빌드 시각을 `BuildConfig.BUILD_TIME` 에 박고
첫 화면에 띄운다(`buildFeatures { buildConfig = true }` 필요).

## 무선 설치

- 첫 연결: 폰 **설정 → 개발자 옵션 → 무선 디버깅 → 페어링 코드로 기기 페어링** → `./dev.sh pair <IP:페어링포트> <6자리>`.
- 포트는 재부팅마다 바뀌므로 `./dev.sh connect` 가 `adb mdns services` 로 다시 찾는다.
- 폰이 순수 핫스팟(LTE 공유)이면 무선 디버깅 UI 가 IP 를 못 잡는다 → 케이블 1회 `adb tcpip 5555`,
  맥의 기본 게이트웨이(=폰)로 붙는다. 서로 다른 망이면 Tailscale 같은 VPN 주소를 `PHONE_HOST` 에 둔다.

**폰이 Doze 중이면 `MY_PACKAGE_REPLACED` 로 서비스가 안 뜬다**(Android 12+ 백그라운드 FGS 제한).
그래서 `dev.sh run` 은 설치 직후 앱을 한 번 연다.

## 더 깊이

- `references/scaffold.md` — 파일별 최소 내용과 흔한 첫 실패
- `references/traps.md` — 함정 4+1 의 에러 전문·원인·무선 adb 세 경로 비교
