package ch.hoffely.fokus.blocking

import io.flutter.plugin.common.EventChannel

/**
 * Holds the `fokus/events` EventChannel sink so native components (the
 * accessibility service, session service, and F-05 later) can push
 * BlockingEvents to Dart. Event names/payloads per CONTRACTS §1.
 *
 * Hot-path events are best-effort: if the Flutter engine is not attached the
 * event is dropped — resilience for engine-dead intercepts is
 * InterceptActivity's job (F-05 launches the engine). Restore-critical
 * events (`sessionRestored`, `permissionLost`) are buffered until a sink
 * attaches, because they typically fire while the engine is down (boot,
 * process-kill restart) and Dart must not miss them.
 *
 * All calls happen on the main thread (channel callbacks, service handler,
 * broadcast receiver) — no extra synchronization needed.
 */
object FokusEventBus : EventChannel.StreamHandler {

    private const val PENDING_LIMIT = 16

    private var sink: EventChannel.EventSink? = null
    private val pending = ArrayDeque<Map<String, Any?>>()

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
        if (events == null) return
        while (pending.isNotEmpty()) {
            events.success(pending.removeFirst())
        }
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun emitDistractionAttempt(packageName: String, tsEpochMs: Long) =
        emit("distractionAttempt", mapOf("pkg" to packageName, "ts" to tsEpochMs))

    fun emitInterceptShown(packageName: String) =
        emit("interceptShown", mapOf("pkg" to packageName))

    fun emitRecoveryRequested() = emit("recoveryRequested", emptyMap())

    fun emitPermissionLost(kind: String) =
        emit("permissionLost", mapOf("kind" to kind), buffered = true)

    fun emitSessionRestored(sessionId: String) =
        emit("sessionRestored", mapOf("sessionId" to sessionId), buffered = true)

    private fun emit(
        type: String,
        payload: Map<String, Any?>,
        buffered: Boolean = false,
    ) {
        val event = mapOf("type" to type) + payload
        val current = sink
        when {
            current != null -> current.success(event)
            buffered && pending.size < PENDING_LIMIT -> pending.addLast(event)
        }
    }
}
