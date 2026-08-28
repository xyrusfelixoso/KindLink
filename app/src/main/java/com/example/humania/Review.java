package com.example.humania;

import java.io.Serializable;

public class Review implements Serializable {
    private String reviewId;
    private String reviewerId;
    private String reviewerName;
    private String targetUserId; // The donor being reviewed
    private float rating;
    private String comment;
    private String timestamp;
    private String donationTitle;
    private String reviewerProfileImage;

    public Review() {}

    public Review(String reviewId, String reviewerId, String reviewerName, String targetUserId, float rating, String comment, String timestamp) {
        this.reviewId = reviewId;
        this.reviewerId = reviewerId;
        this.reviewerName = reviewerName;
        this.targetUserId = targetUserId;
        this.rating = rating;
        this.comment = comment;
        this.timestamp = timestamp;
    }

    public Review(String reviewId, String reviewerId, String reviewerName, String targetUserId, float rating, String comment, String timestamp, String donationTitle, String reviewerProfileImage) {
        this(reviewId, reviewerId, reviewerName, targetUserId, rating, comment, timestamp);
        this.donationTitle = donationTitle;
        this.reviewerProfileImage = reviewerProfileImage;
    }

    public String getReviewId() { return reviewId; }
    public String getReviewerId() { return reviewerId; }
    public String getReviewerName() { return reviewerName; }
    public String getTargetUserId() { return targetUserId; }
    public float getRating() { return rating; }
    public String getComment() { return comment; }
    public String getTimestamp() { return timestamp; }
    public String getDonationTitle() { return donationTitle; }
    public String getReviewerProfileImage() { return reviewerProfileImage; }
}
