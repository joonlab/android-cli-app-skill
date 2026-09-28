plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")      // Compose 안 쓰면 이 줄도 제거
}

// 패키지는 gradle.properties 의 appId 한 곳에서 온다 (dev.sh 도 같은 값을 쓴다)
val appId: String = providers.gradleProperty("appId").get()

android {
    namespace = appId
    compileSdk = 36                                 // stable 채널 최신을 실측해서 넣을 것

    defaultConfig {
        applicationId = appId
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        // 재설치가 진짜 반영됐는지 눈으로 확인하려고 빌드 시각을 박는다 (빌드한 맥의 시간대)
        val stamp = java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(java.util.Date())
        buildConfigField("String", "BUILD_TIME", "\"$stamp\"")
    }

    buildFeatures {
        compose = true      // Compose 안 쓰면 false
        buildConfig = true  // BUILD_TIME 을 쓰려면 필요
    }

    buildTypes { release { isMinifyEnabled = false } }
}

dependencies {
    // ⚠️ BOM 이 끌어오는 Compose 버전이 compileSdk 요구를 정한다 — 실측 후 고를 것
    implementation(platform("androidx.compose:compose-bom:BOM_VERSION"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.activity:activity-compose:ACTIVITY_VERSION")
}
// UI 가 거의 없는 도구성 앱이면 의존성 0 이 낫다 — APK 29MB → 2.6MB (실측)
