package com.rtirl.chat

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.AudioManager.OnAudioFocusChangeListener
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale
import java.util.UUID

class MainActivity : FlutterActivity(), AudioManager.OnAudioFocusChangeListener {

    private var sharedData: String = ""
    private lateinit var audioManager: AudioManager
    private lateinit var focusRequest: AudioFocusRequest
    private val handler = Handler(Looper.getMainLooper())
    private var playbackDelayed = false
    private var wasDucking = false 

    companion object {
        var methodChannel: MethodChannel? = null
        const val NOTIFICATION_ID = 6853027
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent()
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK).run {
            setAudioAttributes(AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                .build())
            setAcceptsDelayedFocusGain(true)
            setOnAudioFocusChangeListener(this@MainActivity, handler)
            build()
        }
    }

    private fun startNotificationService() {
        val intent = Intent(this, NotificationService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, intent)
        } else {
            intent.putExtra("action", "showNotification")
            startService(intent)
        }
    }

    override fun onAudioFocusChange(focusChange: Int) {
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                if (wasDucking) {
                    methodChannel?.invokeMethod("audioVolume", 1.0)
                    wasDucking = false 
                }

                if (playbackDelayed) {
                    playbackDelayed = false
                } else {
                    methodChannel?.invokeMethod("audioVolume", 1.0) 
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                methodChannel?.invokeMethod("audioVolume", 0.3) 
                wasDucking = true
            }
            AudioManager.AUDIOFOCUS_LOSS, 
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> { 
                if (!wasDucking) {
                    // handle other cases if necessary
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        val ttsPlugin = TextToSpeechPlugin(this)
        val ttsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ttsPlugin")
        val notificationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tts_notifications")
        val volumeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "volume_channel")

        methodChannel = notificationChannel

        notificationChannel.setMethodCallHandler { call, result ->
            Log.d("NotificationService", "startForeground called")
            Log.d("Notification called", call.method)
            when (call.method) {
                "dismissNotification" -> {
                    val intent = Intent(this, NotificationService::class.java)
                    intent.putExtra("action", "dismissNotification")
                    intent.putExtra("id", NOTIFICATION_ID)
                    startService(intent)
                    result.success(true)
                }
                "showNotification" -> {
                    startNotificationService()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        volumeChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "tts_on" -> {
                    val res = audioManager.requestAudioFocus(focusRequest)
                    when (res) {
                        AudioManager.AUDIOFOCUS_REQUEST_GRANTED -> {
                            methodChannel?.invokeMethod("audioFocus", "gained")
                            Log.d("Permission granted", "response granted")
                        }
                        AudioManager.AUDIOFOCUS_REQUEST_DELAYED -> {
                            playbackDelayed = true
                            methodChannel?.invokeMethod("audioFocus", "delayed")
                        }
                        else -> methodChannel?.invokeMethod("audioFocus", "failed")
                    }
                }
                "tts_off" -> {
                    audioManager.abandonAudioFocusRequest(focusRequest)
                    methodChannel?.invokeMethod("audioFocus", "lost")
                }
                else -> result.notImplemented()
            }
        }

        ttsChannel.setMethodCallHandler(ttsPlugin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rtirl.chat/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "set" -> {
                    val intent = Intent(this, AudioService::class.java)
                    intent.putStringArrayListExtra("urls", ArrayList(call.argument<List<String>>("urls") ?: listOf()))
                    intent.action = AudioService.ACTION_START_SERVICE
                    startService(intent)
                    result.success(true)
                }
                "reload" -> {
                    val intent = Intent(this, AudioService::class.java)
                    intent.action = AudioService.ACTION_START_SERVICE
                    startService(intent)
                    result.success(true)
                }
                "hasPermission" -> {
                    result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
                }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        startActivityForResult(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName")), 8675309)
                    }
                    result.success(Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(this))
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.rtirl.chat/share").setMethodCallHandler { call, result ->
            if (call.method == "getSharedData") {
                result.success(sharedData)
                sharedData = ""
            }
        }

        super.configureFlutterEngine(flutterEngine)
    }

    private fun handleIntent() {
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)?.let { intentData ->
                sharedData = intentData
            }
        }
    }
}

class TextToSpeechPlugin(private val context: Context) : MethodCallHandler, TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = null
    private val audioManager: AudioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var isTtsInitialized = false
    private var pendingSpeakData: PendingSpeakData? = null

    companion object {
        private const val NOTIFICATION_ID = 6853027
    }

    init {
        tts = TextToSpeech(context, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            isTtsInitialized = true
            pendingSpeakData?.let {
                speak(it.text, it.speed, it.volume, it.result)
                pendingSpeakData = null
            }
        } else {
            // Initialization failed
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "updateTTSPreferences" -> {
                val pitch = call.argument<Double?>("pitch")
                val speed = call.argument<Double?>("speed")
                if (pitch != null && speed != null) {
                    updateTTSPreferences(pitch.toFloat(), speed.toFloat())
                }
            }
            "speak" -> {
                val text = call.argument<String>("text")
                val speed = call.argument<Double?>("speed")
                val volume = call.argument<Double?>("volume")
                if (!text.isNullOrBlank()) {
                    if (isTtsInitialized) {
                        speak(text, speed?.toFloat(), volume?.toFloat(), result)
                    } else {
                        pendingSpeakData = PendingSpeakData(text, speed?.toFloat(), volume?.toFloat(), result)
                    }
                } else {
                    result.error("INVALID_ARGUMENT", "Text is empty or null", null)
                }
            }
            "getLanguages" -> {
                val languageMap = getLanguages()
                result.success(languageMap)
            }
            "disableTTS" -> {
                dismissTTSNotification(result)
            }
            "stopSpeaking" -> {
                stop()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun updateTTSPreferences(pitch: Float, speed: Float) {
        tts?.setPitch(pitch)
        tts?.setSpeechRate(speed)
    }

    private fun speak(text: String, speed: Float?, volume: Float?, result: Result) {
        val utteranceId = UUID.randomUUID().toString()
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String) {
                if (volume != null && Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                    audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, (audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC) * volume).toInt(), 0)
                }
            }

            override fun onDone(utteranceId: String) {
                result.success(true)
            }

            override fun onError(utteranceId: String) {
                dismissTTSNotification(result)
            }
        })

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val params = Bundle()
            params.putString(TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID, utteranceId)
            if (volume != null) {
                params.putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
            }
            if (speed != null) {
                tts?.setSpeechRate(speed)
            }
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
        } else {
            val params = HashMap<String, String>()
            params[TextToSpeech.Engine.KEY_PARAM_UTTERANCE_ID] = utteranceId
            if (speed != null) {
                tts?.setSpeechRate(speed)
            }
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, params)
        }
    }

    private fun dismissTTSNotification(result: Result) {
        val notificationId = NOTIFICATION_ID
        val intent = Intent(context, NotificationService::class.java)
        intent.putExtra("action", "dismissNotification")
        intent.putExtra("id", notificationId)
        context.startService(intent)
        stop()
        result.success(true)
    }

    private fun getLanguages(): Map<String, String> {
        val languageMap = mutableMapOf<String, String>()
        val locales = tts?.availableLanguages
        locales?.forEach { locale ->
            val languageCode = locale.language
            val languageName = locale.displayName
            languageMap[languageCode] = languageName
        }
        return languageMap
    }

    private fun stop() {
        if (tts?.isSpeaking == true) {
            tts?.stop()
        }
    }

    fun shutdown() {
        tts?.shutdown()
    }

    data class PendingSpeakData(
        val text: String,
        val speed: Float?,
        val volume: Float?,
        val result: Result
    )
}