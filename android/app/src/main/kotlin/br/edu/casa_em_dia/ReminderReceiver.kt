package br.edu.casa_em_dia

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            for (task in saved(context).values) schedule(context, task)
            return
        }
        val id = intent.getStringExtra("id") ?: return
        val task = saved(context)[id] ?: return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val expired = System.currentTimeMillis() >= task.getLong("due")
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channel, "Tarefas da casa", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel) else Notification.Builder(context)
        manager.notify(id, 1, builder
            .setSmallIcon(android.R.drawable.ic_popup_reminder)
            .setContentTitle(if (expired) "Tarefa atrasada" else "Tarefa pendente")
            .setContentText(task.getString("title"))
            .setContentIntent(open)
            .setAutoCancel(true)
            .build())
    }

    companion object {
        private const val channel = "tarefas"

        private fun saved(context: Context): Map<String, JSONObject> {
            val preferences = context.getSharedPreferences("reminders", Context.MODE_PRIVATE)
            val values = JSONArray(preferences.getString("tasks", "[]"))
            return (0 until values.length()).map { values.getJSONObject(it) }.associateBy { it.getString("id") }
        }

        private fun alarm(context: Context, id: String, kind: String): PendingIntent =
            PendingIntent.getBroadcast(context, 0,
                Intent(context, ReminderReceiver::class.java)
                    .setData(Uri.parse("casaemdia://reminder/$id/$kind"))
                    .putExtra("id", id),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun schedule(context: Context, task: JSONObject) {
            val manager = context.getSystemService(AlarmManager::class.java)
            val id = task.getString("id")
            val due = task.getLong("due")
            val now = System.currentTimeMillis()
            val before = due - 60 * 60 * 1000
            if (before > now) manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, before, alarm(context, id, "pending"))
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, maxOf(now + 3000, due + 60000), alarm(context, id, "late"))
        }

        fun sync(context: Context, tasks: List<Map<*, *>>) {
            val prior = saved(context)
            val next = tasks.map { task ->
                JSONObject().put("id", task["id"]).put("title", task["title"]).put("due", task["due"])
            }.associateBy { it.getString("id") }
            context.getSharedPreferences("reminders", Context.MODE_PRIVATE).edit()
                .putString("tasks", JSONArray(next.values.toList()).toString()).apply()
            val manager = context.getSystemService(AlarmManager::class.java)
            val notifications = context.getSystemService(NotificationManager::class.java)
            for ((id, task) in prior) {
                if (next[id]?.toString() == task.toString()) continue
                manager.cancel(alarm(context, id, "pending"))
                manager.cancel(alarm(context, id, "late"))
                notifications.cancel(id, 1)
            }
            for ((id, task) in next) {
                if (prior[id]?.toString() != task.toString()) schedule(context, task)
            }
        }
    }
}

