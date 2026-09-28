# 스캐폴딩 — 파일별 최소 내용과 주의점

`assets/` 의 템플릿을 복사하고 placeholder 를 채운다.
**버전은 반드시 실측 후에** (SKILL.md 상단 참조).

| placeholder | 뜻 | 예 |
|---|---|---|
| `APPNAME` | 앱·프로젝트 이름 | `hellofold` |
| `APP_PACKAGE` | 패키지(= applicationId = namespace) | `com.example.hellofold` |
| `AGP_VERSION` `KOTLIN_VERSION` `BOM_VERSION` `ACTIVITY_VERSION` | 실측한 버전 | SKILL.md 의 「검증된 조합」 참고 |

| 템플릿 | 놓을 위치 | 주의 |
|---|---|---|
| `settings.gradle.kts` | 루트 | |
| `build.gradle.kts` | 루트 | AGP 9+ 는 `kotlin.android` 를 **넣으면 안 된다** |
| `gradle.properties` | 루트 | `appId=APP_PACKAGE` 가 여기 한 곳에만 있다. `dev.sh` 도 여기서 읽는다 |
| `app-build.gradle.kts` | `app/build.gradle.kts` | BOM 이 compileSdk 요구를 정한다 |
| `AndroidManifest.xml` | `app/src/main/AndroidManifest.xml` | |
| `MainActivity.kt` | `app/src/main/java/<APP_PACKAGE 를 / 로>/MainActivity.kt` | 첫 줄 `package APP_PACKAGE` |
| `dev.sh` | 루트 | `chmod +x dev.sh` |
| `dev.env.example` | 루트에 `dev.env` 로 복사(선택) | git 에 올리지 말 것 |
| `local.properties.example` | 루트에 `local.properties` 로 복사 | git 에 올리지 말 것 |
| `gitignore` | 루트에 `.gitignore` 로 복사 | |

**`local.properties`** — `sdk.dir` 는 절대경로여야 한다. `$HOME` 은 풀리지 않으므로 직접 쓴다.
```bash
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
```

**Gradle wrapper** — brew 로 깐 gradle 로 한 번 만든다.
```bash
gradle wrapper --gradle-version <실측한 버전>
```

## 첫 빌드 전 점검

```bash
./dev.sh doctor     # JAVA_HOME · java 버전 · ANDROID_HOME · adb · appId 를 한 번에 출력
./dev.sh build
```

## 흔한 첫 실패

| 증상 | 조치 |
|---|---|
| `Unable to locate a Java Runtime` | `JAVA_HOME` export (dev.sh 를 쓰면 자동) |
| `plugin is no longer required` | `org.jetbrains.kotlin.android` 제거 |
| `requires compileSdk 37` | BOM 을 내린다 (프리뷰 SDK 를 받지 말 것) |
| `Failed to find package 'platforms;android-NN'` | stable 채널에 없는 버전이다. `--list` 로 확인 |
| `SDK location not found` | `local.properties` 의 `sdk.dir` 또는 `ANDROID_HOME` |
| 한글 경로에서 간헐 실패 | 코드를 ASCII 경로로 옮기고 문서 폴더엔 심링크 |

## Compose 를 쓸지 말지

| | Compose | 의존성 0 (View) |
|---|---|---|
| APK | ~29MB | ~2.6MB |
| 폴더블 접기/펼치기 대응 | `LocalConfiguration` 으로 실시간 | 직접 처리 |
| 적합 | 화면이 주인공인 앱 | 서비스·타일·공유시트 위주의 도구 |

의존성 0 으로 갈 때: 루트 `build.gradle.kts` 에서 compose 플러그인 줄, `app/build.gradle.kts` 에서
compose 플러그인·`compose = true`·dependencies 블록을 지우고, `MainActivity` 는 `android.app.Activity` 를 상속한다.
