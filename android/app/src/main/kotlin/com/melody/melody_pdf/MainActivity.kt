package com.melody.melody_pdf

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.melody.melody_pdf/intent"
    private var initialFilePath: String? = null
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialFilePath" -> {
                    result.success(initialFilePath)
                    initialFilePath = null // consumed
                }
                "copyContentUri" -> {
                    val uriString = call.arguments as? String
                    if (uriString != null) {
                        val path = copyContentUriToTemp(Uri.parse(uriString))
                        result.success(path)
                    } else {
                        result.error("INVALID_URI", "URI is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Handle intent on launch
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val action = intent.action
        val uri: Uri? = intent.data

        if (uri != null && (action == Intent.ACTION_VIEW || action == Intent.ACTION_OPEN_DOCUMENT)) {
            val path = resolveUri(uri)
            if (path != null) {
                // If Flutter is ready, send immediately
                methodChannel?.invokeMethod("openFile", path)
                // Also store for initial retrieval
                initialFilePath = path
            }
        }
    }

    private fun resolveUri(uri: Uri): String? {
        // If it's a file:// URI, return the path directly
        if (uri.scheme == "file") {
            return uri.path
        }

        // If it's a content:// URI, copy to temp
        if (uri.scheme == "content") {
            return copyContentUriToTemp(uri)
        }

        return uri.path
    }

    private fun copyContentUriToTemp(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null

            // Get filename from URI
            var fileName = "shared_pdf_${System.currentTimeMillis()}.pdf"
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        fileName = it.getString(nameIndex) ?: fileName
                    }
                }
            }

            // Ensure .pdf extension
            if (!fileName.endsWith(".pdf", ignoreCase = true)) {
                fileName = "$fileName.pdf"
            }

            val tempDir = File(cacheDir, "shared_pdfs")
            tempDir.mkdirs()
            val tempFile = File(tempDir, fileName)

            val outputStream = FileOutputStream(tempFile)
            inputStream.use { input ->
                outputStream.use { output ->
                    input.copyTo(output)
                }
            }

            return tempFile.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }
}
