package com.example.humania;

import android.os.Bundle;
import android.widget.ImageView;
import android.widget.RatingBar;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

public class ReviewListActivity extends AppCompatActivity {

    private RecyclerView rvReviews;
    private ReviewAdapter adapter;
    private List<Review> reviewList;
    private DatabaseReference mDatabase;
    private String targetUserId;
    private TextView tvAverageRating, tvTotalReviews;
    private RatingBar summaryRatingBar;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_review_list);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        targetUserId = getIntent().getStringExtra("targetUserId");
        if (targetUserId == null) {
            finish();
            return;
        }

        rvReviews = findViewById(R.id.rvReviews);
        tvAverageRating = findViewById(R.id.tvAverageRating);
        tvTotalReviews = findViewById(R.id.tvTotalReviews);
        summaryRatingBar = findViewById(R.id.summaryRatingBar);
        ImageView btnBack = findViewById(R.id.btnBack);

        btnBack.setOnClickListener(v -> finish());

        reviewList = new ArrayList<>();
        adapter = new ReviewAdapter(reviewList);
        rvReviews.setLayoutManager(new LinearLayoutManager(this));
        rvReviews.setAdapter(adapter);

        fetchReviews();
        fetchUserStats();
    }

    private void fetchReviews() {
        mDatabase.child("reviews").orderByChild("targetUserId").equalTo(targetUserId)
                .addValueEventListener(new ValueEventListener() {
                    @Override
                    public void onDataChange(@NonNull DataSnapshot snapshot) {
                        reviewList.clear();
                        for (DataSnapshot postSnapshot : snapshot.getChildren()) {
                            Review review = postSnapshot.getValue(Review.class);
                            if (review != null) {
                                reviewList.add(0, review); // Newest first
                            }
                        }
                        adapter.notifyDataSetChanged();
                    }

                    @Override
                    public void onCancelled(@NonNull DatabaseError error) {
                        // Handle error
                    }
                });
    }

    private void fetchUserStats() {
        mDatabase.child("users").child(targetUserId).addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                User user = snapshot.getValue(User.class);
                if (user != null) {
                    tvAverageRating.setText(String.format(Locale.getDefault(), "%.1f", user.rating));
                    summaryRatingBar.setRating((float) user.rating);
                    tvTotalReviews.setText(String.format(Locale.getDefault(), "Based on %d reviews", user.reviewCount));
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
            }
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
