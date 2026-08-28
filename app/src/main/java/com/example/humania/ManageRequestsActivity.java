package com.example.humania;

import android.os.Bundle;
import android.widget.TextView;
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

public class ManageRequestsActivity extends AppCompatActivity {

    private RecyclerView rvManageRequests;
    private PickupRequestAdapter adapter;
    private List<PickupRequest> requestList;
    private DatabaseReference mDatabase;
    private String currentUserId;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_my_requests); // Reusing layout

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();
        currentUserId = FirebaseAuth.getInstance().getUid();

        rvManageRequests = findViewById(R.id.rvMyRequests);
        findViewById(R.id.btnBack).setOnClickListener(v -> finish());
        
        TextView tvTitle = findViewById(R.id.tvToolbarTitle);
        if (tvTitle != null) {
            tvTitle.setText("Donation Requests");
        }

        setupRecyclerView();
        loadIncomingRequests();
    }

    private void setupRecyclerView() {
        requestList = new ArrayList<>();
        adapter = new PickupRequestAdapter(requestList, true, new PickupRequestAdapter.OnRequestActionListener() {
            @Override
            public void onApprove(PickupRequest request) {
                updateRequestStatus(request, "APPROVED");
                markDonationAsReserved(request.getDonationId());
            }

            @Override
            public void onReject(PickupRequest request) {
                updateRequestStatus(request, "REJECTED");
            }
        });
        rvManageRequests.setLayoutManager(new LinearLayoutManager(this));
        rvManageRequests.setAdapter(adapter);
    }

    private void loadIncomingRequests() {
        if (currentUserId == null) return;

        mDatabase.child("pickupRequests").orderByChild("donorId").equalTo(currentUserId)
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
                    public void onCancelled(@NonNull DatabaseError error) {}
                });
    }

    private void updateRequestStatus(PickupRequest request, String status) {
        mDatabase.child("pickupRequests").child(request.getRequestId()).child("status").setValue(status)
                .addOnSuccessListener(aVoid -> Toast.makeText(this, "Request " + status, Toast.LENGTH_SHORT).show());
    }

    private void markDonationAsReserved(String donationId) {
        if (donationId == null) return;
        mDatabase.child("donations").child(donationId).child("status").setValue("RESERVED");
    }
}
