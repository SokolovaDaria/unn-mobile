package ru.unn.unn_mobile

import android.content.Intent
import android.net.Uri
import android.nfc.NfcAdapter
import android.util.Log
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {

    companion object {
        const val NFC_CHANNEL = "nfc_channel"
        const val FILE_CHANNEL = "ru.unn.unn_mobile/files"
        const val FILE_PICKER_EVENTS = "ru.unn.unn_mobile/file_events"
        const val ARGUMENT_ERROR = "ARGUMENT_ERROR"
        const val EXECUTION_ERROR = "EXECUTION_ERROR"
        const val FILE_PICKER_REQUEST = 1

        var nfcData: ByteArray? = null
        var pickedFileUri: UriContainer? = null
    }

    class UriContainer(uri: Uri?) {
        val uri: Uri? = uri
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NFC_CHANNEL).setMethodCallHandler { call, result ->
            Log.d("NFC_CHANNEL", "Method call received: ${call.method}")
            when (call.method) {
                "clearNfcData" -> {  // нужно, чтобы случайно не отправить старые данные при следующей отметке.
                    Log.d("NFC_CHANNEL", "Clearing NFC data request from Flutter")
                    MainActivity.nfcData = null 
                    result.success(null)
                }
                "sendNfcData" -> {
                    val text = call.argument<String>("data")
                    if (text != null) { 
                        Log.d("MyHostApduService", "Чистые даные: " + text)
                        Log.d("MyHostApduService", "Размер данных ${text.toByteArray(Charsets.UTF_8).size}")
                        nfcData = text.toByteArray(Charsets.UTF_8)
                        Log.d("MyHostApduService", "Байты" + nfcData)
                        result.success("Приложите телефон к считывателю")
                    } else {
                        result.error("INVALID_DATA", "Некорректные данные", null)
                    }
                }
            
            
                "checkNfcAvailability" -> {
                    val nfcAdapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(this)
                    result.success(nfcAdapter != null && nfcAdapter.isEnabled)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler methodCallback@{ call, result ->
            when (call.method) {
                "pickDirectory" -> {
                    val fileName = call.argument<String>("fileName")
                    val mimeType = call.argument<String>("mimeType")
                    if (fileName == null || mimeType == null) {
                        result.error(ARGUMENT_ERROR, "Arguments \"fileName\" and \"mimeType\" expected but not received", null)
                        return@methodCallback
                    }
                    selectExternalStorageFolder(fileName, mimeType)
                    result.success(0)
                }
                "viewFile" -> {
                    val uriString = call.argument<String>("uri")
                    val mimeType = call.argument<String>("mimeType")
                    if (uriString == null || mimeType == null) {
                        result.error(ARGUMENT_ERROR, "Arguments \"uri\" and \"mimeType\" expected but not received", null)
                        return@methodCallback
                    }
                    val uri = Uri.parse(uriString)
                    try {
                        viewFileFromUri(uri, mimeType)
                        result.success(0)
                    } catch (e: Exception) {
                        result.error(EXECUTION_ERROR, "Exception happened: ${e}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }


        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_PICKER_EVENTS).setStreamHandler(FilePickerHandler)

        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
    }

    private fun selectExternalStorageFolder(fileName: String, mimeType: String) {
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, FILE_PICKER_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            FILE_PICKER_REQUEST -> pickedFileUri = UriContainer(data?.data)
        }
    }

    private fun viewFileFromUri(uri: Uri, mimeType: String) {
        val fileIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(fileIntent)
    }

    private fun hexStringToByteArray(hex: String): ByteArray {
        val result = ByteArray(hex.length / 2)
        for (i in hex.indices step 2) {
            result[i / 2] = ((hex[i].digitToInt(16) shl 4) + hex[i + 1].digitToInt(16)).toByte()
        }
        return result
    }

    object FilePickerHandler : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null
        private val scope = CoroutineScope(Dispatchers.Main)
        private var job: Job? = null

        override fun onListen(argument: Any?, sink: EventChannel.EventSink) {
            eventSink = sink
            job = scope.launch {
                while (eventSink != null) {
                    if (pickedFileUri != null) {
                        val uri = pickedFileUri?.uri
                        pickedFileUri = null
                        eventSink?.success(uri?.toString())
                    }
                    delay(100L)
                }
            }
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
            job?.cancel()
        }
    }
} 