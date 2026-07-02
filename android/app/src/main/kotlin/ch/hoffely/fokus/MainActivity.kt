package ch.hoffely.fokus

import ch.hoffely.fokus.blocking.BlockingChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BlockingChannelHandler.register(this, flutterEngine)
    }
}
