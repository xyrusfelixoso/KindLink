package com.example.humania;

import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.Query;
import com.google.firebase.database.ValueEventListener;

import java.util.ArrayList;
import java.util.List;

public class MyDonationsActivity extends AppCompatActivity {

    private RecyclerView rvMyDonations;
    private TextView tvEmptyState;
    private MyDonationsAdapter adapter;
    private List<Donation> donationList;
    private DatabaseReference mDatabase;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_my_donations);

        findViewById(R.id.btnBack).setOnClickListener(v -> finish());

        rvMyDonations = findViewById(R.id.rvMyDonations);
        tvEmptyState = findViewById(R.id.tvEmptyState);

        donationList = new ArrayList<>();
        rvMyDonations.setLayoutManager(new LinearLayoutManager(this));
        adapter = new MyDonationsAdapter(donationList);
        rvMyDonations.setAdapter(adapter);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        loadMyDonations();
    }

    private void loadMyDonations() {
        String userId = FirebaseAuth.getInstance().getCurrentUser().getUid();
        Query myDonationsQuery = mDatabase.child("donations").orderByChild("userId").equalTo(userId);

        myDonationsQuery.addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                donationList.clear();
                for (DataSnapshot postSnapshot : snapshot.getChildren()) {
                    Donation donation = postSnapshot.getValue(Donation.class);
                    if (donation != null) {
                        if (donation.getDonationId() == null) {
                            donation.setDonationId(postSnapshot.getKey());
                        }
                        donationList.add(donation);
                    }
                }

                if (donationList.isEmpty()) {
                    tvEmptyState.setVisibility(View.VISIBLE);
                    rvMyDonations.setVisibility(View.GONE);
                } else {
                    tvEmptyState.setVisibility(View.GONE);
                    rvMyDonations.setVisibility(View.VISIBLE);
                    adapter.notifyDataSetChanged();
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                // Handle possible errors.
            }
        });
    }
}
