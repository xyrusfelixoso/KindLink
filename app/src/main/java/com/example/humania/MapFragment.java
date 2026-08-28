package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.OnMapReadyCallback;
import com.google.android.gms.maps.SupportMapFragment;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;
import java.util.HashMap;
import java.util.Map;

public class MapFragment extends Fragment implements OnMapReadyCallback {

    private GoogleMap mMap;
    private DatabaseReference mDatabase;
    private Map<Marker, Donation> markerDonationMap = new HashMap<>();

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        View view = inflater.inflate(R.layout.fragment_map, container, false);

        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference("donations");

        SupportMapFragment mapFragment = (SupportMapFragment) getChildFragmentManager().findFragmentById(R.id.mapFragment);
        if (mapFragment != null) {
            mapFragment.getMapAsync(this);
        }

        return view;
    }

    @Override
    public void onMapReady(@NonNull GoogleMap googleMap) {
        mMap = googleMap;
        
        // Default location: Davao City area
        LatLng davao = new LatLng(7.0707, 125.6087);
        mMap.moveCamera(CameraUpdateFactory.newLatLngZoom(davao, 12f));

        mMap.setOnMarkerClickListener(marker -> {
            Donation donation = markerDonationMap.get(marker);
            if (donation != null) {
                Intent intent = new Intent(getActivity(), DetailActivity.class);
                intent.putExtra("donation", donation);
                startActivity(intent);
            }
            return true;
        });

        loadDonationMarkers();
    }

    private void loadDonationMarkers() {
        mDatabase.addValueEventListener(new ValueEventListener() {
            @Override
            public void onDataChange(@NonNull DataSnapshot snapshot) {
                if (mMap == null) return;
                mMap.clear();
                markerDonationMap.clear();

                for (DataSnapshot postSnapshot : snapshot.getChildren()) {
                    Donation donation = postSnapshot.getValue(Donation.class);
                    if (donation != null && donation.getLatitude() != 0 && donation.getLongitude() != 0) {
                        // Only show if grace period (1 day after expiry) is not over
                        if (!DateUtils.isGracePeriodOver(donation.getExpiryDate())) {
                            LatLng pos = new LatLng(donation.getLatitude(), donation.getLongitude());
                            Marker marker = mMap.addMarker(new MarkerOptions()
                                    .position(pos)
                                    .title(donation.getTitle())
                                    .snippet(donation.getCategory())
                                    .icon(BitmapDescriptorFactory.defaultMarker(BitmapDescriptorFactory.HUE_GREEN)));
                            
                            if (marker != null) {
                                markerDonationMap.put(marker, donation);
                            }
                        }
                    }
                }
            }

            @Override
            public void onCancelled(@NonNull DatabaseError error) {
            }
        });
    }
}
