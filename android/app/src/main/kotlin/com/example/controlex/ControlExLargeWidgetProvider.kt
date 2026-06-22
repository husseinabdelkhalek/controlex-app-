package com.example.controlex

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent

class ControlExLargeWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val multiProcessData = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_MULTI_PROCESS)
        appWidgetIds.forEach { widgetId ->
            updateWidgetLayout(context, appWidgetManager, widgetId, multiProcessData)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle
    ) {
        val widgetData = context.getSharedPreferences("HomeWidgetPrefs", Context.MODE_MULTI_PROCESS)
        updateWidgetLayout(context, appWidgetManager, appWidgetId, widgetData)
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
        
        val isCompact = (minWidth > 0 && minWidth < 120) || (minHeight > 0 && minHeight < 110)

        // Dynamic header scaling & padding based on height/width bounds
        if (isCompact) {
            views.setViewVisibility(R.id.header_container, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_divider, android.view.View.GONE)
            views.setViewPadding(R.id.widget_root, dpToPx(context, 6), dpToPx(context, 6), dpToPx(context, 6), dpToPx(context, 6))
        } else {
            views.setViewVisibility(R.id.header_container, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_divider, android.view.View.VISIBLE)
            
            // Adapt root padding
            if (minHeight > 0 && minHeight < 160) {
                views.setViewPadding(R.id.widget_root, dpToPx(context, 8), dpToPx(context, 8), dpToPx(context, 8), dpToPx(context, 8))
            } else {
                views.setViewPadding(R.id.widget_root, dpToPx(context, 12), dpToPx(context, 12), dpToPx(context, 12), dpToPx(context, 12))
            }

            // Adjust sub-elements of the header based on height
            if (minHeight > 0 && minHeight < 140) {
                views.setViewVisibility(R.id.widget_status, android.view.View.GONE)
                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 12f)
            } else {
                views.setViewVisibility(R.id.widget_status, android.view.View.VISIBLE)
                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
            }

            if (minHeight > 0 && minHeight < 125) {
                views.setViewVisibility(R.id.icon_container, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.icon_container, android.view.View.VISIBLE)
            }
        }
        
        // Check if this specific widget is linked to a tool
        var toolId = widgetData.getString("widget_tool_id_$widgetId", null)
        
        if (toolId == null) {
            // Check if there is a pending tool pin request from within the app
            val pendingToolId = widgetData.getString("widget_pending_tool_id", null)
            val pendingToolName = widgetData.getString("widget_pending_tool_name", null)
            val pendingToolType = widgetData.getString("widget_pending_tool_type", "terminal")
            
            if (pendingToolId != null && pendingToolName != null) {
                val editor = widgetData.edit()
                editor.putString("widget_tool_id_$widgetId", pendingToolId)
                editor.putString("widget_name_$widgetId", pendingToolName)
                editor.putString("widget_type_$widgetId", pendingToolType)
                
                val initialData = when (pendingToolType?.lowercase() ?: "terminal") {
                    "joystick" -> "CENTER"
                    "sensor" -> "24°C"
                    "slider" -> "50%"
                    "colorpicker", "color" -> "#FF5F56"
                    "terminal" -> "guest@controlex:~$\n> Console Ready"
                    else -> "OFF"
                }
                editor.putString("widget_data_$pendingToolId", initialData)
                
                editor.remove("widget_pending_tool_id")
                editor.remove("widget_pending_tool_name")
                editor.remove("widget_pending_tool_type")
                editor.apply()
                
                toolId = pendingToolId
            }
        }
        
        if (toolId == null) {
            // Widget is not configured yet - set off background
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_background_off)
            
            views.setViewVisibility(R.id.layout_setup, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.layout_terminal, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_joystick, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_toggle, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, android.view.View.GONE)
            
            views.setTextViewText(R.id.widget_title, "ControlEx Large")
            views.setTextViewText(R.id.widget_status, "Setup Required")
            views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_setup)
            
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("controlex://widget/setup?widgetId=$widgetId")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            views.setOnClickPendingIntent(R.id.widget_refresh_button, pendingIntent)
        } else {
            // Widget is configured
            val toolType = widgetData.getString("widget_type_$widgetId", "terminal")?.lowercase() ?: "terminal"
            val toolName = widgetData.getString("widget_name_$widgetId", "Unknown Device")
            val toolData = widgetData.getString("widget_data_$toolId", "") ?: ""
            
            views.setTextViewText(R.id.widget_title, toolName)
            
            // Hide all and show matching layout
            views.setViewVisibility(R.id.layout_setup, android.view.View.GONE)
            views.setViewVisibility(R.id.layout_terminal, if (toolType == "terminal") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_joystick, if (toolType == "joystick") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_toggle, if (toolType == "toggle") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_push, if (toolType == "push" || toolType == "scene") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_sensor, if (toolType == "sensor") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_slider, if (toolType == "slider") android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.layout_colorpicker, if (toolType == "colorpicker" || toolType == "color") android.view.View.VISIBLE else android.view.View.GONE)
            
            // Dynamic background setup based on state and tool type
            var bgResource = R.drawable.widget_background_active

            when (toolType) {
                "terminal" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_terminal)
                    views.setTextViewText(R.id.widget_status, "• Terminal Console")
                    
                    bgResource = R.drawable.widget_background_blue

                    val consoleText = if (toolData.isEmpty()) {
                        "guest@controlex:~$\n>"
                    } else {
                        if (toolData.contains("guest@controlex")) toolData else "guest@controlex:~$\n> $toolData"
                    }
                    views.setTextViewText(R.id.widget_terminal_logs, consoleText)
                    
                    // Setup quick buttons actions using Background Intent
                    val statusIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/terminal_send?toolId=$toolId&cmd=status")
                    )
                    val pingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/terminal_send?toolId=$toolId&cmd=ping")
                    )
                    val clearIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/terminal_send?toolId=$toolId&cmd=clear")
                    )
                    
                    // Keyboard button opens app to input command
                    val keyboardIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("controlex://widget/open?toolId=$toolId")
                    )
                    
                    views.setOnClickPendingIntent(R.id.btn_cmd_status, statusIntent)
                    views.setOnClickPendingIntent(R.id.btn_cmd_ping, pingIntent)
                    views.setOnClickPendingIntent(R.id.btn_cmd_clear, clearIntent)
                    views.setOnClickPendingIntent(R.id.btn_cmd_keyboard, keyboardIntent)
                    views.setOnClickPendingIntent(R.id.terminal_console_box, keyboardIntent)
                    views.setOnClickPendingIntent(R.id.layout_terminal, keyboardIntent)
                }
                "joystick" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_joystick)
                    views.setTextViewText(R.id.widget_status, "• Joystick D-Pad")
                    
                    bgResource = R.drawable.widget_background_active

                    // Set up movement buttons actions using Background Intent
                    val upIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/joystick_move?toolId=$toolId&dir=UP")
                    )
                    val downIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/joystick_move?toolId=$toolId&dir=DOWN")
                    )
                    val leftIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/joystick_move?toolId=$toolId&dir=LEFT")
                    )
                    val rightIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/joystick_move?toolId=$toolId&dir=RIGHT")
                    )
                    val centerIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/joystick_move?toolId=$toolId&dir=CENTER")
                    )
                    
                    views.setOnClickPendingIntent(R.id.btn_joy_up, upIntent)
                    views.setOnClickPendingIntent(R.id.btn_joy_down, downIntent)
                    views.setOnClickPendingIntent(R.id.btn_joy_left, leftIntent)
                    views.setOnClickPendingIntent(R.id.btn_joy_right, rightIntent)
                    views.setOnClickPendingIntent(R.id.btn_joy_center, centerIntent)
                }
                "toggle" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_toggle)
                    views.setTextViewText(R.id.widget_status, "• Toggle Switch")
                    
                    val isON = toolData.equals("ON", ignoreCase = true)
                    views.setTextViewText(R.id.widget_toggle_status_text, if (isON) "ON" else "OFF")
                    views.setImageViewResource(
                        R.id.widget_toggle_switch_img,
                        if (isON) R.drawable.widget_switch_on else R.drawable.widget_switch_off
                    )
                    
                    bgResource = if (isON) R.drawable.widget_background_green else R.drawable.widget_background_off

                    val toggleIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/toggle?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_toggle, toggleIntent)
                    views.setOnClickPendingIntent(R.id.widget_toggle_switch_img, toggleIntent)
                }
                "push" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_push)
                    views.setTextViewText(R.id.widget_status, "• Push Button")
                    views.setTextViewText(R.id.btn_push_text, "TRIGGER PUSH")
                    
                    bgResource = R.drawable.widget_background_active

                    val pushIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/push?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, pushIntent)
                }
                "scene" -> {
                    views.setImageViewResource(R.id.widget_icon, R.drawable.ic_widget_scene)
                    views.setTextViewText(R.id.widget_status, "• Smart Scene")
                    views.setTextViewText(R.id.btn_push_text, "ACTIVATE")
                    
                    bgResource = R.drawable.widget_background_purple

                    val sceneIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("controlex://widget/scene_trigger?toolId=$toolId")
                    )
                    views.setOnClickPendingIntent(R.id.layout_push, sceneIntent)
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
                    views.setTextViewText(R.id.widget_slider_value_text, "${currentVal.toInt()}%")
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
