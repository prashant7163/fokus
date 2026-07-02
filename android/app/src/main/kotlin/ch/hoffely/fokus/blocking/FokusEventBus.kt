package ch.hoffely.fokus.blocking

import io.flutter.plugin.common.EventChannel

/**
 * Holds the `fokus/events` EventChannel sink so native components (the
 * accessibility service, and F-04/F-05 later) can push BlockingEvents to
 * Dart. Event names/payloads per CONTRACTS §1.
 *
 * Events are best-effort: if the Flutter engine is not attached the event is
 * dropped — resilience for engine-dead intercepts is InterceptActivity's job
 * (F-05 launches the engine).
 */
object FokusEventBus : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
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
        emit("permissionLost", mapOf("kind" to kind))

    fun emitSessionRestored(sessionId: String) =
        emit("sessionRestored", mapOf("sessionId" to sessionId))

    private fun emit(type: String, payload: Map<String, Any?>) {
        sink?.success(mapOf("type" to type) + payload)
    }
}
