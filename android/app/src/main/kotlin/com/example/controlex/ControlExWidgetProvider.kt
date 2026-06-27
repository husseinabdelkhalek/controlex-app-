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

class ControlExWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val data = HomeWidgetPlugin.getData(context)
        appWidgetIds.forEach { widgetId ->
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
        val views = RemoteViews(context.packageName, R.layout.widget_layout)
        
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
        val toolId = widgetData.getString("widget_tool_id_$widgetId", null)
        
        if (toolId == null) {
            // Widget is not configured yet - set off background
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background_off)
            
            views.setViewVisibility(R.id.layout_setup, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_toggle, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_terminal, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, android.view.View.GONE)
            
            views.setTextViewText(R.id.widget_title, "ControlEx")
            views.setTextViewText(R.id.widget_status, "Setup Required")
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_setup)
            
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
            
            views.setTextViewText(R.id.widget_title, toolName)
            
            // Hide all and show matching layout
            views.setViewVisibility(R.id.layout_setup, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_toggle, if (toolType == "toggle") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, if (toolType == "push" || toolType == "scene") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, if (toolType == "sensor") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_terminal, if (toolType == "terminal") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, if (toolType == "slider") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, if (toolType == "colorpicker" || toolType == "color") android.view.View.VISIBLE else android.view.View.GONE)
            
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
                    
                    val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/toggle?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_toggle, toggleIntent)
                    views.setOnClickPendingIntent(R.id.layout_toggle_compact, toggleIntent)
                    views.setOnClickPendingIntent(R.id.widget_toggle_switch_img, toggleIntent)
                    views.setOnClickPendingIntent(R.id.widget_toggle_switch_img_compact, toggleIntent)
                }
                "push" -> {
                    val pushIcon = R.drawable.ic_widget_push
                    views.setImageViewResource(R.id.widget_icon, pushIcon)
                    views.setImageViewResource(R.id.btn_push_icon_normal, pushIcon)
                    views.setImageViewResource(R.id.btn_push_icon_compact, pushIcon)
                    views.setTextViewText(R.id.widget_status, "• Push Button")
                    views.setTextViewText(R.id.btn_push_text, "TRIGGER PUSH")
                    
                    bgResource = R.drawable.widget_background_active
                    
                    val pushIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/push?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, pushIntent)
                    views.setOnClickPendingIntent(R.id.layout_push_compact, pushIntent)
                }
                "scene" -> {
                    val sceneIcon = R.drawable.ic_widget_scene
                    views.setImageViewResource(R.id.widget_icon, sceneIcon)
                    views.setImageViewResource(R.id.btn_push_icon_normal, sceneIcon)
                    views.setImageViewResource(R.id.btn_push_icon_compact, sceneIcon)
                    views.setTextViewText(R.id.widget_status, "• Smart Scene")
                    views.setTextViewText(R.id.btn_push_text, "ACTIVATE")
                    
                    bgResource = R.drawable.widget_background_purple
                    
                    val sceneIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/scene_trigger?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, sceneIntent)
                    views.setOnClickPendingIntent(R.id.layout_push_compact, sceneIntent)
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
                    
                    val minusIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/slider_adjust?toolId=$toolId&adjust=-10")
                    )
                    val plusIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/slider_adjust?toolId=$toolId&adjust=10")
                    )
                    views.setOnClickPendingIntent(R.id.btn_slider_minus, minusIntent)
                    views.setOnClickPendingIntent(R.id.btn_slider_plus, plusIntent)
                    views.setOnClickPendingIntent(R.id.btn_slider_minus_compact, minusIntent)
                    views.setOnClickPendingIntent(R.id.btn_slider_plus_compact, plusIntent)
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
                    
                    val redIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%23FF5F56")
                    )
                    val greenIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%2327C93F")
                    )
                    val blueIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%232979FF")
                    )
                    val purpleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/color_pick?toolId=$toolId&color=%23AA00FF")
                    )
                    views.setOnClickPendingIntent(R.id.btn_color_red, redIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_green, greenIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_blue, blueIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_purple, purpleIntent)
                    
                    views.setOnClickPendingIntent(R.id.btn_color_red_compact, redIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_green_compact, greenIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_blue_compact, blueIntent)
                    views.setOnClickPendingIntent(R.id.btn_color_purple_compact, purpleIntent)
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
            val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("controlex://widget/refresh?toolId=$toolId")
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshIntent)
        }
        
        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
