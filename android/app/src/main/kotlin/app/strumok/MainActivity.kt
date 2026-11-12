package app.strumok

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingInstall: Pair<File, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Self-update channel (spec-11 §11.2); names kept for continuity with the legacy app.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "install_apk").setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("filePath")
                    if (path == null) {
                        result.error("ARGUMENT", "filePath is required", null)
                    } else {
                        installApk(File(path), result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installApk(file: File, result: MethodChannel.Result) {
        if (!file.exists()) {
            result.success(false)
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            pendingInstall?.second?.success(false)
            pendingInstall = file to result
            try {
                val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                @Suppress("DEPRECATION")
                startActivityForResult(intent, REQUEST_UNKNOWN_SOURCES)
            } catch (e: ActivityNotFoundException) {
                // Some TV builds lack this settings screen; let the system installer handle it.
                pendingInstall = null
                result.success(launchInstaller(file))
            }
            return
        }
        result.success(launchInstaller(file))
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_UNKNOWN_SOURCES) return
        val (file, result) = pendingInstall ?: return
        pendingInstall = null
        val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
        result.success(allowed && launchInstaller(file))
    }

    private fun launchInstaller(file: File): Boolean = try {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileProvider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        true
    } catch (e: Exception) {
        Log.e(TAG, "Failed to launch installer", e)
        false
    }

    private companion object {
        const val TAG = "Strumok"
        const val REQUEST_UNKNOWN_SOURCES = 4201
    }
}
