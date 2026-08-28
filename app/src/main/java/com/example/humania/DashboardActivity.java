package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.view.GravityCompat;
import androidx.drawerlayout.widget.DrawerLayout;
import androidx.fragment.app.Fragment;
import com.google.android.material.bottomnavigation.BottomNavigationView;
import com.google.android.material.floatingactionbutton.FloatingActionButton;
import com.google.android.material.navigation.NavigationView;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

public class DashboardActivity extends AppCompatActivity {

    private DrawerLayout drawerLayout;
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

        drawerLayout = findViewById(R.id.drawer_layout);
        bottomNav = findViewById(R.id.bottom_navigation);
        FloatingActionButton fab = findViewById(R.id.fab_add);
        NavigationView sideNav = findViewById(R.id.side_navigation);

        // Update Side Navigation Header
        updateSideNavHeader(sideNav);

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

        sideNav.setNavigationItemSelectedListener(item -> {
            int id = item.getItemId();
            if (id == R.id.nav_logout) {
                FirebaseAuth.getInstance().signOut();
                startActivity(new Intent(DashboardActivity.this, MainActivity.class));
                finish();
            }
            drawerLayout.closeDrawer(GravityCompat.START);
            return true;
        });
    }

    private void updateSideNavHeader(NavigationView sideNav) {
        View headerView = sideNav.getHeaderView(0);
        TextView tvNavName = headerView.findViewById(R.id.nav_header_name);
        TextView tvNavEmail = headerView.findViewById(R.id.nav_header_email);

        FirebaseUser firebaseUser = mAuth.getCurrentUser();
        if (firebaseUser != null) {
            String userId = firebaseUser.getUid();
            mDatabase.child("users").child(userId).addValueEventListener(new ValueEventListener() {
                @Override
                public void onDataChange(@NonNull DataSnapshot snapshot) {
                    User user = snapshot.getValue(User.class);
                    if (user != null) {
                        if (tvNavName != null) tvNavName.setText(user.fullName);
                        if (tvNavEmail != null) tvNavEmail.setText(user.email);
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {
                    android.util.Log.e("DashboardActivity", "Side nav header error: " + error.getMessage());
                }
            });
        }
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

    public void openDrawer() {
        if (drawerLayout != null) {
            drawerLayout.openDrawer(GravityCompat.START);
        }
    }
}
