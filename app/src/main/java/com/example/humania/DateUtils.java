package com.example.humania;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class DateUtils {
    private static final String DATE_TIME_FORMAT = "yyyy-MM-dd HH:mm";
    private static final String DATE_FORMAT = "yyyy-MM-dd";
    private static final String OLD_DATE_FORMAT = "M/d/yyyy";

    /**
     * Checks if the item should be removed from the main active lists (Home/Map).
     * Returns true if the grace period (1 day after expiry) has passed.
     */
    public static boolean isGracePeriodOver(String expiryDateStr) {
        if (expiryDateStr == null || expiryDateStr.isEmpty()) return false;

        Date expiryDate = parseDate(expiryDateStr);
        if (expiryDate == null) return false;

        // Grace Period: 1 day after expiry
        Calendar cal = Calendar.getInstance();
        cal.setTime(expiryDate);
        cal.add(Calendar.DAY_OF_YEAR, 1);
        Date endOfGrace = cal.getTime();

        Date today = new Date();
        return today.after(endOfGrace);
    }

    /**
     * Checks if the actual expiry date has passed.
     */
    public static boolean isExpired(String expiryDateStr) {
        if (expiryDateStr == null || expiryDateStr.isEmpty()) return false;

        Date expiryDate = parseDate(expiryDateStr);
        if (expiryDate == null) return false;

        Date today = new Date();
        return today.after(expiryDate);
    }

    private static Date parseDate(String dateStr) {
        String[] formats = {DATE_TIME_FORMAT, DATE_FORMAT, OLD_DATE_FORMAT};
        for (String format : formats) {
            try {
                SimpleDateFormat sdf = new SimpleDateFormat(format, Locale.getDefault());
                return sdf.parse(dateStr);
            } catch (ParseException ignored) {}
        }
        return null;
    }

    public static String getTodayDate() {
        return new SimpleDateFormat(DATE_FORMAT, Locale.getDefault()).format(new Date());
    }

    /**
     * Returns a human-readable "Time Left" string.
     */
    public static String getTimeLeft(String expiryDateStr) {
        if (expiryDateStr == null || expiryDateStr.isEmpty()) return "";

        Date expiryDate = parseDate(expiryDateStr);
        if (expiryDate == null) return "";

        long diff = expiryDate.getTime() - new Date().getTime();
        if (diff <= 0) return "Expired";

        long hours = diff / (1000 * 60 * 60);
        long minutes = (diff / (1000 * 60)) % 60;

        if (hours > 24) {
            return (hours / 24) + "d left";
        } else if (hours > 0) {
            return hours + "h " + minutes + "m left";
        } else {
            return minutes + "m left";
        }
    }
}
