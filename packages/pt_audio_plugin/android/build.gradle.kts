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

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }

  kotlinOptions {
    jvmTarget = "17"
  }
}

dependencies {
  implementation("androidx.core:core-ktx:1.13.1")
}
