package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import androidx.appcompat.app.AppCompatActivity;
import com.google.android.material.bottomnavigation.BottomNavigationView;

public class BrowseActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_browse);

        String category = getIntent().getStringExtra("category");
        if (category != null) {
            TextView tvTitle = findViewById(R.id.tvBrowseTitle);
            if (tvTitle != null) tvTitle.setText("Browse: " + category);
        }

        findViewById(R.id.btnBrowseBack).setOnClickListener(v -> finish());

        // Make cards functional
        setupCards();

        setupBottomNavigation();
    }

    private void setupCards() {
        View card1 = findViewById(R.id.browseCard1);
        View card2 = findViewById(R.id.browseCard2);
        View card3 = findViewById(R.id.browseCard3);
        View card4 = findViewById(R.id.browseCard4);

        if (card1 != null) card1.setOnClickListener(v -> openDetail("Fresh Vegetables Bundle"));
        if (card2 != null) card2.setOnClickListener(v -> openDetail("Warm Clothes for Kids"));
        if (card3 != null) card3.setOnClickListener(v -> openDetail("Educational Toys Set"));
        if (card4 != null) card4.setOnClickListener(v -> openDetail("Canned Goods Assortment"));
    }

    private void openDetail(String title) {
        Intent intent = new Intent(BrowseActivity.this, DetailActivity.class);
        intent.putExtra("title", title);
        startActivity(intent);
    }

    private void setupBottomNavigation() {
        BottomNavigationView bottomNav = findViewById(R.id.bottomNavigationView);
        if (bottomNav != null) {
            bottomNav.setSelectedItemId(R.id.nav_browse);
            bottomNav.setOnItemSelectedListener(item -> {
                int id = item.getItemId();
                if (id == R.id.nav_home) {
                    startActivity(new Intent(this, HomeActivity.class));
                    finish();
                    return true;
                } else if (id == R.id.nav_browse) {
                    return true;
                } else if (id == R.id.nav_map) {
                    Intent intent = new Intent(this, DashboardActivity.class);
                    intent.putExtra("OPEN_MAP", true);
                    startActivity(intent);
                    finish();
                    return true;
                } else if (id == R.id.nav_profile) {
                    startActivity(new Intent(this, ProfileActivity.class));
                    finish();
                    return true;
                }
                return false;
            });
        }
    }
}
