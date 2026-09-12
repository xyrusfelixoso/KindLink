package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.fragment.app.Fragment;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

public class DashboardActivity extends AppCompatActivity {

    private BottomNavigationView bottomNav;
    private DatabaseReference mDatabase;
    private FirebaseAuth mAuth;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_dashboard);

        mAuth = FirebaseAuth.getInstance();
        String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
        mDatabase = FirebaseDatabase.getInstance(databaseUrl).getReference();

        bottomNav = findViewById(R.id.bottom_navigation);
        FloatingActionButton fab = findViewById(R.id.fab_add);

        // Set default fragment
        if (savedInstanceState == null) {
            if (getIntent().getBooleanExtra("OPEN_MAP", false)) {
                loadFragment(new MapFragment(), R.id.nav_map);
            } else {
                loadFragment(new HomeFragment(), R.id.nav_home);
            }
        }

        bottomNav.setOnItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_home) return loadFragment(new HomeFragment(), id);
            if (id == R.id.nav_browse) return loadFragment(new BrowseFragment(), id);
            if (id == R.id.nav_map) return loadFragment(new MapFragment(), id);
            if (id == R.id.nav_profile) return loadFragment(new ProfileFragment(), id);
            return false;
        });

        fab.setOnClickListener(v -> {
            Intent intent = new Intent(DashboardActivity.this, DonateActivity.class);
            startActivity(intent);
        });
    }

    private boolean loadFragment(Fragment fragment, int itemId) {
        if (fragment != null) {
            getSupportFragmentManager().beginTransaction()
                    .replace(R.id.nav_host_fragment, fragment)
                    .commit();
            bottomNav.getMenu().findItem(itemId).setChecked(true);
            return true;
        }
        return false;
    }

    public void switchToBrowse() {
        bottomNav.setSelectedItemId(R.id.nav_browse);
    }
}
