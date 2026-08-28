package com.example.humania;

import android.net.Uri;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import android.util.Base64;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import java.io.File;
import java.util.List;

public class MyDonationsAdapter extends RecyclerView.Adapter<MyDonationsAdapter.ViewHolder> {

    private List<Donation> donations;

    public MyDonationsAdapter(List<Donation> donations) {
        this.donations = donations;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_donation_card, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        Donation donation = donations.get(position);
        holder.tvTitle.setText(donation.getTitle());
        holder.tvDescription.setText(donation.getDescription());
        holder.tvMeta.setText("By " + donation.getDonorName() + " • " + (donation.getTimestamp() != null ? donation.getTimestamp() : "Recently"));
        holder.tvCategory.setText(getEmojiForCategory(donation.getCategory()) + " " + donation.getCategory());
        
        // Handle Photo display (Supports Base64 and Path/URL)
        String path = donation.getPhotoPath();
        if (path != null && !path.isEmpty()) {
            holder.ivDonationImage.setVisibility(View.VISIBLE);
            holder.tvEmoji.setVisibility(View.GONE);
            
            if (path.startsWith("http") || path.startsWith("/")) {
                Glide.with(holder.itemView.getContext())
                        .load(path)
                        .placeholder(R.drawable.bg_gradient_card_image)
                        .into(holder.ivDonationImage);
            } else {
                // Base64
                try {
                    byte[] imageBytes = Base64.decode(path, Base64.DEFAULT);
                    Glide.with(holder.itemView.getContext())
                            .load(imageBytes)
                            .placeholder(R.drawable.bg_gradient_card_image)
                            .into(holder.ivDonationImage);
                } catch (Exception e) {
                    holder.ivDonationImage.setVisibility(View.GONE);
                    holder.tvEmoji.setVisibility(View.VISIBLE);
                }
            }
        } else {
            holder.ivDonationImage.setVisibility(View.GONE);
            holder.tvEmoji.setVisibility(View.VISIBLE);
            holder.tvEmoji.setText(getEmojiForCategory(donation.getCategory()));
        }
        
        // Expiry Status
        if (DateUtils.isExpired(donation.getExpiryDate())) {
            holder.tvUrgency.setText("EXPIRED");
            holder.tvUrgency.setBackgroundResource(R.drawable.bg_tag_orange);
        } else {
            holder.tvUrgency.setText(donation.getQuantity() + " items");
        }
        
        holder.tvDistance.setText(donation.getLocation());
    }

    @Override
    public int getItemCount() {
        return donations.size();
    }

    private String getEmojiForCategory(String category) {
        if (category == null) return "🎁";
        switch (category) {
            case "Food": return "🥦";
            case "Clothes": return "👕";
            case "Items": return "📦";
            case "Toys": return "🧸";
            case "Electronics": return "📱";
            case "Tools": return "🛠️";
            default: return "🎁";
        }
    }

    public static class ViewHolder extends RecyclerView.ViewHolder {
        TextView tvTitle, tvDescription, tvMeta, tvCategory, tvUrgency, tvDistance, tvEmoji;
        ImageView ivDonationImage;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            tvTitle = itemView.findViewById(R.id.tvDonationTitle);
            tvDescription = itemView.findViewById(R.id.tvDonationDescription);
            tvMeta = itemView.findViewById(R.id.tvDonationMeta);
            tvCategory = itemView.findViewById(R.id.tvTagCategory);
            tvUrgency = itemView.findViewById(R.id.tvTagUrgency);
            tvDistance = itemView.findViewById(R.id.tvDistance);
            tvEmoji = itemView.findViewById(R.id.tvDonationEmoji);
            ivDonationImage = itemView.findViewById(R.id.ivDonationImage);
        }
    }
}
