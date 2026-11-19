package com.example.concertx_movil

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.concurrent.TimeUnit

/**
 * Widget de pantalla de inicio "Próximo concierto".
 *
 * La app (lib/core/services/widget_service.dart) guarda los datos con
 * home_widget; aquí solo se leen y se pintan. La cuenta regresiva se
 * recalcula en cada actualización (cada 30 min o cuando la app manda datos
 * nuevos), así que sigue siendo correcta aunque no se abra la app.
 */
class ProximoConciertoWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val id = widgetData.getString("pc_id", null)
        val artista = widgetData.getString("pc_artista", null)
        val tour = widgetData.getString("pc_tour", null)
        val detalle = widgetData.getString("pc_detalle", null)
        val fechaMs = widgetData.getString("pc_fecha_ms", null)?.toLongOrNull()

        for (widgetId in appWidgetIds) {
            val vistas = RemoteViews(context.packageName, R.layout.proximo_concierto_widget)

            if (id.isNullOrEmpty() || artista.isNullOrEmpty()) {
                vistas.setTextViewText(R.id.widget_artista, "Sin conciertos próximos")
                vistas.setTextViewText(R.id.widget_tour, "Abre ConcertX para actualizar")
                vistas.setTextViewText(R.id.widget_detalle, "")
                vistas.setViewVisibility(R.id.widget_cuenta, View.GONE)
            } else {
                vistas.setTextViewText(R.id.widget_artista, artista)
                vistas.setTextViewText(R.id.widget_tour, tour ?: "")
                vistas.setTextViewText(R.id.widget_detalle, detalle ?: "")
                val cuenta = cuentaRegresiva(fechaMs)
                vistas.setTextViewText(R.id.widget_cuenta, cuenta)
                // Sin texto, la etiqueta se veía como un óvalo vacío.
                vistas.setViewVisibility(R.id.widget_cuenta, if (cuenta.isEmpty()) View.GONE else View.VISIBLE)
            }

            // Al tocar el widget se abre la app en el detalle del concierto
            // (lo atiende WidgetService en Flutter con la ruta concertx://).
            val uri = if (id.isNullOrEmpty()) Uri.parse("concertx://inicio") else Uri.parse("concertx://concierto/$id")
            val alTocar = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
            vistas.setOnClickPendingIntent(R.id.widget_raiz, alTocar)

            appWidgetManager.updateAppWidget(widgetId, vistas)
        }
    }

    /** "Hoy", "Mañana", "En 5 días"… según la fecha del concierto. */
    private fun cuentaRegresiva(fechaMs: Long?): String {
        if (fechaMs == null) return ""
        val restante = fechaMs - System.currentTimeMillis()
        if (restante < -TimeUnit.HOURS.toMillis(4)) return "Terminó"
        if (restante <= 0) return "¡En curso!"
        val horas = TimeUnit.MILLISECONDS.toHours(restante)
        val dias = TimeUnit.MILLISECONDS.toDays(restante)
        return when {
            horas < 24 -> if (horas <= 1) "¡Ya casi!" else "En $horas h"
            dias == 1L -> "Mañana"
            else -> "En $dias días"
        }
    }
}
