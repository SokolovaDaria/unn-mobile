package ru.unn.unn_mobile

import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MyHostApduService : HostApduService() {

    companion object {
        private const val TAG = "MyHostApduService"
        private const val CHANNEL = "nfc_channel"
    }

    private val SELECT_APDU = byteArrayOf(
        0x00.toByte(), 0xA4.toByte(), 0x04.toByte(), 0x00.toByte(), 0x07.toByte(),
        0xF0.toByte(), 0x01.toByte(), 0x02.toByte(), 0x03.toByte(), 0x04.toByte(), 0x05.toByte(), 0x06.toByte(), 0x00.toByte()
    )

    private val SUCCESS_RESPONSE = byteArrayOf(0x90.toByte(), 0x00.toByte()) // SW1 SW2 (успешно)

    private val GET_NEXT_BLOCK_APDU = byteArrayOf(0x00.toByte(), 0xB0.toByte())

    private val SUCCESS_APDU = byteArrayOf(0x03.toByte(), 0x0F.toByte(), 0xD1.toByte(), 0x01.toByte(), 0x0B.toByte(), 0x55.toByte(), 0x00.toByte(), 0xA3.toByte(), 0x81.toByte(), 0xBF.toByte(), 0xB5.toByte(), 0x85.toByte())
    private val ERROR_APDU = byteArrayOf(0x03.toByte(), 0x11.toByte(), 0xD1.toByte(), 0x01.toByte(), 0x0D.toByte(), 0x55.toByte(), 0x00.toByte(), 0x9E.toByte(), 0x88.toByte(), 0xB8.toByte(), 0xB1.toByte(), 0xBA.toByte(), 0xB0.toByte())

    private val ALREADY_MARKED_APDU = byteArrayOf(0x03.toByte(), 0x19.toByte(), 0xD1.toByte(), 0x01.toByte(), 0x0F.toByte(), 0x55.toByte(), 0x00.toByte(), 0xAE.toByte(), 0x92.toByte(), 0xB6.toByte(), 0xB3.toByte(), 0xBC.toByte(), 0xB4.toByte()) // 409
    private val TOO_EARLY_APDU = byteArrayOf(0x03.toByte(), 0x21.toByte(), 0xD1.toByte(), 0x01.toByte(), 0x11.toByte(), 0x55.toByte(), 0x00.toByte(), 0xC1.toByte(), 0x97.toByte(), 0xA2.toByte(), 0xB9.toByte(), 0xA5.toByte(), 0xC5.toByte()) // 400

    private var responseData: ByteArray = byteArrayOf() 
    private var currentOffset = 0 

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        Log.d(TAG, "Получена команда: ${commandApdu?.joinToString(" ") { "%02X".format(it) }}")

        when {
            commandApdu.contentEquals(SELECT_APDU) -> {
                responseData = MainActivity.nfcData ?: byteArrayOf(0x6F.toByte(), 0x00.toByte()) 
               
                currentOffset = 0 

                return getNextBlock()  
            }

            commandApdu.contentEquals(SUCCESS_APDU) -> {
                Log.d(TAG, "Получен успешный APDU")
                sendToFlutter("Вы успешно отметились!")
                return SUCCESS_RESPONSE
            }

            commandApdu.contentEquals(ERROR_APDU) -> {
                Log.d(TAG, "Ошибка APDU")
                sendToFlutter("Ошибка. Приложите телефон еще раз.")
                return byteArrayOf(0x6F.toByte(), 0x00.toByte()) // Ошибка
            }

            commandApdu.contentEquals(ALREADY_MARKED_APDU) -> {
                Log.d(TAG, "Ошибка: студент уже отмечен (409)")
                sendToFlutter("Вы уже отметились на этой паре.")
                return byteArrayOf(0x6F.toByte(), 0x00.toByte()) // Ошибка
            }

            commandApdu.contentEquals(TOO_EARLY_APDU) -> {
                Log.d(TAG, "Ошибка: еще рано отмечаться (400)")
                sendToFlutter("Отметиться можно только во время занятия.")
                return byteArrayOf(0x6F.toByte(), 0x00.toByte()) // Ошибка
            }

            commandApdu.contentEquals(GET_NEXT_BLOCK_APDU) -> {
                Log.d(TAG, "Получен запрос следующего блока")
                return getNextBlock()
            }

            else -> {
                Log.d(TAG, "Неизвестная команда")
                return byteArrayOf(0x6F.toByte(), 0x00.toByte()) // Ошибка
            }
        }
    }


    private fun getNextBlock(): ByteArray {
        val remaining = responseData.size - currentOffset
        Log.d(TAG, "Размер оставшихся данных: $remaining")
    
        if (remaining <= 0) {
            return SUCCESS_RESPONSE
        }
    
        val blockSize = 50
        val end = (currentOffset + blockSize).coerceAtMost(responseData.size)
        val block = responseData.copyOfRange(currentOffset, end)
        currentOffset = end
    
        Log.d(TAG, "Отправляем блок: ${block.joinToString(" ") { "%02X".format(it) }}")
    
        return block + SUCCESS_RESPONSE
    }


    override fun onDeactivated(reason: Int) { // убрали телефон от считывателя
        Log.d(TAG, "Служба деактивирована: $reason")
    }

    private fun sendToFlutter(message: String) {
        val flutterEngine = FlutterEngineCache.getInstance().get("my_engine_id")
        if (flutterEngine != null) {
            val methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            methodChannel.invokeMethod("nfcStatus", message)
            Log.d(TAG, "Отправлено во Flutter: $message")
        } else {
            Log.e(TAG, "FlutterEngine не найден в кэше")
        }
    }
}