plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // pode deixar "kotlin-android" se já usa, mas este é o canônico
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_application_meditrack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Java 11 está ok
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11

        // ⬇️ Habilita core library desugaring (exigido pelo flutter_local_notifications)
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.flutter_application_meditrack"
        // ⬇️ Garante minSdk >= 21
        minSdk = maxOf(21, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // (Opcional) Se rolar erro de 65k métodos depois, habilite multidex:
        // multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // ⬇️ Lib do desugaring (necessária quando isCoreLibraryDesugaringEnabled = true)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // (Opcional) Só se habilitou multidex acima:
    // implementation("androidx.multidex:multidex:2.0.1")
}

flutter {
    source = "../.."
}
