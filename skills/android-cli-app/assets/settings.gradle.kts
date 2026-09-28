// 버전은 반드시 실측 후 채울 것 — SKILL.md 「버전을 이 문서에서 베끼지 마라」 참조
pluginManagement {
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "APPNAME"
include(":app")
