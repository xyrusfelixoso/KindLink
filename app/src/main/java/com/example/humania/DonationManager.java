package com.example.humania;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;
import com.google.firebase.database.DatabaseReference;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.database.ServerValue;
import com.google.firebase.database.ValueEventListener;
import com.google.firebase.storage.FirebaseStorage;
import com.google.firebase.storage.StorageReference;
import com.google.firebase.storage.UploadTask;

import androidx.annotation.NonNull;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.util.Base64;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;

public class DonationManager {
    private static final String DATABASE_URL = "https://humania-942a7-default-rtdb.asia-southeast1.firebasedatabase.app/";
    private static DatabaseReference mDatabase = FirebaseDatabase.getInstance(DATABASE_URL).getReference();
    private static FirebaseStorage mStorage = FirebaseStorage.getInstance();
    private static int mDonationCount = 0;
    private static String mCurrentListenerUserId = null;

    public interface OnUploadCompleteListener {
        void onComplete(boolean success, String result);
    }

    /**
     * Alternative way: Converts image to Base64 string to store in Realtime Database.
     * Includes a slight resize to ensure it stays within the Database's 10MB limit.
     */
    public static String encodeImageToBase64(String localPath) {
        if (localPath == null || localPath.isEmpty()) return null;
        
        try {
            Bitmap bitmap = BitmapFactory.decodeFile(localPath);
            if (bitmap == null) return null;

            // Resize if too large (e.g., max width 800px)
            int maxWidth = 800;
            if (bitmap.getWidth() > maxWidth) {
                int newHeight = (int) (bitmap.getHeight() * ((float) maxWidth / bitmap.getWidth()));
                bitmap = Bitmap.createScaledBitmap(bitmap, maxWidth, newHeight, true);
            }

            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            bitmap.compress(Bitmap.CompressFormat.JPEG, 70, outputStream);
            byte[] byteArray = outputStream.toByteArray();
            return Base64.encodeToString(byteArray, Base64.DEFAULT);
        } catch (Exception e) {
            e.printStackTrace();
            return null;
        }
    }

    public static void uploadDonationImage(String localPath, OnUploadCompleteListener listener) {
        if (localPath == null || localPath.isEmpty()) {
            listener.onComplete(true, null);
            return;
        }

        Uri file = Uri.fromFile(new File(localPath));
        StorageReference storageRef = mStorage.getReference().child("donations/" + file.getLastPathSegment());
        UploadTask uploadTask = storageRef.putFile(file);

        uploadTask.continueWithTask(task -> {
            if (!task.isSuccessful()) {
                throw task.getException();
            }
            return storageRef.getDownloadUrl();
        }).addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                Uri downloadUri = task.getResult();
                listener.onComplete(true, downloadUri.toString());
            } else {
                listener.onComplete(false, task.getException().getMessage());
            }
        });
    }

    /**
     * Gets the current user's total donation count.
     * This method maintains a listener to the Firebase database to keep the count updated.
     * @return The number of donations made by the current user.
     */
    public static int getDonationCount() {
        String userId = FirebaseAuth.getInstance().getCurrentUser() != null ?
                FirebaseAuth.getInstance().getCurrentUser().getUid() : null;

        if (userId != null && !userId.equals(mCurrentListenerUserId)) {
            mCurrentListenerUserId = userId;
            mDonationCount = 0;
            mDatabase.child("users").child(userId).child("totalDonations")
                    .addValueEventListener(new ValueEventListener() {
                        @Override
                        public void onDataChange(@NonNull DataSnapshot snapshot) {
                            Integer count = snapshot.getValue(Integer.class);
                            if (count != null) {
                                mDonationCount = count;
                            }
                        }

                        @Override
                        public void onCancelled(@NonNull DatabaseError error) {
                        }
                    });
        }
        return mDonationCount;
    }

    public static void addDonation(Donation donation, OnDonationCompleteListener listener) {
        String donationId = mDatabase.child("donations").push().getKey();
        if (donationId == null) return;

        donation.setDonationId(donationId); // Set the ID in the object before saving

        mDatabase.child("donations").child(donationId).setValue(donation)
                .addOnCompleteListener(task -> {
                    if (task.isSuccessful()) {
                        // Increment user's personal donation count
                        String userId = FirebaseAuth.getInstance().getCurrentUser().getUid();
                        mDatabase.child("users").child(userId).child("totalDonations")
                                .setValue(ServerValue.increment(1));
                        
                        // Increment global donation count
                        mDatabase.child("globalStats").child("totalDonations")
                                .setValue(ServerValue.increment(1));

                        if (listener != null) listener.onComplete(true, null);
                    } else {
                        if (listener != null) listener.onComplete(false, task.getException().getMessage());
                    }
                });
    }

    public interface OnDonationCompleteListener {
        void onComplete(boolean success, String message);
    }
}
