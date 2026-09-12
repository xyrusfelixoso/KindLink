package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import java.util.ArrayList;
import java.util.List;

public class HomeFragment extends Fragment {

    private TextView tvUserName, tvHomeStatDonated, tvGlobalTotalDonations;
    private DatabaseReference mDatabase;
    private FirebaseAuth mAuth;
    private RecyclerView rvNearYou;
    private DonationAdapter adapter;
    private List<Donation> donationList;
    private List<Donation> fullDonationList;
    private TextView[] categoryChips;
    private String currentCategory = "All";

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_home, container, false);

        mAuth = FirebaseAuth.getInstance();
        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        tvUserName = view.findViewById(R.id.tvUserName);
        tvHomeStatDonated = view.findViewById(R.id.tvHomeStatDonated);
        tvGlobalTotalDonations = view.findViewById(R.id.tvGlobalTotalDonations);
        rvNearYou = view.findViewById(R.id.rvNearYou);

        initCategoryChips(view);
        setupRecyclerView();
        loadUserData();
        loadGlobalStats();
        loadDonations();

        // See All
        view.findViewById(R.id.tvSeeAll).setOnClickListener(v -> 
            Toast.makeText(getContext(), "See All clicked", Toast.LENGTH_SHORT).show());

        return view;
    }

    private void setupRecyclerView() {
        fullDonationList = new ArrayList<>();
        donationList = new ArrayList<>();
        adapter = new DonationAdapter(donationList, donation -> {
            Intent intent = new Intent(getActivity(), DetailActivity.class);
            intent.putExtra("donation", donation);
            startActivity(intent);
        });
        if (rvNearYou != null) {
            rvNearYou.setLayoutManager(new LinearLayoutManager(getContext()));
            rvNearYou.setAdapter(adapter);
            rvNearYou.setNestedScrollingEnabled(false);
        }
    }

    private void loadDonations() {
        mDatabase.child("donations").addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                fullDonationList.clear();
                for (DataSnapshot dataSnapshot : snapshot.getChildren()) {
                    Donation donation = dataSnapshot.getValue(Donation.class);
                    if (donation != null) {
                        if (donation.getDonationId() == null) {
                            donation.setDonationId(dataSnapshot.getKey());
                        }
                        
                        // Only show if NOT expired exactly at the set time
                        if (!DateUtils.isExpired(donation.getExpiryDate())) {
                            fullDonationList.add(donation);
                        }
                    }
                }
                filterDonations(currentCategory);
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                if (getContext() != null) {
                    Toast.makeText(getContext(), "Error loading donations: " + error.getMessage(), Toast.LENGTH_SHORT).show();
                }
            }
        });
    }

    private void initCategoryChips(View view) {
        TextView chipAll = view.findViewById(R.id.chipAll);
        TextView chipFood = view.findViewById(R.id.chipFood);
        TextView chipClothes = view.findViewById(R.id.chipClothes);
        TextView chipItems = view.findViewById(R.id.chipItems);
        TextView chipToys = view.findViewById(R.id.chipToys);
        TextView chipElectronics = view.findViewById(R.id.chipElectronics);
        TextView chipTools = view.findViewById(R.id.chipTools);
        TextView chipOther = view.findViewById(R.id.chipOther);

        categoryChips = new TextView[]{chipAll, chipFood, chipClothes, chipItems, chipToys, chipElectronics, chipTools, chipOther};

        setupChip(chipAll, "All");
        setupChip(chipFood, "Food");
        setupChip(chipClothes, "Clothes");
        setupChip(chipItems, "Items");
        setupChip(chipToys, "Toys");
        setupChip(chipElectronics, "Electronics");
        setupChip(chipTools, "Tools");
        setupChip(chipOther, "Other");
    }

    private void setupChip(TextView chip, String category) {
        if (chip != null) {
            chip.setOnClickListener(v -> {
                currentCategory = category;
                updateChipStyles();
                filterDonations(category);
            });
        }
    }

    private void updateChipStyles() {
        if (getContext() == null || categoryChips == null) return;
        
        for (TextView chip : categoryChips) {
            if (chip == null) continue;
            
            String chipText = chip.getText().toString();
            boolean isActive;
            if (currentCategory.equals("All")) {
                isActive = chip.getId() == R.id.chipAll;
            } else {
                isActive = chipText.equalsIgnoreCase(currentCategory);
            }

            if (isActive) {
                chip.setBackgroundResource(R.drawable.bg_chip_active);
                chip.setTextColor(androidx.core.content.ContextCompat.getColor(getContext(), R.color.white));
            } else {
                chip.setBackgroundResource(R.drawable.bg_chip);
                chip.setTextColor(androidx.core.content.ContextCompat.getColor(getContext(), R.color.text_secondary));
            }
        }
    }

    private void filterDonations(String category) {
        donationList.clear();
        for (Donation d : fullDonationList) {
            // Filter by Category
            boolean categoryMatch = category.equalsIgnoreCase("All") || (d.getCategory() != null && d.getCategory().equalsIgnoreCase(category));
            
            // Filter by Status: Only show AVAILABLE items
            boolean isAvailable = d.getStatus() == null || d.getStatus().equalsIgnoreCase("AVAILABLE");

            if (categoryMatch && isAvailable) {
                donationList.add(d);
            }
        }
        
        // Sort by timestamp (newest first)
        java.util.Collections.sort(donationList, (d1, d2) -> {
            String t1 = d1.getTimestamp() != null ? d1.getTimestamp() : "";
            String t2 = d2.getTimestamp() != null ? d2.getTimestamp() : "";
            return t2.compareTo(t1);
        });

        adapter.notifyDataSetChanged();
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
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {
                    if (getContext() != null) {
                        Toast.makeText(getContext(), "User data error: " + error.getMessage(), Toast.LENGTH_SHORT).show();
                    }
                }
            });
        }
    }

    private void loadGlobalStats() {
        mDatabase.child("globalStats").child("totalDonations").addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                Long total = snapshot.getValue(Long.class);
                if (tvGlobalTotalDonations != null) {
                    tvGlobalTotalDonations.setText(total != null ? String.valueOf(total) : "0");
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                if (getContext() != null) {
                    android.util.Log.e("HomeFragment", "Global stats error: " + error.getMessage());
                }
            }
        });
    }
}
