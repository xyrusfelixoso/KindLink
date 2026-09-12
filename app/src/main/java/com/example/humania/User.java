package com.example.humania;

import com.google.firebase.database.IgnoreExtraProperties;

@IgnoreExtraProperties
public class User {
    public String fullName;
    public String email;
    public String password;
    public int totalDonations;
    public int totalHelped;
    public double rating;
    public int reviewCount;
    public boolean isOnline;
    public long lastSeen;

    public User() {
        // Default constructor required for calls to DataSnapshot.getValue(User.class)
    }

    public User(String fullName, String email, String password) {
        this.fullName = fullName;
        this.email = email;
        this.password = password;
        this.totalDonations = 0;
        this.totalHelped = 0;
        this.rating = 0.0;
        this.reviewCount = 0;
        this.isOnline = true;
        this.lastSeen = System.currentTimeMillis();
    }
}
