package com.example.overview_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "OverviewFilePicker"
        private const val CHANNEL = "overview_app/file_picker"
        private const val REQ_PICK = 9911
    }

    private var pendingResult: MethodChannel.Result? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            window.decorView.importantForAutofill =
                View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerFilePickerChannel(flutterEngine)
    }

    private fun registerFilePickerChannel(flutterEngine: FlutterEngine) {
        Log.i(TAG, "Registering MethodChannel: $CHANNEL")
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            Log.i(TAG, "Method called: ${call.method}")
            when (call.method) {
                "ping" -> result.success("ok")
                "pickFiles" -> {
                    if (pendingResult != null) {
                        result.error("BUSY", "File picker already open", null)
                        return@setMethodCallHandler
                    }
                    pendingResult = result
                    val allowMultiple = call.argument<Boolean>("allowMultiple") ?: true
                    openDocumentPicker(allowMultiple)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openDocumentPicker(multiple: Boolean) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivityForResult(intent, REQ_PICK)
        } catch (_: Exception) {
            try {
                val fallback = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multiple)
                }
                startActivityForResult(
                    Intent.createChooser(fallback, "Select Excel file"),
                    REQ_PICK,
                )
            } catch (e: Exception) {
                pendingResult?.error("PICKER_FAILED", e.message, null)
                pendingResult = null
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK) return

        val result = pendingResult
        pendingResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return
        }

        try {
            val uris = mutableListOf<Uri>()
            val clip = data.clipData
            if (clip != null) {
                for (i in 0 until clip.itemCount) {
                    uris.add(clip.getItemAt(i).uri)
                }
            } else {
                data.data?.let { uris.add(it) }
            }

            val fileUris = uris.mapNotNull { copyUriToCache(it) }
            Log.i(TAG, "Picked files: $fileUris")
            result.success(fileUris)
        } catch (e: Exception) {
            result.error("COPY_FAILED", e.message, null)
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            try {
                contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: Exception) {
            }

            val name = queryDisplayName(uri) ?: "upload_${System.currentTimeMillis()}.xlsx"
            val outFile = File(cacheDir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: return null

            Uri.fromFile(outFile).toString()
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return null
    }
}
