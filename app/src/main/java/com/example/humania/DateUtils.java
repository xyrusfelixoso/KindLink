package com.example.humania;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class DateUtils {
    private static final String DATE_FORMAT = "yyyy-MM-dd";
    private static final String OLD_DATE_FORMAT = "M/d/yyyy";

    /**
     * Checks if the item should be removed from the main active lists (Home/Map).
     * Returns true if the grace period (1 day after expiry) has passed.
     */
    public static boolean isGracePeriodOver(String expiryDateStr) {
        if (expiryDateStr == null || expiryDateStr.isEmpty()) return false;

        SimpleDateFormat sdf = new SimpleDateFormat(DATE_FORMAT, Locale.getDefault());
        Date expiryDate = null;
        try {
            expiryDate = sdf.parse(expiryDateStr);
        } catch (ParseException e) {
            try {
                SimpleDateFormat oldSdf = new SimpleDateFormat(OLD_DATE_FORMAT, Locale.getDefault());
                expiryDate = oldSdf.parse(expiryDateStr);
            } catch (ParseException e1) {
                return false;
            }
        }

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

        SimpleDateFormat sdf = new SimpleDateFormat(DATE_FORMAT, Locale.getDefault());
        Date expiryDate = null;
        try {
            expiryDate = sdf.parse(expiryDateStr);
        } catch (ParseException e) {
            try {
                SimpleDateFormat oldSdf = new SimpleDateFormat(OLD_DATE_FORMAT, Locale.getDefault());
                expiryDate = oldSdf.parse(expiryDateStr);
            } catch (ParseException e1) {
                return false;
            }
        }

        if (expiryDate == null) return false;

        Date today = new Date();
        return today.after(expiryDate);
    }

    public static String getTodayDate() {
        return new SimpleDateFormat(DATE_FORMAT, Locale.getDefault()).format(new Date());
    }
}
