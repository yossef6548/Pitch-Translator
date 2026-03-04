plugins {
  id("com.android.library")
  kotlin("android")
}

android {
  namespace = "com.pitchtranslator.audio"
  compileSdk = 34

  defaultConfig {
    minSdk = 26
    externalNativeBuild {
      cmake {
        cppFlags += "-std=c++17"
      }
    }
  }

  externalNativeBuild {
    cmake {
      path = file("src/main/cpp/CMakeLists.txt")
      version = "3.22.1"
    }
  }

  sourceSets {
    getByName("main") {
      manifest.srcFile("src/main/AndroidManifest.xml")
      java.srcDirs("src/main/kotlin")
    }
  }
}

dependencies {
  implementation("androidx.core:core-ktx:1.13.1")
}
