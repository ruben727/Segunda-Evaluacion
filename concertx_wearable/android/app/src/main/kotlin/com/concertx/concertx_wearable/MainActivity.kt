package com.concertx.concertx_wearable

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * Implementa un servidor GATT BLE (modo periférico) que expone cuatro
 * características con propiedad NOTIFY, para que la app de teléfono
 * pueda suscribirse y recibir datos del reloj en tiempo real:
 *   - ritmo (BPM, Int16)
 *   - color de efecto activo (String UTF-8, ej "#3B82F6")
 *   - estado de vibración (1 byte, 0x00 / 0x01)
 *   - oxígeno en sangre / SpO2 (1 byte, 0-100)
 */
class MainActivity : FlutterActivity() {

    private val methodChannelName = "com.concertx/ble_gatt_server"
    private val eventChannelName = "com.concertx/ble_gatt_server_status"

    private val serviceUuid = UUID.fromString("12345678-1234-1234-1234-123456789abc")
    private val ritmoCharUuid = UUID.fromString("12345678-1234-1234-1234-123456789ab1")
    private val colorCharUuid = UUID.fromString("12345678-1234-1234-1234-123456789ab2")
    private val vibracionCharUuid = UUID.fromString("12345678-1234-1234-1234-123456789ab3")
    private val oxigenoCharUuid = UUID.fromString("12345678-1234-1234-1234-123456789ab4")
    private val cccdUuid = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    private var bluetoothManager: BluetoothManager? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var eventSink: EventChannel.EventSink? = null

    private var ritmoChar: BluetoothGattCharacteristic? = null
    private var colorChar: BluetoothGattCharacteristic? = null
    private var vibracionChar: BluetoothGattCharacteristic? = null
    private var oxigenoChar: BluetoothGattCharacteristic? = null

    private val subscribedDevices = mutableSetOf<BluetoothDevice>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "iniciar" -> {
                        val ok = iniciarServidor()
                        result.success(ok)
                    }
                    "detener" -> {
                        detenerServidor()
                        result.success(null)
                    }
                    "actualizarRitmo" -> {
                        val bpm = call.argument<Int>("bpm") ?: 0
                        actualizarRitmo(bpm)
                        result.success(null)
                    }
                    "actualizarColor" -> {
                        val color = call.argument<String>("color") ?: "#3B82F6"
                        actualizarColor(color)
                        result.success(null)
                    }
                    "actualizarVibracion" -> {
                        val activa = call.argument<Boolean>("activa") ?: false
                        actualizarVibracion(activa)
                        result.success(null)
                    }
                    "actualizarOxigeno" -> {
                        val porcentaje = call.argument<Int>("porcentaje") ?: 0
                        actualizarOxigeno(porcentaje)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun tienePermisos(): Boolean {
        val permisos = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            permisos.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            permisos.add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        return permisos.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun solicitarPermisos() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH_ADVERTISE,
                    Manifest.permission.BLUETOOTH_CONNECT
                ),
                1001
            )
        }
    }

    private fun iniciarServidor(): Boolean {
        if (!tienePermisos()) {
            solicitarPermisos()
            enviarEstado("error:permisos_bluetooth_faltantes")
            return false
        }

        bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter? = bluetoothManager?.adapter

        if (adapter == null || !adapter.isEnabled) {
            enviarEstado("error:bluetooth_desactivado")
            return false
        }

        try {
            gattServer = bluetoothManager?.openGattServer(this, gattServerCallback)
            val service = BluetoothGattService(serviceUuid, BluetoothGattService.SERVICE_TYPE_PRIMARY)

            ritmoChar = crearCaracteristica(ritmoCharUuid)
            colorChar = crearCaracteristica(colorCharUuid)
            vibracionChar = crearCaracteristica(vibracionCharUuid)
            oxigenoChar = crearCaracteristica(oxigenoCharUuid)

            service.addCharacteristic(ritmoChar)
            service.addCharacteristic(colorChar)
            service.addCharacteristic(vibracionChar)
            service.addCharacteristic(oxigenoChar)

            gattServer?.addService(service)

            advertiser = adapter.bluetoothLeAdvertiser
            iniciarAdvertising()
            return true
        } catch (e: SecurityException) {
            enviarEstado("error:${e.message}")
            return false
        }
    }

    private fun crearCaracteristica(uuid: UUID): BluetoothGattCharacteristic {
        val characteristic = BluetoothGattCharacteristic(
            uuid,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        val descriptor = BluetoothGattDescriptor(
            cccdUuid,
            BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
        )
        characteristic.addDescriptor(descriptor)
        return characteristic
    }

    private fun iniciarAdvertising() {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(android.os.ParcelUuid(serviceUuid))
            .build()

        try {
            advertiser?.startAdvertising(settings, data, advertiseCallback)
        } catch (e: SecurityException) {
            enviarEstado("error:${e.message}")
        }
    }

    private fun detenerServidor() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
            gattServer?.close()
        } catch (e: SecurityException) {
            // Ignorar: ya no hay permisos o el adaptador se desactivó.
        }
        subscribedDevices.clear()
        enviarEstado("detenido")
    }

    private fun actualizarRitmo(bpm: Int) {
        val bytes = byteArrayOf((bpm shr 8).toByte(), (bpm and 0xFF).toByte())
        notificar(ritmoChar, bytes)
    }

    private fun actualizarColor(colorHex: String) {
        notificar(colorChar, colorHex.toByteArray(Charsets.UTF_8))
    }

    private fun actualizarVibracion(activa: Boolean) {
        notificar(vibracionChar, byteArrayOf(if (activa) 0x01 else 0x00))
    }

    private fun actualizarOxigeno(porcentaje: Int) {
        notificar(oxigenoChar, byteArrayOf(porcentaje.toByte()))
    }

    private fun notificar(characteristic: BluetoothGattCharacteristic?, valor: ByteArray) {
        if (characteristic == null || subscribedDevices.isEmpty()) return
        characteristic.value = valor
        for (device in subscribedDevices) {
            try {
                gattServer?.notifyCharacteristicChanged(device, characteristic, false)
            } catch (e: SecurityException) {
                // Sin permiso BLUETOOTH_CONNECT en este momento; se ignora el envío.
            }
        }
    }

    private fun enviarEstado(estado: String) {
        runOnUiThread { eventSink?.success(estado) }
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            enviarEstado("advertising")
        }

        override fun onStartFailure(errorCode: Int) {
            enviarEstado("error:advertising_fallo_$errorCode")
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothGatt.STATE_CONNECTED) {
                enviarEstado("connected")
            } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                subscribedDevices.remove(device)
                enviarEstado("disconnected")
            }
        }

        override fun onDescriptorWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            if (descriptor.uuid == cccdUuid) {
                if (value.contentEquals(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)) {
                    subscribedDevices.add(device)
                    enviarEstado("connected")
                } else {
                    subscribedDevices.remove(device)
                }
            }
            if (responseNeeded) {
                try {
                    gattServer?.sendResponse(device, requestId, android.bluetooth.BluetoothGatt.GATT_SUCCESS, offset, value)
                } catch (e: SecurityException) {
                    // sin permiso, ignorar
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic
        ) {
            try {
                gattServer?.sendResponse(
                    device,
                    requestId,
                    android.bluetooth.BluetoothGatt.GATT_SUCCESS,
                    offset,
                    characteristic.value
                )
            } catch (e: SecurityException) {
                // sin permiso, ignorar
            }
        }
    }

    override fun onDestroy() {
        detenerServidor()
        super.onDestroy()
    }
}
