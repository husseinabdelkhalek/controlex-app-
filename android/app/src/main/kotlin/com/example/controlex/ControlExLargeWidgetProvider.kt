package com.example.controlex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

import android.util.Log
import android.content.Intent
import android.app.PendingIntent

class ControlExLargeWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.controlex.ACTION_WIDGET_CLICK") {
            WidgetClickHandler.handleIntent(context, intent)
        } else {
            super.onReceive(context, intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val data = HomeWidgetPlugin.getData(context)
        Log.d("ControlExWidget", "onUpdate called with ${appWidgetIds.size} widget IDs (Large)")
        appWidgetIds.forEach { widgetId ->
            Log.d("ControlExWidget", "Updating large widget ID: $widgetId")
            updateWidgetLayout(context, appWidgetManager, widgetId, data)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        val data = HomeWidgetPlugin.getData(context)
        Log.d("ControlExWidget", "onAppWidgetOptionsChanged for large widget ID: $appWidgetId")
        updateWidgetLayout(context, appWidgetManager, appWidgetId, data)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun dpToPx(context: Context, dp: Int): Int {
        val density = context.resources.displayMetrics.density
        return (dp * density).toInt()
    }

    private fun updateWidgetLayout(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        widgetData: SharedPreferences
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_large_layout)
        
        // Retrieve size parameters to optimize for external screens and different bounds
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        
        val isCompact = (minWidth > 0 && minWidth < 100) || (minHeight > 0 && minHeight < 80)

        // Dynamic header scaling & padding based on height/width bounds
        if (isCompact) {
            views.setViewVisibility(R.id.header_container, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_divider, android.view.View.GONE)
            views.setViewPadding(R.id.widget_root, dpToPx(context, 4), dpToPx(context, 4), dpToPx(context, 4), dpToPx(context, 4))
        } else {
            views.setViewVisibility(R.id.header_container, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_divider, android.view.View.VISIBLE)
            
            // Adapt root padding
            if (minHeight > 0 && minHeight < 120) {
                views.setViewPadding(R.id.widget_root, dpToPx(context, 6), dpToPx(context, 6), dpToPx(context, 6), dpToPx(context, 6))
            } else {
                views.setViewPadding(R.id.widget_root, dpToPx(context, 10), dpToPx(context, 10), dpToPx(context, 10), dpToPx(context, 10))
            }

            // Adjust sub-elements of the header based on height
            if (minHeight > 0 && minHeight < 110) {
                views.setViewVisibility(R.id.widget_status, android.view.View.GONE)
                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 12f)
            } else {
                views.setViewVisibility(R.id.widget_status, android.view.View.VISIBLE)
                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
            }

            if (minHeight > 0 && minHeight < 95) {
                views.setViewVisibility(R.id.icon_container, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.icon_container, android.view.View.VISIBLE)
            }
        }

        // Check if this specific widget is linked to a tool
        var toolId = widgetData.getString("widget_tool_id_$widgetId", null)
        Log.d("ControlExWidget", "widgetId: $widgetId -> toolId from prefs (Large): $toolId")
        
        if (toolId == null) {
            val pendingToolId = widgetData.getString("widget_pending_tool_id", null)
            Log.d("ControlExWidget", "Checking pending tool for widgetId $widgetId (Large): $pendingToolId")
            if (pendingToolId != null) {
                val pendingToolName = widgetData.getString("widget_pending_tool_name", "Device") ?: "Device"
                val pendingToolType = widgetData.getString("widget_pending_tool_type", "toggle") ?: "toggle"
                Log.d("ControlExWidget", "Auto-binding pending tool: $pendingToolId ($pendingToolName, $pendingToolType) to widgetId: $widgetId (Large)")
                
                widgetData.edit().apply {
                    putString("widget_tool_id_$widgetId", pendingToolId)
                    putString("widget_name_$widgetId", pendingToolName)
                    putString("widget_type_$widgetId", pendingToolType)
                    
                    val pendingUserEmail = widgetData.getString("widget_pending_user_email", null)
                    if (pendingUserEmail != null) {
                        putString("widget_owner_email_$widgetId", pendingUserEmail)
                    }
                    
                    val initialData = when (pendingToolType.lowercase()) {
                        "sensor" -> "24°C"
                        "slider" -> "50%"
                        "colorpicker", "color" -> "#FF5F56"
                        else -> "OFF"
                    }
                    putString("widget_data_$pendingToolId", initialData)
                    
                    remove("widget_pending_tool_id")
                    remove("widget_pending_tool_name")
                    remove("widget_pending_tool_type")
                    remove("widget_pending_user_email")
                    apply()
                }
                toolId = pendingToolId
            }
        }
        
        var widgetOwnerEmail = widgetData.getString("widget_owner_email_$widgetId", null)
        val currentUserEmail = widgetData.getString("widget_current_user_email", null)
        
        if (widgetOwnerEmail == null && currentUserEmail != null && toolId != null) {
            widgetOwnerEmail = currentUserEmail
            widgetData.edit().putString("widget_owner_email_$widgetId", currentUserEmail).apply()
        }
        
        val isAuthInvalid = toolId != null && (currentUserEmail == null || (widgetOwnerEmail != null && widgetOwnerEmail != currentUserEmail))

        if (toolId == null || isAuthInvalid) {
            // Widget is not configured yet or authentication has changed - set off background
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background_off)
            
            views.setViewVisibility(R.id.layout_setup, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_toggle, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_terminal, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_chart, android.view.View.GONE)
            
            views.setTextViewText(R.id.widget_title, "ControlEx")
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_setup)
            
            if (isAuthInvalid) {
                val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val lang = flutterPrefs.getString("flutter.language", "en") ?: "en"
                val isArabic = lang.equals("ar", ignoreCase = true)
                
                views.setTextViewText(R.id.widget_status, if (isArabic) "مطلوب تسجيل الدخول" else "Authentication Required")
                
                val message = if (widgetOwnerEmail != null) {
                    if (isArabic) {
                        "سجل الدخول بحساب\n$widgetOwnerEmail\nلتفعيل الأداة"
                    } else {
                        "Please login as\n$widgetOwnerEmail\nto activate"
                    }
                } else {
                    if (isArabic) {
                        "يرجى تسجيل الدخول لتفعيل الأداة"
                    } else {
                        "Please login to activate"
                    }
                }
                views.setTextViewText(R.id.widget_setup_text, message)
            } else {
                views.setTextViewText(R.id.widget_status, "Setup Required")
                views.setTextViewText(R.id.widget_setup_text, "Tap to setup")
            }
            
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("controlex://widget/setup?widgetId=$widgetId")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_refresh_button, pendingIntent)
            views.setOnClickPendingIntent(R.id.layout_setup, pendingIntent)
        } else {
            // Widget is configured
            val toolType = widgetData.getString("widget_type_$widgetId", "toggle")?.lowercase() ?: "toggle"
            val toolName = widgetData.getString("widget_name_$widgetId", "Unknown Device")
            val toolData = widgetData.getString("widget_data_$toolId", "OFF") ?: "OFF"
            Log.d("ControlExWidget", "Widget ID $widgetId configured (Large): toolId=$toolId, type=$toolType, name=$toolName, data=$toolData")
            
            views.setTextViewText(R.id.widget_title, toolName)
            
            // Hide all and show matching layout
            views.setViewVisibility(R.id.layout_setup, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_toggle, if (toolType == "toggle") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, if (toolType == "push" || toolType == "scene") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, if (toolType == "sensor") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_terminal, if (toolType == "terminal") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, if (toolType == "slider") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, if (toolType == "colorpicker" || toolType == "color") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_chart, if (toolType == "chart") android.view.View.VISIBLE else android.view.View.GONE)
            
            // Toggle sub-layout visibility based on size
            views.setViewVisibility(R.id.layout_toggle_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_toggle_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)
            
            views.setViewVisibility(R.id.layout_push_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_push_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)
            
            views.setViewVisibility(R.id.layout_slider_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_slider_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)
            
            views.setViewVisibility(R.id.layout_colorpicker_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_colorpicker_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)
            
            views.setViewVisibility(R.id.layout_terminal_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_terminal_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)

            views.setViewVisibility(R.id.layout_chart_normal, if (isCompact) android.view.View.GONE else android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_chart_compact, if (isCompact) android.view.View.VISIBLE else android.view.View.GONE)

            // Dynamic background setup based on state and tool type
            var bgResource = R.drawable.widget_background_active
            
            when (toolType) {
                "toggle" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_toggle)
                    views.setTextViewText(R.id.widget_status, "• Toggle Switch")
                    
                    val isON = toolData.equals("ON", ignoreCase = true)
                    views.setTextViewText(R.id.widget_toggle_status_text, if (isON) "ON" else "OFF")
                    val switchImg = if (isON) R.drawable.widget_switch_on else R.drawable.widget_switch_off
                    views.setImageViewResource(R.id.widget_toggle_switch_img, switchImg)
                    views.setImageViewResource(R.id.widget_toggle_switch_img_compact, switchImg)
                    
                    bgResource = if (isON) R.drawable.widget_background_green else R.drawable.widget_background_off
                    
                    val toggleIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/toggle?toolId=$toolId")
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        widgetId,
                        toggleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.layout_toggle, pendingIntent)
                    views.setOnClickPendingIntent(R.id.layout_toggle_compact, pendingIntent)
                    views.setOnClickPendingIntent(R.id.widget_toggle_switch_img, pendingIntent)
                    views.setOnClickPendingIntent(R.id.widget_toggle_switch_img_compact, pendingIntent)
                }
                "push" -> {
                    val pushIcon = R.drawable.ic_widget_push
                    views.setImageViewResource(R.id.widget_icon, pushIcon)
                    views.setImageViewResource(R.id.btn_push_icon_normal, pushIcon)
                    views.setImageViewResource(R.id.btn_push_icon_compact, pushIcon)
                    views.setTextViewText(R.id.widget_status, "• Push Button")
                    views.setTextViewText(R.id.btn_push_text, "TRIGGER PUSH")
                    
                    bgResource = R.drawable.widget_background_active
                    
                    val pushIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/push?toolId=$toolId")
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        widgetId,
                        pushIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, pendingIntent)
                    views.setOnClickPendingIntent(R.id.layout_push_compact, pendingIntent)
                }
                "scene" -> {
                    val sceneIcon = R.drawable.ic_widget_scene
                    views.setImageViewResource(R.id.widget_icon, sceneIcon)
                    views.setImageViewResource(R.id.btn_push_icon_normal, sceneIcon)
                    views.setImageViewResource(R.id.btn_push_icon_compact, sceneIcon)
                    views.setTextViewText(R.id.widget_status, "• Smart Scene")
                    views.setTextViewText(R.id.btn_push_text, "ACTIVATE")
                    
                    bgResource = R.drawable.widget_background_purple
                    
                    val sceneIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/scene_trigger?toolId=$toolId")
                    }
                    val pendingIntent = PendingIntent.getBroadcast(
                        context,
                        widgetId,
                        sceneIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, pendingIntent)
                    views.setOnClickPendingIntent(R.id.layout_push_compact, pendingIntent)
                }
                "sensor" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_sensor)
                    views.setTextViewText(R.id.widget_status, "• Sensor Node")
                    
                    bgResource = R.drawable.widget_background_active
                    
                    var valueText = toolData
                    var unitText = ""
                    val numRegex = Regex("^[-\\d.]+")
                    val match = numRegex.find(toolData)
                    if (match != null) {
                        valueText = match.value
                        unitText = toolData.substring(match.value.length)
                    }
                    
                    views.setTextViewText(R.id.widget_sensor_value, valueText)
                    views.setTextViewText(R.id.widget_sensor_unit, unitText)
                }
                "slider" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_slider)
                    views.setTextViewText(R.id.widget_status, "• Slider")
                    
                    bgResource = R.drawable.widget_background_active
                    
                    val currentVal = toolData.replace(Regex("[^0-9.]"), "").toDoubleOrNull() ?: 50.0
                    val valStr = "${currentVal.toInt()}%"
                    views.setTextViewText(R.id.widget_slider_value_text, valStr)
                    views.setTextViewText(R.id.widget_slider_value_text_compact, valStr)
                    views.setProgressBar(R.id.widget_slider_progress, 100, currentVal.toInt(), false)
                    
                    val minusIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/slider_adjust?toolId=$toolId&adjust=-10")
                    }
                    val pendingMinus = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 1,
                        minusIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val plusIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/slider_adjust?toolId=$toolId&adjust=10")
                    }
                    val pendingPlus = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 2,
                        plusIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.btn_slider_minus, pendingMinus)
                    views.setOnClickPendingIntent(R.id.btn_slider_plus, pendingPlus)
                    views.setOnClickPendingIntent(R.id.btn_slider_minus_compact, pendingMinus)
                    views.setOnClickPendingIntent(R.id.btn_slider_plus_compact, pendingPlus)
                }
                "colorpicker", "color" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_colorpicker)
                    views.setTextViewText(R.id.widget_status, "• Color Swatches")
                    
                    // Match glowing border dynamically to selected color!
                    bgResource = when {
                        toolData.equals("#FF5F56", ignoreCase = true) -> R.drawable.widget_background_red
                        toolData.equals("#27C93F", ignoreCase = true) -> R.drawable.widget_background_green
                        toolData.equals("#2979FF", ignoreCase = true) -> R.drawable.widget_background_blue
                        toolData.equals("#AA00FF", ignoreCase = true) -> R.drawable.widget_background_purple
                        else -> R.drawable.widget_background_active
                    }
                    
                    val redIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%23FF5F56")
                    }
                    val pendingRed = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 3,
                        redIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val greenIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%2327C93F")
                    }
                    val pendingGreen = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 4,
                        greenIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val blueIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%232979FF")
                    }
                    val pendingBlue = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 5,
                        blueIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    val purpleIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                        action = "com.example.controlex.ACTION_WIDGET_CLICK"
                        data = Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%23AA00FF")
                    }
                    val pendingPurple = PendingIntent.getBroadcast(
                        context,
                        widgetId * 10 + 6,
                        purpleIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(R.id.btn_color_red, pendingRed)
                    views.setOnClickPendingIntent(R.id.btn_color_green, pendingGreen)
                    views.setOnClickPendingIntent(R.id.btn_color_blue, pendingBlue)
                    views.setOnClickPendingIntent(R.id.btn_color_purple, pendingPurple)
                    
                    views.setOnClickPendingIntent(R.id.btn_color_red_compact, pendingRed)
                    views.setOnClickPendingIntent(R.id.btn_color_green_compact, pendingGreen)
                    views.setOnClickPendingIntent(R.id.btn_color_blue_compact, pendingBlue)
                    views.setOnClickPendingIntent(R.id.btn_color_purple_compact, pendingPurple)
                }
                "terminal" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_terminal)
                    views.setTextViewText(R.id.widget_status, "• Terminal Log")
                    views.setTextViewText(R.id.widget_terminal_logs, "guest@controlex:~$\n> $toolData")
                    
                    bgResource = R.drawable.widget_background_blue
                    
                    val keyboardIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("controlex://widget/open?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_terminal, keyboardIntent)
                    views.setOnClickPendingIntent(R.id.layout_terminal_compact, keyboardIntent)
                    views.setOnClickPendingIntent(R.id.widget_terminal_logs, keyboardIntent)
                }
                "chart" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_chart)
                    views.setTextViewText(R.id.widget_status, "• Chart Node")
                    
                    bgResource = R.drawable.widget_background_active
                    
                    views.setTextViewText(R.id.widget_chart_value_text, toolData)
                    views.setTextViewText(R.id.widget_chart_value_text_compact, toolData)
                    
                    // Render the chart history curve natively!
                    val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    val historyJson = flutterPrefs.getString("flutter.local_chart_history", null)
                    val historyList = ArrayList<Double>()
                    if (historyJson != null) {
                        try {
                            val obj = org.json.JSONObject(historyJson)
                            val arr = obj.optJSONArray(toolId)
                            if (arr != null) {
                                for (i in 0 until arr.length()) {
                                    val item = arr.getJSONObject(i)
                                    val valDouble = item.optDouble("value", Double.NaN)
                                    if (!valDouble.isNaN()) {
                                        historyList.add(valDouble)
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("ControlExWidget", "Error parsing chart history: ${e.message}")
                        }
                    }
                    try {
                        val bitmap = WidgetClickHandler.drawChartWave(450, 180, historyList)
                        views.setImageViewBitmap(R.id.widget_chart_graph_image, bitmap)
                    } catch (e: Exception) {
                        Log.e("ControlExWidget", "Error drawing chart: ${e.message}")
                    }
                }
                else -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_setup)
                    views.setTextViewText(R.id.widget_status, "• Online")
                    bgResource = R.drawable.widget_background_active
                }
            }
            
            // Set dynamic background
            views.setInt(R.id.widget_root, "setBackgroundResource", bgResource)
            
            // Normal tap on header container opens the app for that tool
            val openIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("controlex://widget/open?toolId=$toolId")
            )
            views.setOnClickPendingIntent(R.id.header_container, openIntent)
            
            // Refresh button triggers background refresh
            val refreshIntent = Intent(context, ControlExLargeWidgetProvider::class.java).apply {
                action = "com.example.controlex.ACTION_WIDGET_CLICK"
                data = Uri.parse("controlex://widget/refresh?toolId=$toolId")
            }
            val pendingRefresh = PendingIntent.getBroadcast(
                context,
                widgetId * 10 + 7,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, pendingRefresh)
        }
        
        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
