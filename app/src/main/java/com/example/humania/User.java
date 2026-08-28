package com.example.humania;

import com.google.firebase.database.IgnoreExtraProperties;

@IgnoreExtraProperties
public class User {
    public String fullName;
    public String email;
    public int totalDonations;
    public double rating;
    public int reviewCount;
    public boolean isOnline;
    public long lastSeen;

    public User() {
        // Default constructor required for calls to DataSnapshot.getValue(User.class)
    }

    public User(String fullName, String email) {
        this.fullName = fullName;
        this.email = email;
        this.totalDonations = 0;
        this.rating = 0.0;
        this.reviewCount = 0;
        this.isOnline = true;
        this.lastSeen = System.currentTimeMillis();
    }
}
