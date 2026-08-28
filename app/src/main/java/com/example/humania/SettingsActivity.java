package com.example.humania;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.TextView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import com.google.firebase.auth.FirebaseAuth;

public class SettingsActivity extends AppCompatActivity {

    private FirebaseAuth mAuth;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_settings);

        mAuth = FirebaseAuth.getInstance();

        findViewById(R.id.btnBack).setOnClickListener(v -> finish());

        // Account
        setupRow(R.id.itemEditProfile, "Edit Profile", v -> Toast.makeText(this, "Opening Edit Profile...", Toast.LENGTH_SHORT).show());
        setupRow(R.id.itemChangePassword, "Change Password", v -> Toast.makeText(this, "Opening Password Settings...", Toast.LENGTH_SHORT).show());
        setupRow(R.id.itemVerification, "Account Verification", v -> Toast.makeText(this, "Opening Verification...", Toast.LENGTH_SHORT).show());

        // Notifications
        setupRow(R.id.itemNotifRequests, "Requests", null);
        setupRow(R.id.itemNotifPickup, "Pickup Updates", null);
        setupRow(R.id.itemNotifReviews, "Reviews", null);
        setupRow(R.id.itemNotifAnnounce, "Announcements", null);

        // Privacy
        setupRow(R.id.itemPrivacyVisibility, "Profile Visibility", null);
        setupRow(R.id.itemPrivacyLocation, "Location Privacy", null);
        setupRow(R.id.itemPrivacyBlocked, "Blocked Users", null);
        setupRow(R.id.itemPrivacySessions, "Active Sessions", null);

        // Donation Prefs
        setupRow(R.id.itemPrefRadius, "Donation Radius", null);
        setupRow(R.id.itemPrefCategories, "Default Categories", null);
        setupRow(R.id.itemPrefPickup, "Pickup Preferences", null);
        setupRow(R.id.itemPrefAvailability, "Availability", null);

        // Appearance
        setupRow(R.id.itemApperTheme, "Theme", null);
        setupRow(R.id.itemApperLang, "Language", null);
        setupRow(R.id.itemApperTextSize, "Text Size", null);

        // Data
        setupRow(R.id.itemDataCache, "Clear Cache", v -> Toast.makeText(this, "Cache cleared", Toast.LENGTH_SHORT).show());

        // Help
        setupRow(R.id.itemHelpCenter, "Help Center", null);
        setupRow(R.id.itemHelpReport, "Report a Problem", null);
        setupRow(R.id.itemHelpContact, "Contact Support", null);

        // About
        setupRow(R.id.itemAboutPrivacy, "Privacy Policy", null);
        setupRow(R.id.itemAboutTerms, "Terms & Conditions", null);
        setupRow(R.id.itemAboutVersion, "App Version (1.0.0)", null);

        // Account Actions
        setupRow(R.id.itemActionLogout, "Log Out", v -> {
            mAuth.signOut();
            Intent intent = new Intent(this, MainActivity.class);
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
            startActivity(intent);
        });
        setupRow(R.id.itemActionDelete, "Delete Account", v -> Toast.makeText(this, "Contact support to delete account", Toast.LENGTH_LONG).show());
    }

    private void setupRow(int viewId, String title, View.OnClickListener listener) {
        View row = findViewById(viewId);
        if (row != null) {
            TextView tvTitle = row.findViewById(R.id.tvSettingsTitle);
            if (tvTitle != null) tvTitle.setText(title);
            
            if (listener != null) {
                row.setOnClickListener(listener);
            } else {
                row.setOnClickListener(v -> Toast.makeText(this, title + " coming soon", Toast.LENGTH_SHORT).show());
            }
        }
    }
}
