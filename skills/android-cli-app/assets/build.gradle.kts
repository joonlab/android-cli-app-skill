plugins {
    id("com.android.application") version "AGP_VERSION" apply false
    // ⚠️ AGP 9+ 는 Kotlin 지원이 내장이다 — org.jetbrains.kotlin.android 을 넣으면 빌드가 죽는다
    id("org.jetbrains.kotlin.plugin.compose") version "KOTLIN_VERSION" apply false   // Compose 쓸 때만
}
