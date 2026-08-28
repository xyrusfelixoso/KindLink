package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import java.util.ArrayList;
import java.util.List;

public class HomeActivity extends AppCompatActivity {

    private TextView tvUserName, tvHomeStatDonated, tvGlobalTotalDonations, tvHomeRating;
    private DatabaseReference mDatabase;
    private FirebaseAuth mAuth;
    private RecyclerView rvNearYou;
    private DonationAdapter donationAdapter;
    private List<Donation> donationList;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.fragment_home);

        mAuth = FirebaseAuth.getInstance();
        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        tvUserName = findViewById(R.id.tvUserName);
        tvHomeStatDonated = findViewById(R.id.tvHomeStatDonated);
        tvGlobalTotalDonations = findViewById(R.id.tvGlobalTotalDonations);
        tvHomeRating = findViewById(R.id.tvHomeRating);

        // RecyclerView Setup
        rvNearYou = findViewById(R.id.rvNearYou);
        donationList = new ArrayList<>();
        donationAdapter = new DonationAdapter(donationList, donation -> {
            Intent intent = new Intent(HomeActivity.this, DetailActivity.class);
            intent.putExtra("donation", donation);
            startActivity(intent);
        });
        rvNearYou.setLayoutManager(new LinearLayoutManager(this));
        rvNearYou.setAdapter(donationAdapter);

        // Avatar (Yellow Emoji) -> Profile Screen
        View ivProfileAvatar = findViewById(R.id.ivProfileAvatar);
        if (ivProfileAvatar != null) {
            ivProfileAvatar.setOnClickListener(v -> {
                Intent intent = new Intent(HomeActivity.this, ProfileActivity.class);
                intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                startActivity(intent);
            });
        }

        // See All -> Browse all
        TextView tvSeeAll = findViewById(R.id.tvSeeAll);
        if (tvSeeAll != null) {
            tvSeeAll.setOnClickListener(v -> {
                Intent intent = new Intent(HomeActivity.this, BrowseActivity.class);
                intent.putExtra("category", "All");
                intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                startActivity(intent);
            });
        }

        // Bottom Navigation Setup
        setupBottomNavigation();

        // Category Chips Setup
        setupChips();
        
        // Load real-time data
        loadUserData();
        loadDonationsData();
    }

    private void loadUserData() {
        FirebaseUser firebaseUser = mAuth.getCurrentUser();
        if (firebaseUser != null) {
            String userId = firebaseUser.getUid();
            mDatabase.child("users").child(userId).addValueEventListener(new ValueEventListener() {
                @Override
                public void onDataChange(@NonNull DataSnapshot snapshot) {
                    User user = snapshot.getValue(User.class);
                    if (user != null) {
                        if (tvUserName != null) tvUserName.setText(user.fullName);
                        if (tvHomeStatDonated != null) tvHomeStatDonated.setText(String.valueOf(user.totalDonations));
                        if (tvHomeRating != null) {
                            tvHomeRating.setText(String.format(java.util.Locale.getDefault(), "⭐ %.1f", user.rating));
                        }
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {
                    android.util.Log.e("HomeActivity", "User data error: " + error.getMessage());
                }
            });
        }
    }

    private void loadDonationsData() {
        // Load all donations for "Near You" (simplified for now)
        mDatabase.child("donations").addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                donationList.clear();
                long totalGlobalCount = 0;
                for (DataSnapshot postSnapshot : snapshot.getChildren()) {
                    Donation donation = postSnapshot.getValue(Donation.class);
                    if (donation != null) {
                        // Ensure ID is set even if not in the DB record (fallback)
                        if (donation.getDonationId() == null) {
                            donation.setDonationId(postSnapshot.getKey());
                        }
                        
                        // Only show if grace period (1 day after expiry) is not over
                        if (!DateUtils.isGracePeriodOver(donation.getExpiryDate())) {
                            donationList.add(0, donation); // Add to top (newest first)
                        }
                        totalGlobalCount++;
                    }
                }
                donationAdapter.notifyDataSetChanged();
                if (tvGlobalTotalDonations != null) {
                    tvGlobalTotalDonations.setText(String.valueOf(totalGlobalCount));
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
        // Sync bottom nav selection
        BottomNavigationView bottomNav = findViewById(R.id.bottomNavigationView);
        if (bottomNav != null) {
            bottomNav.setSelectedItemId(R.id.nav_home);
        }
    }

    private void setupBottomNavigation() {
        BottomNavigationView bottomNav = findViewById(R.id.bottomNavigationView);
        if (bottomNav != null) {
            bottomNav.setSelectedItemId(R.id.nav_home);
            bottomNav.setOnItemSelectedListener(item -> {
                int id = item.getItemId();
                Intent intent = null;
                if (id == R.id.nav_home) {
                    return true;
                } else if (id == R.id.nav_browse) {
                    intent = new Intent(this, BrowseActivity.class);
                    intent.putExtra("category", "All");
                } else if (id == R.id.nav_map) {
                    intent = new Intent(this, DashboardActivity.class);
                    intent.putExtra("OPEN_MAP", true);
                } else if (id == R.id.nav_profile) {
                    intent = new Intent(this, ProfileActivity.class);
                }
                
                if (intent != null) {
                    intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
                    startActivity(intent);
                    overridePendingTransition(0, 0);
                    return true;
                }
                return false;
            });
        }
    }

    private void setupChips() {
        findViewById(R.id.chipAll).setOnClickListener(v -> openBrowse("All"));
        findViewById(R.id.chipFood).setOnClickListener(v -> openBrowse("Food"));
        findViewById(R.id.chipClothes).setOnClickListener(v -> openBrowse("Clothes"));
        findViewById(R.id.chipItems).setOnClickListener(v -> openBrowse("Items"));
        findViewById(R.id.chipToys).setOnClickListener(v -> openBrowse("Toys"));
        findViewById(R.id.chipElectronics).setOnClickListener(v -> openBrowse("Electronics"));
        findViewById(R.id.chipTools).setOnClickListener(v -> openBrowse("Tools"));
        findViewById(R.id.chipOther).setOnClickListener(v -> openBrowse("Other"));
    }

    private void openBrowse(String category) {
        Intent intent = new Intent(HomeActivity.this, BrowseActivity.class);
        intent.putExtra("category", category);
        intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT);
        startActivity(intent);
    }
}
