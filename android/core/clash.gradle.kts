import org.apache.tools.ant.taskdefs.condition.Os
import java.io.*
import java.util.*
import java.net.*
import java.time.*

val gMinSdkVersion: String by project

val geoipDatabaseUrl = "https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geoip.metadb"
val geoipInvalidate = Duration.ofDays(7)
val geoipOutput = buildDir.resolve("outputs/geoip")
val nativeAbis = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
val mihomoVersion = "v1.19.25"
val mihomoBaseUrl = "https://github.com/MetaCubeX/mihomo/releases/download/$mihomoVersion/"

val String.exe: String
    get() {
        return if (Os.isFamily(Os.FAMILY_WINDOWS))
            "$this.exe"
        else
            this
    }

task("downloadMihomoCore") {
    doLast {
        val jniLibsDir = file("src/main/jniLibs")
        
        val mapping = mapOf(
            "armeabi-v7a" to "mihomo-android-armv7-$mihomoVersion.gz",
            "arm64-v8a" to "mihomo-android-arm64-$mihomoVersion.gz",
            "x86" to "mihomo-android-386-$mihomoVersion.gz",
            "x86_64" to "mihomo-android-amd64-$mihomoVersion.gz"
        )

        mapping.forEach { (abi, fileName) ->
            val libDir = jniLibsDir.resolve(abi)
            val outputFile = libDir.resolve("libclash.so")
            val gzFile = buildDir.resolve("downloads/$fileName")
            
            if (outputFile.exists()) return@forEach
            
            println("Downloading $fileName ...")
            libDir.mkdirs()
            gzFile.parentFile.mkdirs()
            
            val url = URL("$mihomoBaseUrl$fileName")
            url.openStream().use { input ->
                FileOutputStream(gzFile).use { output ->
                    input.copyTo(output)
                }
            }
            
            println("Extracting $fileName ...")
            "gunzip -f ${gzFile.absolutePath}".exec(pwd = buildDir)
            
            // The extracted file is usually named 'mihomo' or similar, rename it
            val extractedFile = gzFile.resolveSibling(fileName.replace(".gz", ""))
            // Sometimes it's just the name without .gz
            if (!extractedFile.exists()) {
                // Try finding the extracted file
                val files = gzFile.parentFile.listFiles { f -> f.name.startsWith("mihomo-android") && f.extension != "gz" }
                if (files != null && files.isNotEmpty()) {
                    files[0].renameTo(outputFile)
                }
            } else {
                extractedFile.renameTo(outputFile)
            }
            
            "chmod +x ${outputFile.absolutePath}".exec(pwd = buildDir)
        }
    }
}

task("downloadGeoipDatabase") {
    val geoipFile = geoipOutput.resolve("geoip.metadb") // Mihomo uses metadb usually, or Country.mmdb

    onlyIf {
        System.currentTimeMillis() - geoipFile.lastModified() > geoipInvalidate.toMillis()
    }

    doLast {
        geoipOutput.mkdirs()

        URL(geoipDatabaseUrl).openConnection().getInputStream().use { input ->
            FileOutputStream(geoipFile).use { output ->
                input.copyTo(output)
            }
        }
    }
}

fun String.exec(pwd: File = buildDir, env: Map<String, String> = System.getenv()): String {
    val process = ProcessBuilder().run {
        if (Os.isFamily(Os.FAMILY_WINDOWS))
            command("cmd.exe", "/c", this@exec)
        else
            command("bash", "-c", this@exec)

        environment().putAll(env)
        directory(pwd)

        redirectErrorStream(true)

        start()
    }

    val outputStream = ByteArrayOutputStream()
    process.inputStream.copyTo(outputStream)

    if (process.waitFor() != 0) {
        println(outputStream.toString("utf-8"))
        throw GradleScriptException("Exec $this failure", IOException())
    }

    return outputStream.toString("utf-8")
}
