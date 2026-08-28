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
import com.google.firebase.database.Query;
import com.google.firebase.database.ValueEventListener;

import java.util.ArrayList;
import java.util.List;

public class ProfileFragment extends Fragment {

    private TextView tvProfileName, tvProfileHandle, tvStatDonated, tvProfileRating;
    private DatabaseReference mDatabase;
    private FirebaseAuth mAuth;
    private View sectionMyDonations, sectionExpiredItems;
    private RecyclerView rvMyDonations, rvExpiredItems;
    private MyDonationsAdapter adapter, expiredAdapter;
    private List<Donation> donationList, expiredList;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_profile, container, false);

        mAuth = FirebaseAuth.getInstance();
        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        tvProfileName = view.findViewById(R.id.tvProfileName);
        tvProfileHandle = view.findViewById(R.id.tvProfileHandle);
        tvStatDonated = view.findViewById(R.id.tvStatDonated);
        tvProfileRating = view.findViewById(R.id.tvProfileRating);
        sectionMyDonations = view.findViewById(R.id.sectionMyDonations);
        rvMyDonations = view.findViewById(R.id.rvMyDonationsProfile);
        
        sectionExpiredItems = view.findViewById(R.id.sectionExpiredItems);
        rvExpiredItems = view.findViewById(R.id.rvExpiredItems);

        // Sidebar/Drawer menu button
        View btnMenu = view.findViewById(R.id.btnOpenDrawer);
        if (btnMenu != null) {
            btnMenu.setOnClickListener(v -> {
                if (getActivity() instanceof DashboardActivity) {
                    ((DashboardActivity) getActivity()).openDrawer();
                }
            });
        }

        // See All Donations link
        View tvSeeAll = view.findViewById(R.id.tvSeeAllDonations);
        if (tvSeeAll != null) {
            tvSeeAll.setOnClickListener(v -> {
                startActivity(new Intent(getActivity(), MyDonationsActivity.class));
            });
        }

        // Initialize Menu Items with CORRECT labels
        setupMenuItem(view.findViewById(R.id.menuRequests), "My Requests", "Manage your requests", "🤝", v -> {
            startActivity(new Intent(getActivity(), MyRequestsActivity.class));
        });
        setupMenuItem(view.findViewById(R.id.menuMessages), "Donation Requests", "Approve or decline requests", "📦", v -> {
            startActivity(new Intent(getActivity(), ManageRequestsActivity.class));
        });
        setupMenuItem(view.findViewById(R.id.menuReviews), "Reviews", "Feedback from others", "⭐", v -> {
            Intent intent = new Intent(getActivity(), ReviewListActivity.class);
            intent.putExtra("targetUserId", mAuth.getUid());
            startActivity(intent);
        });
        setupMenuItem(view.findViewById(R.id.menuSettings), "Settings", "Account and security", "⚙️", v -> {
            startActivity(new Intent(getActivity(), SettingsActivity.class));
        });
        setupMenuItem(view.findViewById(R.id.menuLogout), "Log Out", "Exit your account", "🚪", v -> {
            mAuth.signOut();
            Intent intent = new Intent(getActivity(), MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            startActivity(intent);
        });

        setupRecyclerView();
        loadUserData();
        loadMyDonations();

        return view;
    }

    private void setupRecyclerView() {
        donationList = new ArrayList<>();
        adapter = new MyDonationsAdapter(donationList);
        if (rvMyDonations != null) {
            rvMyDonations.setLayoutManager(new LinearLayoutManager(getContext()));
            rvMyDonations.setAdapter(adapter);
            rvMyDonations.setNestedScrollingEnabled(false);
        }

        expiredList = new ArrayList<>();
        expiredAdapter = new MyDonationsAdapter(expiredList);
        if (rvExpiredItems != null) {
            rvExpiredItems.setLayoutManager(new LinearLayoutManager(getContext()));
            rvExpiredItems.setAdapter(expiredAdapter);
            rvExpiredItems.setNestedScrollingEnabled(false);
        }
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
                        if (tvProfileName != null) tvProfileName.setText(user.fullName);
                        if (tvProfileHandle != null) tvProfileHandle.setText("@" + user.fullName.toLowerCase().replace(" ", "") + " · ✅ Verified");
                        if (tvStatDonated != null) tvStatDonated.setText(String.valueOf(user.totalDonations));
                        if (tvProfileRating != null) {
                            tvProfileRating.setText(String.format(java.util.Locale.getDefault(), "⭐ %.1f", user.rating));
                        }
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {
                    if (getContext() != null) {
                        Toast.makeText(getContext(), "Profile data error: " + error.getMessage(), Toast.LENGTH_SHORT).show();
                    }
                }
            });
        }
    }

    private void loadMyDonations() {
        FirebaseUser firebaseUser = mAuth.getCurrentUser();
        if (firebaseUser == null) return;

        String userId = firebaseUser.getUid();
        Query myDonationsQuery = mDatabase.child("donations").orderByChild("userId").equalTo(userId);

        myDonationsQuery.addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                donationList.clear();
                expiredList.clear();
                for (DataSnapshot postSnapshot : snapshot.getChildren()) {
                    Donation donation = postSnapshot.getValue(Donation.class);
                    if (donation != null) {
                        if (donation.getDonationId() == null) {
                            donation.setDonationId(postSnapshot.getKey());
                        }
                        
                        if (DateUtils.isGracePeriodOver(donation.getExpiryDate())) {
                            expiredList.add(0, donation);
                        } else {
                            donationList.add(0, donation); // Newest first
                        }
                    }
                }

                // Show/Hide Active Donations
                if (donationList.isEmpty()) {
                    if (sectionMyDonations != null) sectionMyDonations.setVisibility(View.GONE);
                } else {
                    if (sectionMyDonations != null) sectionMyDonations.setVisibility(View.VISIBLE);
                    adapter.notifyDataSetChanged();
                }

                // Show/Hide Expired Donations
                if (expiredList.isEmpty()) {
                    if (sectionExpiredItems != null) sectionExpiredItems.setVisibility(View.GONE);
                } else {
                    if (sectionExpiredItems != null) sectionExpiredItems.setVisibility(View.VISIBLE);
                    expiredAdapter.notifyDataSetChanged();
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                if (getContext() != null) {
                    android.util.Log.e("ProfileFragment", "My donations error: " + error.getMessage());
                }
            }
        });
    }

    private void setupMenuItem(View menu, String title, String subtitle, String icon, View.OnClickListener listener) {
        if (menu != null) {
            TextView tvTitle = menu.findViewById(R.id.tvMenuTitle);
            TextView tvSubtitle = menu.findViewById(R.id.tvMenuSubtitle);
            TextView tvIcon = menu.findViewById(R.id.tvMenuIcon);

            if (tvTitle != null) tvTitle.setText(title);
            if (tvSubtitle != null) tvSubtitle.setText(subtitle);
            if (tvIcon != null) tvIcon.setText(icon);

            menu.setOnClickListener(listener);
        }
    }
}
