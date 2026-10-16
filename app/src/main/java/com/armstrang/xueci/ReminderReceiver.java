package com.armstrang.xueci;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * The reminder alarm fires here: show today's reminder (if still needed) and set tomorrow's.
 * After a restart, an app update or a clock/time-zone change the alarm is set again, because
 * Android forgets alarms on reboot.
 */
public class ReminderReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        String action = intent.getAction();
        if (Reminder.ACTION.equals(action)) Reminder.show(context);
        Reminder.schedule(context);
    }
}
