package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import java.util.ArrayList;
import java.util.List;

public class BrowseFragment extends Fragment {

    private DatabaseReference mDatabase;
    private RecyclerView rvBrowse;
    private DonationAdapter adapter;
    private List<Donation> donationList;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_browse, container, false);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        rvBrowse = view.findViewById(R.id.rvBrowse);
        setupRecyclerView();
        loadDonations();

        return view;
    }

    private void setupRecyclerView() {
        donationList = new ArrayList<>();
        adapter = new DonationAdapter(donationList, donation -> {
            Intent intent = new Intent(getActivity(), DetailActivity.class);
            intent.putExtra("donation", donation);
            startActivity(intent);
        });
        rvBrowse.setLayoutManager(new LinearLayoutManager(getContext()));
        rvBrowse.setAdapter(adapter);
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
                        donationList.add(donation);
                    }
                }
                adapter.notifyDataSetChanged();
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
                if (getContext() != null) {
                    Toast.makeText(getContext(), "Error: " + error.getMessage(), Toast.LENGTH_SHORT).show();
                }
            }
        });
    }
}
