package com.rtirl.chat

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.*
import androidx.core.app.NotificationCompat
import androidx.multidex.BuildConfig
import io.flutter.Log


class AudioService : Service() {
    companion object {
        private const val NOTIFICATION_ID = 68448
        private const val CHANNEL_ID = "AudioSources"
        private const val PACKAGE_NAME = BuildConfig.APPLICATION_ID + ".AudioService"
        const val ACTION_START_SERVICE = "$PACKAGE_NAME.start_service"
    }

    private val views = HashMap<String, WebView>()
    private var wakelock: PowerManager.WakeLock? = null

    private val notification: NotificationCompat.Builder
        get() {
            val intent = Intent(this, getMainActivityClass(this))

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("RealtimeChat Audio Sources")
                .setContentText("We're keeping your audio sources alive fam.")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setColorized(true)
                .setColor(0xFF009FDF.toInt())
                .setSmallIcon(R.drawable.notification_icon)
                .setWhen(System.currentTimeMillis())
                .setContentIntent(
                    PendingIntent.getActivity(
                        this, 0, intent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        } else {
                            PendingIntent.FLAG_UPDATE_CURRENT
                        }
                    )
                )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder.setChannelId(CHANNEL_ID)
            }

            return builder
        }

    private fun getMainActivityClass(context: Context): Class<*>? {
        val packageName = context.packageName
        val launchIntent = context.packageManager.getLaunchIntentForPackage(packageName)
        val className = launchIntent?.component?.className ?: return null

        return try {
            Class.forName(className)
        } catch (e: ClassNotFoundException) {
            e.printStackTrace()
            null
        }
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val urls = intent?.getStringArrayListExtra("urls")?.toHashSet()

        if (urls != null) {
            val wm = getSystemService(WINDOW_SERVICE) as WindowManager

            val add = (urls subtract views.keys)
            val remove = (views.keys subtract urls)
            add.forEach {
                val view = WebView(this)
                view.settings.javaScriptEnabled = true
                view.settings.mediaPlaybackRequiresUserGesture = false
                view.settings.domStorageEnabled = true
                view.settings.databaseEnabled = true
                view.settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                view.webChromeClient = object : WebChromeClient() {
                    override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                        Log.d("WebView", consoleMessage.message())
                        return true
                    }
                }
                view.setLayerType(View.LAYER_TYPE_HARDWARE, null)
                view.loadUrl(it)
                view.webViewClient = object : WebViewClient() {
                    override fun shouldOverrideUrlLoading(
                        view: WebView?,
                        request: WebResourceRequest?
                    ): Boolean {
                        return false
                    }
                }

                val params = WindowManager.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY else WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                    PixelFormat.TRANSPARENT
                )

                params.x = 0
                params.y = 0
                params.width = 0
                params.height = 0

                wm.addView(
                    view, params
                )
                views[it] = view
            }
            remove.forEach {
                wm.removeView(views[it])
                views.remove(it)?.destroy()
            }
        } else {
            views.forEach { (_, view) -> view.reload() }
        }

        if (wakelock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakelock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RealtimeChat::Wakelock")
        }

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        return if (views.isNotEmpty()) {
            // ensure the notification is shown
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val mChannel = NotificationChannel(
                    CHANNEL_ID,
                    "Audio Sources",
                    NotificationManager.IMPORTANCE_MIN
                )
                mChannel.setSound(null, null)
                nm.createNotificationChannel(mChannel)
            }
            startForeground(NOTIFICATION_ID, notification.build())
            wakelock?.acquire()
            START_STICKY
        } else {
            // ensure the notification is removed
            stopForeground(true)
            nm.cancel(NOTIFICATION_ID)
            stopSelf()
            if(wakelock?.isHeld() == true) {
                wakelock?.release()
            }
            START_NOT_STICKY
        }
    }
}