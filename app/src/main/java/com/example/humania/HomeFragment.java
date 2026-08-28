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

        setupRecyclerView();
        loadUserData();
        loadGlobalStats();
        loadDonations();

        // Category Chips
        setupChip(view.findViewById(R.id.chipAll), "All");
        setupChip(view.findViewById(R.id.chipFood), "Food");
        setupChip(view.findViewById(R.id.chipClothes), "Clothes");
        setupChip(view.findViewById(R.id.chipItems), "Items");
        setupChip(view.findViewById(R.id.chipToys), "Toys");
        setupChip(view.findViewById(R.id.chipElectronics), "Electronics");
        setupChip(view.findViewById(R.id.chipTools), "Tools");
        setupChip(view.findViewById(R.id.chipOther), "Other");

        // See All
        view.findViewById(R.id.tvSeeAll).setOnClickListener(v -> 
            Toast.makeText(getContext(), "See All clicked", Toast.LENGTH_SHORT).show());

        return view;
    }

    private void setupRecyclerView() {
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
                donationList.clear();
                for (DataSnapshot dataSnapshot : snapshot.getChildren()) {
                    Donation donation = dataSnapshot.getValue(Donation.class);
                    if (donation != null) {
                        if (donation.getDonationId() == null) {
                            donation.setDonationId(dataSnapshot.getKey());
                        }
                        
                        // Only show if grace period (1 day after expiry) is not over
                        if (!DateUtils.isGracePeriodOver(donation.getExpiryDate())) {
                            donationList.add(donation);
                        }
                    }
                }
                adapter.notifyDataSetChanged();
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                if (getContext() != null) {
                    Toast.makeText(getContext(), "Error loading donations: " + error.getMessage(), Toast.LENGTH_SHORT).show();
                }
            }
        });
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

    private void setupChip(View chip, String name) {
        if (chip != null) {
            chip.setOnClickListener(v -> 
                Toast.makeText(getContext(), name + " category selected", Toast.LENGTH_SHORT).show());
        }
    }
}
