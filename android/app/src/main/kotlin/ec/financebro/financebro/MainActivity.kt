package ec.financebro.financebro

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.pm.ApplicationInfo

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Puente de evaluación de la propia app; no se registra en una compilación release.
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ec.financebro/evaluacion")
            .setMethodCallHandler { call, result ->
                val gestor = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "limpiarAvisos" -> { gestor.cancelAll(); result.success(null) }
                    "segundoPlano" -> result.success(moveTaskToBack(true))
                    "cantidadAvisos" -> result.success(gestor.activeNotifications.size)
                    "estaVisible" -> result.success(hasWindowFocus())
                    else -> result.notImplemented()
                }
            }
    }
}
