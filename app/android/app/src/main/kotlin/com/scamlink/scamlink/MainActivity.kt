package com.scamlink.scamlink

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Forwards Share / PROCESS_TEXT / VIEW intents into Flutter.
 */
class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var pendingText: String? = null
    private var pendingAction: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    flushPendingToStream()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_METHODS)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialIncoming" -> {
                        // Peek without requiring the event stream.
                        result.success(peekPending())
                    }
                    "consumeInitialIncoming" -> {
                        result.success(consumePending())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent, isInitial = true)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, isInitial = false)
    }

    private fun handleIncomingIntent(intent: Intent?, isInitial: Boolean) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = extractSendText(intent)
                if (!text.isNullOrEmpty()) {
                    emit("share", text, isInitial)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val list = intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
                val joined = list
                    ?.mapNotNull { it?.trim() }
                    ?.filter { it.isNotEmpty() }
                    ?.joinToString("\n")
                if (!joined.isNullOrEmpty()) {
                    emit("share", joined, isInitial)
                } else {
                    val single = extractSendText(intent)
                    if (!single.isNullOrEmpty()) {
                        emit("share", single, isInitial)
                    }
                }
            }
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)
                    ?.toString()
                    ?.trim()
                if (!text.isNullOrEmpty()) {
                    emit("process_text", text, isInitial)
                }
            }
            Intent.ACTION_VIEW -> {
                val uri = intent.data?.toString()?.trim()
                if (!uri.isNullOrEmpty()) {
                    emit("view", uri, isInitial)
                }
            }
        }
    }

    private fun extractSendText(intent: Intent): String? {
        val extras = intent.extras ?: return intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()

        val text = extras.getCharSequence(Intent.EXTRA_TEXT)?.toString()?.trim()
        if (!text.isNullOrEmpty()) return text

        val subject = extras.getCharSequence(Intent.EXTRA_SUBJECT)?.toString()?.trim()
        if (!subject.isNullOrEmpty()) return subject

        // Some messaging apps put the body under HTML text.
        val html = extras.getCharSequence(Intent.EXTRA_HTML_TEXT)?.toString()?.trim()
        if (!html.isNullOrEmpty()) return html

        return null
    }

    private fun emit(action: String, text: String, isInitial: Boolean) {
        pendingAction = action
        pendingText = text

        // Cold start: keep pending for getInitialIncoming — do not flush away.
        if (isInitial) return

        // Warm share while Flutter is already running.
        if (eventSink != null) {
            flushPendingToStream()
        }
    }

    private fun flushPendingToStream() {
        val sink = eventSink ?: return
        val map = consumePending() ?: return
        sink.success(map)
    }

    private fun peekPending(): Map<String, String>? {
        val text = pendingText ?: return null
        val action = pendingAction ?: "unknown"
        return mapOf("action" to action, "text" to text)
    }

    private fun consumePending(): Map<String, String>? {
        val map = peekPending() ?: return null
        pendingText = null
        pendingAction = null
        return map
    }

    companion object {
        private const val CHANNEL_EVENTS = "com.scamlink/incoming_events"
        private const val CHANNEL_METHODS = "com.scamlink/incoming_methods"
    }
}
