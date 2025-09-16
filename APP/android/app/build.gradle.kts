plugins {
    id("com.android.application")
    id("kotlin-android")
    // لازم يبقى بعد Android/Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sawt.sawt"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.sawt.sawt"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // لو لسه ما جهزت توقيع ريلِيز، خليه مؤقتًا على debug
            signingConfig = signingConfigs.getByName("debug")

            // فعّل التصغير + ربط ملف القواعد
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"      // لازم الملف يكون موجود تحت android/app/
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // TensorFlow Lite (لو تحتاج GPU)
    implementation("org.tensorflow:tensorflow-lite:2.12.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.12.0")
}
