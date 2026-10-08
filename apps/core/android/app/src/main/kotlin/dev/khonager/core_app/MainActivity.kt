package dev.khonager.core_app

import android.Manifest
import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val prefs by lazy { getSharedPreferences("core.downloads.v1", Context.MODE_PRIVATE) }
    private val manager by lazy { getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager }
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.khonager.core/device")
            .setMethodCallHandler { call, result ->
                try {
                    val id = call.argument<String>("id") ?: ""
                    val pkg = call.argument<String>("package")
                    when (call.method) {
                        "status" -> result.success(status(id, pkg))
                        "download" -> {
                            val url = Uri.parse(call.argument<String>("url")!!)
                            require(url.scheme == "https" && url.host == "github.com" && url.path?.contains("/releases/download/") == true) { "Only GitHub release APKs can be downloaded." }
                            require(!pkg.isNullOrBlank()) { "This project has no configured Android package ID." }
                            cancel(id)
                            val file = apkFile(id)
                            val request = DownloadManager.Request(url)
                                .setTitle(call.argument<String>("name"))
                                .setDescription("Core app download")
                                .setMimeType("application/vnd.android.package-archive")
                                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                                .setDestinationUri(Uri.fromFile(file))
                            val downloadId = manager.enqueue(request)
                            prefs.edit().putLong("$id.download", downloadId).putString("$id.package", pkg).apply()
                            result.success(null)
                        }
                        "cancel" -> { cancel(id); result.success(null) }
                        "install" -> {
                            val file = apkFile(id)
                            require(file.exists()) { "Download the APK again before installing." }
                            val info = packageManager.getPackageArchiveInfo(file.path, 0)
                                ?: throw IllegalStateException("This download is not a valid APK.")
                            require(info.packageName == prefs.getString("$id.package", null)) {
                                "This APK has a different package ID. Update the catalog before installing it."
                            }
                            if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                result.error("permission", "Allow Core to install apps, then tap Install downloaded APK again.", null)
                            } else {
                                val uri = FileProvider.getUriForFile(this, "$packageName.downloads", file)
                                prefs.edit().putBoolean("$id.installing", true).apply()
                                val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).setData(uri)
                                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    .putExtra(Intent.EXTRA_RETURN_RESULT, true)
                                prefs.edit().putString("active.install", id).apply()
                                startActivityForResult(intent, 82)
                                result.success(null)
                            }
                        }
                        "uninstall" -> {
                            require(!pkg.isNullOrBlank())
                            startActivity(Intent(Intent.ACTION_DELETE, Uri.parse("package:$pkg")))
                            result.success(null)
                        }
                        "notifications" -> {
                            val notifications = getSystemService(NotificationManager::class.java)
                            if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                                if (permissionResult != null) result.error("busy", "A permission request is already open.", null)
                                else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 83) }
                            } else result.success(Build.VERSION.SDK_INT < 24 || notifications.areNotificationsEnabled())
                        }
                        "notify" -> {
                            val notifications = getSystemService(NotificationManager::class.java)
                            if (Build.VERSION.SDK_INT >= 26) notifications.createNotificationChannel(
                                NotificationChannel("updates", "Project updates", NotificationManager.IMPORTANCE_DEFAULT))
                            val intent = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            notifications.notify(id.hashCode(), NotificationCompat.Builder(this, "updates")
                                .setSmallIcon(R.drawable.ic_notification)
                                .setContentTitle(call.argument<String>("title"))
                                .setContentText(call.argument<String>("body"))
                                .setContentIntent(intent).setAutoCancel(true).build())
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) { result.error("device", e.message ?: "Android could not complete this action.", null) }
            }
    }
    private fun apkFile(id: String): File {
        require(id.matches(Regex("[a-zA-Z0-9._-]+")))
        return File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "$id.apk")
    }
    private fun cancel(id: String) {
        val downloadId = prefs.getLong("$id.download", -1)
        if (downloadId != -1L) manager.remove(downloadId)
        apkFile(id).delete()
        prefs.edit().remove("$id.download").remove("$id.package").remove("$id.installing").apply()
    }
    private fun status(id: String, pkg: String?): Map<String, Any?> {
        val data = mutableMapOf<String, Any?>("phase" to "none")
        if (!pkg.isNullOrBlank()) try {
            data["version"] = packageManager.getPackageInfo(pkg, 0).versionName
        } catch (_: PackageManager.NameNotFoundException) { }
        val downloadId = prefs.getLong("$id.download", -1)
        if (downloadId == -1L) return data
        manager.query(DownloadManager.Query().setFilterById(downloadId)).use { cursor ->
            if (!cursor.moveToFirst()) { data["phase"] = "failed"; return data }
            val state = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            data["phase"] = when (state) {
                DownloadManager.STATUS_SUCCESSFUL -> if (prefs.getBoolean("$id.installing", false)) "installing" else "ready"
                DownloadManager.STATUS_FAILED -> "failed"
                else -> "downloading"
            }
            val total = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
            val done = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
            if (total > 0) data["progress"] = (done.toDouble() / total).coerceIn(0.0, 1.0)
        }
        return data
    }
    @Deprecated("Android installer activity result")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 82) {
            val id = prefs.getString("active.install", null) ?: return
            if (resultCode == RESULT_OK) cancel(id)
            else prefs.edit().putBoolean("$id.installing", false).apply()
            prefs.edit().remove("active.install").apply()
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 83) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}
