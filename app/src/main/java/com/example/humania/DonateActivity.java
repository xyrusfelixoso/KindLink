package com.example.humania;

import android.Manifest;
import android.app.DatePickerDialog;
import android.app.TimePickerDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AlertDialog;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.FileProvider;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ValueEventListener;

import java.io.File;
import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;

public class DonateActivity extends AppCompatActivity {

    private static final int CAMERA_PERMISSION_CODE = 101;
    private static final int CAMERA_REQUEST_CODE = 102;
    private static final int MAP_PICKER_REQUEST_CODE = 103;
    
    private LinearLayout uploadZone;
    private ImageView ivPreview;
    private String currentPhotoPath;
    
    private TextView catFood, catClothes, catItems, catToys, catElectronics, catTools, catOther;
    private EditText etTitle, etDescription, etQuantity, etExpiry, etLocation, etDonorName;
    private Button btnPostDonation;
    private String selectedCategory = "Food"; // Default
    private double selectedLat = 0, selectedLng = 0;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.fragment_donate);

        initViews();
        setupListeners();
        fetchCurrentUserName();
    }

    private void fetchCurrentUserName() {
        String uid = FirebaseAuth.getInstance().getUid();
        if (uid != null) {
            String databaseUrl = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
            FirebaseDatabase.getInstance(databaseUrl).getReference("users").child(uid).child("fullName")
                    .addListenerForSingleValueEvent(new ValueEventListener() {
                @Override
                public void onDataChange(@NonNull DataSnapshot snapshot) {
                    if (snapshot.exists()) {
                        String fullName = snapshot.getValue(String.class);
                        if (etDonorName != null && fullName != null) {
                            etDonorName.setText(fullName);
                        }
                    }
                }

                @Override
                public void onCancelled(@NonNull DatabaseError error) {}
            });
        }
    }

    private void initViews() {
        uploadZone = findViewById(R.id.uploadZone);
        ivPreview = findViewById(R.id.ivPreview);
        
        catFood = findViewById(R.id.catFood);
        catClothes = findViewById(R.id.catClothes);
        catItems = findViewById(R.id.catItems);
        catToys = findViewById(R.id.catToys);
        catElectronics = findViewById(R.id.catElectronics);
        catTools = findViewById(R.id.catTools);
        catOther = findViewById(R.id.catOther);
        
        etDonorName = findViewById(R.id.etDonorName);
        etTitle = findViewById(R.id.etTitle);
        etDescription = findViewById(R.id.etDescription);
        etQuantity = findViewById(R.id.etQuantity);
        etExpiry = findViewById(R.id.etExpiry);
        etLocation = findViewById(R.id.etLocation);
        
        btnPostDonation = findViewById(R.id.btnPostDonation);
    }

    private void setupListeners() {
        View btnBack = findViewById(R.id.btnBack);
        if (btnBack != null) {
            btnBack.setOnClickListener(v -> finish());
        }

        if (uploadZone != null) {
            uploadZone.setOnClickListener(v -> {
                if (checkCameraPermission()) {
                    openCamera();
                } else {
                    requestCameraPermission();
                }
            });
        }

        // Category Listeners
        if (catFood != null) catFood.setOnClickListener(v -> selectCategory("Food", catFood));
        if (catClothes != null) catClothes.setOnClickListener(v -> selectCategory("Clothes", catClothes));
        if (catItems != null) catItems.setOnClickListener(v -> selectCategory("Items", catItems));
        if (catToys != null) catToys.setOnClickListener(v -> selectCategory("Toys", catToys));
        if (catElectronics != null) catElectronics.setOnClickListener(v -> selectCategory("Electronics", catElectronics));
        if (catTools != null) catTools.setOnClickListener(v -> selectCategory("Tools", catTools));
        if (catOther != null) catOther.setOnClickListener(v -> selectCategory("Other", catOther));

        // Expiry Date Picker
        if (etExpiry != null) {
            etExpiry.setOnClickListener(v -> showDatePicker());
        }

        // Map Location Picker
        if (etLocation != null) {
            etLocation.setOnClickListener(v -> {
                Intent intent = new Intent(DonateActivity.this, MapPickerActivity.class);
                startActivityForResult(intent, MAP_PICKER_REQUEST_CODE);
            });
        }

        // Post Donation
        if (btnPostDonation != null) {
            btnPostDonation.setOnClickListener(v -> handlePostDonation());
        }
    }

    private void selectCategory(String category, TextView selectedView) {
        selectedCategory = category;
        
        // Reset all categories to default style
        TextView[] chips = {catFood, catClothes, catItems, catToys, catElectronics, catTools, catOther};
        for (TextView chip : chips) {
            if (chip != null) {
                chip.setBackgroundResource(R.drawable.bg_chip);
                chip.setTextColor(ContextCompat.getColor(this, R.color.text_secondary));
            }
        }

        // Apply active style to selected
        if (selectedView != null) {
            selectedView.setBackgroundResource(R.drawable.bg_chip_active);
            selectedView.setTextColor(ContextCompat.getColor(this, R.color.white));
        }
    }

    private void showDatePicker() {
        final Calendar c = Calendar.getInstance();
        int year = c.get(Calendar.YEAR);
        int month = c.get(Calendar.MONTH);
        int day = c.get(Calendar.DAY_OF_MONTH);

        DatePickerDialog datePickerDialog = new DatePickerDialog(this,
                (view, year1, monthOfYear, dayOfMonth) -> {
                    // After picking date, pick time
                    showTimePicker(year1, monthOfYear, dayOfMonth);
                }, year, month, day);
        
        // Restrict to today or future dates
        datePickerDialog.getDatePicker().setMinDate(c.getTimeInMillis());
        datePickerDialog.show();
    }

    private void showTimePicker(int year, int month, int day) {
        final Calendar c = Calendar.getInstance();
        int hour = c.get(Calendar.HOUR_OF_DAY);
        int minute = c.get(Calendar.MINUTE);

        TimePickerDialog timePickerDialog = new TimePickerDialog(this,
                (view, hourOfDay, minute1) -> {
                    String dateTime = String.format(Locale.getDefault(), "%04d-%02d-%02d %02d:%02d", 
                            year, month + 1, day, hourOfDay, minute1);
                    etExpiry.setText(dateTime);
                }, hour, minute, true);
        timePickerDialog.show();
    }

    private void handlePostDonation() {
        String donorName = etDonorName.getText().toString().trim();
        String title = etTitle.getText().toString().trim();
        String desc = etDescription.getText().toString().trim();
        String qty = etQuantity.getText().toString().trim();
        String expiry = etExpiry.getText().toString().trim();
        String loc = etLocation.getText().toString().trim();

        if (donorName.isEmpty() || title.isEmpty() || desc.isEmpty() || qty.isEmpty() || loc.isEmpty()) {
            Toast.makeText(this, "Please fill in all required fields", Toast.LENGTH_SHORT).show();
            return;
        }

        // Prepare metadata
        String timestamp = new SimpleDateFormat("MMM dd, yyyy HH:mm", Locale.getDefault()).format(new Date());
        String userId = FirebaseAuth.getInstance().getCurrentUser().getUid();

        // Save donation to Firebase via DonationManager
        btnPostDonation.setEnabled(false);
        
        // Alternative way: Convert to Base64 to bypass Storage plan limits
        String base64Image = DonationManager.encodeImageToBase64(currentPhotoPath);
        
        // Save to Database
        Donation newDonation = new Donation(title, desc, qty, expiry, loc, selectedLat, selectedLng, 
                selectedCategory, base64Image, timestamp, userId, donorName);

        DonationManager.addDonation(newDonation, (success, message) -> {
            btnPostDonation.setEnabled(true);
            if (success) {
                new AlertDialog.Builder(this)
                        .setTitle("Donation Posted")
                        .setMessage("Success! Your donation of '" + title + "' has been posted.")
                        .setPositiveButton("OK", (dialog, which) -> {
                            setResult(RESULT_OK);
                            finish();
                        })
                        .show();
            } else {
                Toast.makeText(this, "Failed to post donation: " + message, Toast.LENGTH_SHORT).show();
            }
        });
    }

    private boolean checkCameraPermission() {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED;
    }

    private void requestCameraPermission() {
        ActivityCompat.requestPermissions(this, new String[]{Manifest.permission.CAMERA}, CAMERA_PERMISSION_CODE);
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == CAMERA_PERMISSION_CODE) {
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                openCamera();
            } else {
                Toast.makeText(this, "Camera permission is required to take photos", Toast.LENGTH_SHORT).show();
            }
        }
    }

    private void openCamera() {
        Intent takePictureIntent = new Intent(MediaStore.ACTION_IMAGE_CAPTURE);
        if (takePictureIntent.resolveActivity(getPackageManager()) != null) {
            File photoFile = null;
            try {
                photoFile = createImageFile();
            } catch (IOException ex) {
                Toast.makeText(this, "Error creating file", Toast.LENGTH_SHORT).show();
            }

            if (photoFile != null) {
                Uri photoURI = FileProvider.getUriForFile(this,
                        getApplicationContext().getPackageName() + ".fileprovider",
                        photoFile);
                takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI);
                startActivityForResult(takePictureIntent, CAMERA_REQUEST_CODE);
            }
        }
    }

    private File createImageFile() throws IOException {
        String timeStamp = new SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(new Date());
        String imageFileName = "JPEG_" + timeStamp + "_";
        File storageDir = getExternalFilesDir(Environment.DIRECTORY_PICTURES);
        File image = File.createTempFile(imageFileName, ".jpg", storageDir);
        currentPhotoPath = image.getAbsolutePath();
        return image;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == CAMERA_REQUEST_CODE && resultCode == RESULT_OK) {
            if (ivPreview != null) {
                ivPreview.setVisibility(View.VISIBLE);
                ivPreview.setImageURI(Uri.fromFile(new File(currentPhotoPath)));
                View tvCameraEmoji = findViewById(R.id.tvCameraEmoji);
                View tvAddPhotos = findViewById(R.id.tvAddPhotos);
                View tvUploadHint = findViewById(R.id.tvUploadHint);
                if (tvCameraEmoji != null) tvCameraEmoji.setVisibility(View.GONE);
                if (tvAddPhotos != null) tvAddPhotos.setVisibility(View.GONE);
                if (tvUploadHint != null) tvUploadHint.setVisibility(View.GONE);
            }
            Toast.makeText(this, "Photo added!", Toast.LENGTH_SHORT).show();
        } else if (requestCode == MAP_PICKER_REQUEST_CODE && resultCode == RESULT_OK && data != null) {
            String address = data.getStringExtra("address");
            selectedLat = data.getDoubleExtra("latitude", 0);
            selectedLng = data.getDoubleExtra("longitude", 0);
            if (etLocation != null) {
                etLocation.setText(address);
            }
        }
    }
}
