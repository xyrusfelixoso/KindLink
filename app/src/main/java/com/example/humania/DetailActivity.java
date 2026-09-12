package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;
import android.util.Base64;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import com.bumptech.glide.Glide;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

public class DetailActivity extends AppCompatActivity {

    private DatabaseReference mDatabase;
    private String currentUserId;
    private String currentUserName = "Anonymous";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.fragment_detail);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();
        currentUserId = FirebaseAuth.getInstance().getUid();

        // Get current user name for requests
        if (currentUserId != null) {
            mDatabase.child("users").child(currentUserId).child("fullName")
                    .addListenerForSingleValueEvent(new ValueEventListener() {
                @Override
                public void onDataChange(@NonNull DataSnapshot snapshot) {
                    if (snapshot.exists()) {
                        currentUserName = snapshot.getValue(String.class);
                    }
                }
                @Override
                public void onCancelled(@NonNull DatabaseError error) {}
            });
        }

        // Get data from intent
        Donation donation = (Donation) getIntent().getSerializableExtra("donation");
        
        if (donation != null) {
            displayDonationDetails(donation);
        } else {
            // Fallback for old "title" extra
            String title = getIntent().getStringExtra("title");
            if (title != null) {
                TextView tvTitle = findViewById(R.id.tvDetailTitle);
                if (tvTitle != null) tvTitle.setText(title);
            }
        }

        // Back Button
        FrameLayout btnBack = findViewById(R.id.btnDetailBack);
        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        // Request Pickup Button
        Button btnRequest = findViewById(R.id.btnRequestPickup);
        if (btnRequest != null) {
            if (donation != null && donation.getUserId() != null && donation.getUserId().equals(currentUserId)) {
                btnRequest.setVisibility(View.GONE); // Can't request own item
            }

            btnRequest.setOnClickListener(v -> {
                if (donation == null) return;
                handlePickupRequest(donation);
            });
        }

        // Favorite Button
        FrameLayout btnFavorite = findViewById(R.id.btnFavorite);
        if (btnFavorite != null) {
            btnFavorite.setOnClickListener(v -> {
                TextView tvIcon = findViewById(R.id.tvFavoriteIcon);
                if (tvIcon != null) {
                    if (tvIcon.getText().toString().equals("🤍")) {
                        tvIcon.setText("❤️");
                        Toast.makeText(this, "Added to favorites", Toast.LENGTH_SHORT).show();
                    } else {
                        tvIcon.setText("🤍");
                        Toast.makeText(this, "Removed from favorites", Toast.LENGTH_SHORT).show();
                    }
                }
            });
        }
    }

    private void handlePickupRequest(Donation donation) {
        if (currentUserId == null) {
            Toast.makeText(this, "Please log in to request pickup", Toast.LENGTH_SHORT).show();
            return;
        }

        String requestId = mDatabase.child("pickupRequests").push().getKey();
        if (requestId == null) return;

        String requestDate = new SimpleDateFormat("MMM dd, yyyy HH:mm", Locale.getDefault()).format(new Date());
        
        PickupRequest request = new PickupRequest(
                requestId,
                donation.getDonationId(),
                donation.getUserId(),
                currentUserId,
                currentUserName,
                donation.getTitle(),
                donation.getPhotoPath(),
                requestDate
        );

        mDatabase.child("pickupRequests").child(requestId).setValue(request)
                .addOnSuccessListener(aVoid -> {
                    Toast.makeText(this, "Pickup request sent! You can track it in 'My Requests'.", Toast.LENGTH_SHORT).show();
                    finish();
                })
                .addOnFailureListener(e -> {
                    Toast.makeText(this, "Failed to send request: " + e.getMessage(), Toast.LENGTH_SHORT).show();
                });
    }

    private void displayDonationDetails(Donation donation) {
        TextView tvTitle = findViewById(R.id.tvDetailTitle);
        TextView tvDescription = findViewById(R.id.tvDetailDescription);
        TextView tvLocation = findViewById(R.id.tvDetailLocation);
        TextView tvCategory = findViewById(R.id.tvDetailTagCategory);
        TextView tvUrgency = findViewById(R.id.tvDetailTagUrgency);
        TextView tvEmoji = findViewById(R.id.tvDetailEmoji);
        TextView tvDonor = findViewById(R.id.tvDonorName);
        TextView tvDonorReputation = findViewById(R.id.tvDonorReputation);
        ImageView ivImage = findViewById(R.id.ivDetailImage);

        if (tvTitle != null) tvTitle.setText(donation.getTitle());
        if (tvDescription != null) tvDescription.setText(donation.getDescription());
        if (tvLocation != null) tvLocation.setText("📍 " + donation.getLocation());
        if (tvCategory != null) tvCategory.setText(donation.getCategory());
        if (tvUrgency != null) tvUrgency.setText("⚡ Expires: " + donation.getExpiryDate());
        if (tvDonor != null) tvDonor.setText(donation.getDonorName() != null ? donation.getDonorName() : "Anonymous Donor");

        if (donation.getUserId() != null) {
            mDatabase.child("users").child(donation.getUserId()).addListenerForSingleValueEvent(new ValueEventListener() {
                @Override
                public void onDataChange(@NonNull DataSnapshot snapshot) {
                    User user = snapshot.getValue(User.class);
                    if (user != null && tvDonorReputation != null) {
                        String reputation = String.format(Locale.getDefault(), "⭐ %.1f · %d donations", user.rating, user.totalDonations);
                        tvDonorReputation.setText(reputation);
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {}
            });
        }

        // Load image with Glide (Supports URL, Local Path, and Base64)
        if (ivImage != null) {
            String path = donation.getPhotoPath();
            if (path != null && !path.isEmpty()) {
                ivImage.setVisibility(View.VISIBLE);
                if (tvEmoji != null) tvEmoji.setVisibility(View.GONE);
                
                if (path.startsWith("http") || path.startsWith("/")) {
                    Glide.with(this)
                            .load(path)
                            .into(ivImage);
                } else {
                    // Assume Base64
                    try {
                        byte[] imageBytes = Base64.decode(path, Base64.DEFAULT);
                        Glide.with(this)
                                .load(imageBytes)
                                .into(ivImage);
                    } catch (Exception e) {
                        ivImage.setVisibility(View.GONE);
                        if (tvEmoji != null) tvEmoji.setVisibility(View.VISIBLE);
                    }
                }
            } else {
                ivImage.setVisibility(View.GONE);
                if (tvEmoji != null) tvEmoji.setVisibility(View.VISIBLE);
            }
        }

        // Emoji mapping
        if (tvEmoji != null && donation.getCategory() != null) {
            String cat = donation.getCategory().toLowerCase();
            if (cat.contains("food")) tvEmoji.setText("🥦");
            else if (cat.contains("clothes")) tvEmoji.setText("👕");
            else if (cat.contains("toys")) tvEmoji.setText("🧸");
            else tvEmoji.setText("🎁");
        }
    }
}
