package com.example.humania;

import android.os.Bundle;
import android.widget.Button;
import android.widget.EditText;
import android.widget.RatingBar;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class ReviewActivity extends AppCompatActivity {

    private RatingBar ratingBar;
    private EditText etComment;
    private Button btnSubmit;
    private TextView tvItemName;
    private DatabaseReference mDatabase;
    private String targetUserId;
    private String donationId;
    private String itemName;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_review);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        ratingBar = findViewById(R.id.ratingBar);
        etComment = findViewById(R.id.etReviewComment);
        btnSubmit = findViewById(R.id.btnSubmitReview);
        tvItemName = findViewById(R.id.tvReviewItemName);

        targetUserId = getIntent().getStringExtra("targetUserId");
        donationId = getIntent().getStringExtra("donationId");
        itemName = getIntent().getStringExtra("itemName");

        if (itemName != null) {
            tvItemName.setText("Item: " + itemName);
        }

        btnSubmit.setOnClickListener(v -> submitReview());
    }

    private void submitReview() {
        float rating = ratingBar.getRating();
        String comment = etComment.getText().toString().trim();
        String reviewerId = FirebaseAuth.getInstance().getUid();

        if (reviewerId == null || targetUserId == null) return;
        if (rating == 0) {
            Toast.makeText(this, "Please provide a rating", Toast.LENGTH_SHORT).show();
            return;
        }

        mDatabase.child("users").child(reviewerId).child("fullName").get().addOnCompleteListener(task -> {
            String reviewerName = task.isSuccessful() ? String.valueOf(task.getResult().getValue()) : "Anonymous";
            String reviewId = mDatabase.child("reviews").push().getKey();
            String timestamp = new SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(new Date());

            Review review = new Review(reviewId, reviewerId, reviewerName, targetUserId, rating, comment, timestamp);

            if (reviewId != null) {
                mDatabase.child("reviews").child(reviewId).setValue(review).addOnSuccessListener(aVoid -> {
                    updateUserRating(targetUserId, rating);
                    Toast.makeText(ReviewActivity.this, "Review submitted! Thank you.", Toast.LENGTH_SHORT).show();
                    finish();
                });
            }
        });
    }

    private void updateUserRating(String userId, float newRatingValue) {
        DatabaseReference userRef = mDatabase.child("users").child(userId);
        userRef.addListenerForSingleValueEvent(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                User user = snapshot.getValue(User.class);
                if (user != null) {
                    double currentRating = user.rating;
                    int count = user.reviewCount;
                    double updatedRating = ((currentRating * count) + newRatingValue) / (count + 1);
                    
                    userRef.child("rating").setValue(updatedRating);
                    userRef.child("reviewCount").setValue(count + 1);
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {}
        });
    }

    @Override
    protected void onResume() {
        super.onResume();
        PresenceManager.setUserOnline(true);
    }

    @Override
    protected void onPause() {
        super.onPause();
        PresenceManager.setUserOnline(false);
    }
}
