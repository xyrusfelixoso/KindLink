package com.example.humania;

import android.os.Bundle;
import android.widget.Toast;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import java.util.ArrayList;
import java.util.List;

public class MyRequestsActivity extends AppCompatActivity {

    private RecyclerView rvMyRequests;
    private PickupRequestAdapter adapter;
    private List<PickupRequest> requestList;
    private DatabaseReference mDatabase;
    private String currentUserId;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_my_requests);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();
        currentUserId = FirebaseAuth.getInstance().getUid();

        rvMyRequests = findViewById(R.id.rvMyRequests);
        findViewById(R.id.btnBack).setOnClickListener(v -> finish());

        setupRecyclerView();
        loadMyRequests();
    }

    private void setupRecyclerView() {
        requestList = new ArrayList<>();
        // In "My Requests", we are the requester, so isDonorView is false
        adapter = new PickupRequestAdapter(requestList, false, new PickupRequestAdapter.OnRequestActionListener() {
            @Override
            public void onApprove(PickupRequest request) {}

            @Override
            public void onReject(PickupRequest request) {}

            @Override
            public void onConfirmPickup(PickupRequest request) {
                handlePickupConfirmation(request);
            }

            @Override
            public void onDeleteRequest(PickupRequest request) {
                if (request == null) return;
                mDatabase.child("pickupRequests").child(request.getRequestId()).removeValue()
                        .addOnSuccessListener(aVoid -> Toast.makeText(MyRequestsActivity.this, "Request removed from your list.", Toast.LENGTH_SHORT).show());
            }
        });
        rvMyRequests.setLayoutManager(new LinearLayoutManager(this));
        rvMyRequests.setAdapter(adapter);
    }

    private void handlePickupConfirmation(PickupRequest request) {
        // 1. Update Request status to COMPLETED
        mDatabase.child("pickupRequests").child(request.getRequestId()).child("status").setValue("COMPLETED")
                .addOnSuccessListener(aVoid -> {
                    // 2. Update Donation status to COMPLETED
                    mDatabase.child("donations").child(request.getDonationId()).child("status").setValue("COMPLETED");
                    Toast.makeText(this, "Pickup confirmed! Item is now removed from public feed.", Toast.LENGTH_SHORT).show();
                });
    }

    private void loadMyRequests() {
        if (currentUserId == null) return;

        mDatabase.child("pickupRequests").orderByChild("requesterId").equalTo(currentUserId)
                .addValueEventListener(new ValueEventListener() {
                    @Override
                    public void onDataChange(@NonNull DataSnapshot snapshot) {
                        requestList.clear();
                        for (DataSnapshot data : snapshot.getChildren()) {
                            PickupRequest request = data.getValue(PickupRequest.class);
                            if (request != null) {
                                requestList.add(request);
                            }
                        }
                        adapter.notifyDataSetChanged();
                    }

                    @Override
                    public void onCancelled(@NonNull DatabaseError error) {
                        Toast.makeText(MyRequestsActivity.this, "Error loading requests", Toast.LENGTH_SHORT).show();
                    }
                });
    }
}
