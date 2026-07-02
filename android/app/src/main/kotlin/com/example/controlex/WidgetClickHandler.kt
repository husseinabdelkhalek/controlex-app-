package com.example.controlex

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread
import org.json.JSONArray
import org.json.JSONObject

object WidgetClickHandler {

    private const val BASE_URL = "https://male-cindy-controlex1-bd3de383.koyeb.app"

    fun handleIntent(context: Context, intent: Intent) {
        if (intent.action == "com.example.controlex.ACTION_WIDGET_CLICK") {
            val uri = intent.data ?: return
            thread {
                try {
                    val toolId = uri.getQueryParameter("toolId") ?: return@thread
                    val path = uri.path?.removePrefix("/") ?: ""
                    Log.d("WidgetClickHandler", "Clicked: toolId=$toolId, path=$path, uri=$uri")

                    val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
                    val token = sharedPrefs.getString("widget_auth_token", null)
                    if (token == null) {
                        Log.e("WidgetClickHandler", "No auth token found in HomeWidgetPreferences")
                        return@thread
                    }

                    var updated = false

                    when (path) {
                        "toggle" -> {
                            val currentVal = sharedPrefs.getString("widget_data_$toolId", "OFF") ?: "OFF"
                            val newVal = if (currentVal.equals("ON", ignoreCase = true)) "OFF" else "ON"
                            
                            val response = makeHttpPost("$BASE_URL/api/command/send", token, "{\"widgetId\":\"$toolId\",\"value\":\"$newVal\"}")
                            if (response != null) {
                                sharedPrefs.edit().putString("widget_data_$toolId", newVal).commit()
                                updated = true
                            }
                        }
                        "push" -> {
                            val response = makeHttpPost("$BASE_URL/api/command/send", token, "{\"widgetId\":\"$toolId\",\"value\":\"ON\"}")
                            if (response != null) {
                                sharedPrefs.edit().putString("widget_data_$toolId", "ON").commit()
                                updated = true
                            }
                        }
                        "scene_trigger" -> {
                            val cleanId = toolId.replaceFirst("scene_", "")
                            if (toolId.startsWith("local_scene_")) {
                                triggerLocalScene(context, toolId)
                            } else {
                                val response = makeHttpPost("$BASE_URL/api/scenes/$cleanId/execute", token, "{}")
                                if (response != null) {
                                    updated = true
                                }
                            }
                        }
                        "slider_adjust" -> {
                            val adjustStr = uri.getQueryParameter("adjust") ?: "0"
                            val adjustVal = adjustStr.toDoubleOrNull() ?: 0.0
                            val currentStr = sharedPrefs.getString("widget_data_$toolId", "50") ?: "50"
                            val currentVal = currentStr.replace(Regex("[^0-9.]"), "").toDoubleOrNull() ?: 50.0
                            val newVal = (currentVal + adjustVal).coerceIn(0.0, 100.0).toInt()
                            
                            val response = makeHttpPost("$BASE_URL/api/command/send", token, "{\"widgetId\":\"$toolId\",\"value\":\"$newVal\"}")
                            if (response != null) {
                                sharedPrefs.edit().putString("widget_data_$toolId", "$newVal%").commit()
                                updated = true
                            }
                        }
                        "color_pick" -> {
                            val color = uri.getQueryParameter("color") ?: "#FF5F56"
                            val response = makeHttpPost("$BASE_URL/api/command/send", token, "{\"widgetId\":\"$toolId\",\"value\":\"$color\"}")
                            if (response != null) {
                                sharedPrefs.edit().putString("widget_data_$toolId", color).commit()
                                updated = true
                            }
                        }
                        "refresh" -> {
                            val response = makeHttpGet("$BASE_URL/api/widgets", token)
                            if (response != null) {
                                try {
                                    val widgets = JSONArray(response)
                                    for (i in 0 until widgets.length()) {
                                        val w = widgets.getJSONObject(i)
                                        if (w.optString("id") == toolId) {
                                            val type = w.optString("type", "toggle").lowercase()
                                            val state = w.optJSONObject("state")
                                            val config = w.optJSONObject("configuration")
                                            var value = "OFF"
                                            when (type) {
                                                "sensor", "chart" -> {
                                                    val lastValue = state?.optString("lastValue") ?: "N/A"
                                                    val unit = config?.optString("unit") ?: ""
                                                    value = "$lastValue$unit"
                                                    if (type == "chart") {
                                                        val valDouble = lastValue.toDoubleOrNull()
                                                        if (valDouble != null) {
                                                            updateLocalChartHistory(context, toolId, valDouble)
                                                        }
                                                    }
                                                }
                                                "toggle" -> {
                                                    val isActive = state?.optBoolean("isActive") ?: false
                                                    val onCmd = config?.optString("onCommand") ?: "ON"
                                                    val lastValue = state?.optString("lastValue") ?: ""
                                                    value = if (isActive || lastValue == onCmd) "ON" else "OFF"
                                                }
                                                "slider" -> {
                                                    val lastValue = state?.optString("lastValue") ?: "0"
                                                    val unit = config?.optString("unit") ?: ""
                                                    value = "$lastValue$unit"
                                                }
                                                "terminal" -> {
                                                    value = state?.optString("lastValue") ?: "Console Ready"
                                                }
                                            }
                                            sharedPrefs.edit().putString("widget_data_$toolId", value).commit()
                                            updated = true
                                            break
                                        }
                                    }
                                } catch (je: Exception) {
                                    Log.e("WidgetClickHandler", "JSON Parse error on refresh: ${je.message}")
                                }
                            }
                        }
                    }

                    if (updated) {
                        Log.d("WidgetClickHandler", "Successfully updated state. Refreshing widgets on home screen...")
                        val appWidgetManager = AppWidgetManager.getInstance(context)
                        
                        val providerComponent = ComponentName(context, ControlExWidgetProvider::class.java)
                        val providerIds = appWidgetManager.getAppWidgetIds(providerComponent)
                        val updateIntent = Intent(context, ControlExWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, providerIds)
                        }
                        context.sendBroadcast(updateIntent)

                        val largeProviderComponent = ComponentName(context, ControlExLargeWidgetProvider::class.java)
                        val largeProviderIds = appWidgetManager.getAppWidgetIds(largeProviderComponent)
                        val largeUpdateIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, largeProviderIds)
                        }
                        context.sendBroadcast(largeUpdateIntent)
                    }
                } catch (e: Exception) {
                    Log.e("WidgetClickHandler", "Error handling click: ${e.message}")
                }
            }
        }
    }

    private fun updateLocalChartHistory(context: Context, widgetId: String, value: Double) {
        try {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val historyJson = flutterPrefs.getString("flutter.local_chart_history", null)
            val obj = if (historyJson != null) JSONObject(historyJson) else JSONObject()
            val arr = obj.optJSONArray(widgetId) ?: JSONArray()
            
            // Check if last point in history has the same value to avoid duplicates
            if (arr.length() > 0) {
                val lastItem = arr.getJSONObject(arr.length() - 1)
                val lastVal = lastItem.optDouble("value", Double.NaN)
                if (lastVal == value) {
                    return // No need to append duplicate value
                }
            }
            
            val newItem = JSONObject()
            val df = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
            df.timeZone = java.util.TimeZone.getTimeZone("UTC")
            newItem.put("time", df.format(java.util.Date()))
            newItem.put("value", value)
            arr.put(newItem)
            
            // Keep maximum 1000 points
            if (arr.length() > 1000) {
                val newArr = JSONArray()
                for (i in (arr.length() - 1000) until arr.length()) {
                    newArr.put(arr.get(i))
                }
                obj.put(widgetId, newArr)
            } else {
                obj.put(widgetId, arr)
            }
            
            flutterPrefs.edit().putString("flutter.local_chart_history", obj.toString()).commit()
        } catch (e: Exception) {
            Log.e("WidgetClickHandler", "Error updating local chart history in Kotlin: ${e.message}")
        }
    }

    private fun triggerLocalScene(context: Context, toolId: String) {
        try {
            val sharedPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = sharedPrefs.getString("flutter.local_control_scenes_v1", null) ?: return
            val scenes = JSONArray(raw)
            val rawId = toolId.replaceFirst("local_scene_", "")
            for (i in 0 until scenes.length()) {
                val scene = scenes.getJSONObject(i)
                if (scene.optString("id") == rawId) {
                    val actions = scene.optJSONArray("actions") ?: return
                    val ip = sharedPrefs.getString("flutter.local_device_ip", "") ?: ""
                    if (ip.isEmpty()) return
                    for (j in 0 until actions.length()) {
                        val act = actions.getJSONObject(j)
                        val actionWidgetId = act.optString("widgetId")
                        val actionVal = act.optString("value")
                        
                        val rawWidgets = sharedPrefs.getString("flutter.local_widgets", null) ?: continue
                        val widgetsList = JSONArray(rawWidgets)
                        var feedName = ""
                        for (k in 0 until widgetsList.length()) {
                            val w = widgetsList.getJSONObject(k)
                            if (w.optString("id") == actionWidgetId) {
                                feedName = w.optString("feedName", "")
                                break
                            }
                        }
                        if (feedName.isNotEmpty()) {
                            val url = "http://$ip/$feedName?value=$actionVal"
                            thread {
                                try {
                                    val conn = URL(url).openConnection() as HttpURLConnection
                                    conn.connectTimeout = 3000
                                    conn.readTimeout = 3000
                                    conn.responseCode
                                } catch (e: Exception) {
                                    Log.e("WidgetClickHandler", "Local command error: ${e.message}")
                                }
                            }
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("WidgetClickHandler", "Error triggering local scene: ${e.message}")
        }
    }

    private fun makeHttpPost(urlStr: String, token: String?, jsonBody: String?): String? {
        try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("Content-Type", "application/json")
            if (token != null) {
                conn.setRequestProperty("x-auth-token", token)
            }
            
            if (jsonBody != null) {
                conn.doOutput = true
                val writer = OutputStreamWriter(conn.outputStream)
                writer.write(jsonBody)
                writer.flush()
                writer.close()
            }
            
            val responseCode = conn.responseCode
            if (responseCode in 200..299) {
                return conn.inputStream.bufferedReader().use { it.readText() }
            }
        } catch (e: Exception) {
            Log.e("WidgetClickHandler", "HTTP POST error to $urlStr: ${e.message}")
        }
        return null
    }

    private fun makeHttpGet(urlStr: String, token: String?): String? {
        try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "GET"
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            if (token != null) {
                conn.setRequestProperty("x-auth-token", token)
            }
            val responseCode = conn.responseCode
            if (responseCode in 200..299) {
                return conn.inputStream.bufferedReader().use { it.readText() }
            }
        } catch (e: Exception) {
            Log.e("WidgetClickHandler", "HTTP GET error to $urlStr: ${e.message}")
        }
        return null
    }

    fun drawChartWave(width: Int, height: Int, history: List<Double>): android.graphics.Bitmap {
        val bitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
        val canvas = android.graphics.Canvas(bitmap)
        canvas.drawColor(android.graphics.Color.TRANSPARENT)
        
        val points = if (history.size >= 2) history else listOf(20.0, 45.0, 28.0, 60.0, 35.0, 75.0, 40.0, 85.0, 65.0, 50.0, 70.0, 95.0)
        
        val minVal = points.minOrNull() ?: 0.0
        val maxVal = points.maxOrNull() ?: 100.0
        val range = if (maxVal == minVal) 1.0 else maxVal - minVal
        
        val path = android.graphics.Path()
        val dx = width.toFloat() / (points.size - 1)
        
        val firstY = height.toFloat() - ((points[0] - minVal) / range * (height * 0.8)).toFloat() - (height * 0.1).toFloat()
        path.moveTo(0f, firstY)
        
        for (i in 1 until points.size) {
            val x = i * dx
            val y = height.toFloat() - ((points[i] - minVal) / range * (height * 0.8)).toFloat() - (height * 0.1).toFloat()
            path.lineTo(x, y)
        }
        
        val linePaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#00E5FF")
            strokeWidth = 4f
            style = android.graphics.Paint.Style.STROKE
            isAntiAlias = true
            strokeCap = android.graphics.Paint.Cap.ROUND
            strokeJoin = android.graphics.Paint.Join.ROUND
        }
        canvas.drawPath(path, linePaint)
        
        val areaPath = android.graphics.Path(path)
        areaPath.lineTo(width.toFloat(), height.toFloat())
        areaPath.lineTo(0f, height.toFloat())
        areaPath.close()
        
        val areaPaint = android.graphics.Paint().apply {
            color = android.graphics.Color.parseColor("#1A00E5FF")
            style = android.graphics.Paint.Style.FILL
            isAntiAlias = true
        }
        canvas.drawPath(areaPath, areaPaint)
        
        return bitmap
    }
}
