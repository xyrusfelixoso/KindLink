package com.example.humania;

import java.io.Serializable;

public class Donation implements Serializable {
    private String donationId;
    private String title;
    private String description;
    private String quantity;
    private String expiryDate;
    private String location;
    private double latitude;
    private double longitude;
    private String category;
    private String photoPath;
    private String timestamp;
    private String userId;
    private String donorName;

    // No-argument constructor for Firebase
    public Donation() {}

    public Donation(String donationId, String title, String description, String quantity, String expiryDate, String location, double latitude, double longitude, String category, String photoPath, String timestamp, String userId, String donorName) {
        this.donationId = donationId;
        this.title = title;
        this.description = description;
        this.quantity = quantity;
        this.expiryDate = expiryDate;
        this.location = location;
        this.latitude = latitude;
        this.longitude = longitude;
        this.category = category;
        this.photoPath = photoPath;
        this.timestamp = timestamp;
        this.userId = userId;
        this.donorName = donorName;
    }

    public Donation(String title, String description, String quantity, String expiryDate, String location, double latitude, double longitude, String category, String photoPath, String timestamp, String userId, String donorName) {
        this.title = title;
        this.description = description;
        this.quantity = quantity;
        this.expiryDate = expiryDate;
        this.location = location;
        this.latitude = latitude;
        this.longitude = longitude;
        this.category = category;
        this.photoPath = photoPath;
        this.timestamp = timestamp;
        this.userId = userId;
        this.donorName = donorName;
    }

    // Getters and Setters
    public String getDonationId() { return donationId; }
    public void setDonationId(String donationId) { this.donationId = donationId; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public String getQuantity() { return quantity; }
    public void setQuantity(String quantity) { this.quantity = quantity; }

    public String getExpiryDate() { return expiryDate; }
    public void setExpiryDate(String expiryDate) { this.expiryDate = expiryDate; }

    public String getLocation() { return location; }
    public void setLocation(String location) { this.location = location; }

    public double getLatitude() { return latitude; }
    public void setLatitude(double latitude) { this.latitude = latitude; }

    public double getLongitude() { return longitude; }
    public void setLongitude(double longitude) { this.longitude = longitude; }

    public String getCategory() { return category; }
    public void setCategory(String category) { this.category = category; }

    public String getPhotoPath() { return photoPath; }
    public void setPhotoPath(String photoPath) { this.photoPath = photoPath; }

    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }

    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    public String getDonorName() { return donorName; }
    public void setDonorName(String donorName) { this.donorName = donorName; }
}
