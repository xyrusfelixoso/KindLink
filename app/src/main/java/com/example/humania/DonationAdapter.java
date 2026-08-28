package com.example.humania;

import android.content.Context;
import android.content.Intent;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageButton;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import android.util.Base64;
import com.bumptech.glide.Glide;
import java.util.List;

public class DonationAdapter extends RecyclerView.Adapter<DonationAdapter.DonationViewHolder> {

    private List<Donation> donationList;
    private OnItemClickListener listener;

    public interface OnItemClickListener {
        void onItemClick(Donation donation);
    }

    public DonationAdapter(List<Donation> donationList, OnItemClickListener listener) {
        this.donationList = donationList;
        this.listener = listener;
    }

    @NonNull
    @Override
    public DonationViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_donation_card, parent, false);
        return new DonationViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull DonationViewHolder holder, int position) {
        Donation donation = donationList.get(position);
        holder.bind(donation, listener);
    }

    @Override
    public int getItemCount() {
        return donationList.size();
    }

    static class DonationViewHolder extends RecyclerView.ViewHolder {
        TextView tvTitle, tvDescription, tvMeta, tvTagCategory, tvTagUrgency, tvDistance, tvEmoji, tvDonor;
        ImageView ivImage;

        public DonationViewHolder(@NonNull View itemView) {
            super(itemView);
            tvTitle = itemView.findViewById(R.id.tvDonationTitle);
            tvDescription = itemView.findViewById(R.id.tvDonationDescription);
            tvMeta = itemView.findViewById(R.id.tvDonationMeta);
            tvTagCategory = itemView.findViewById(R.id.tvTagCategory);
            tvTagUrgency = itemView.findViewById(R.id.tvTagUrgency);
            tvDistance = itemView.findViewById(R.id.tvDistance);
            tvEmoji = itemView.findViewById(R.id.tvDonationEmoji);
            tvDonor = itemView.findViewById(R.id.tvDonationDonor);
            ivImage = itemView.findViewById(R.id.ivDonationImage);
        }

        public void bind(Donation donation, OnItemClickListener listener) {
            Context context = itemView.getContext();
            tvTitle.setText(donation.getTitle());
            tvDescription.setText(donation.getDescription());
            tvMeta.setText("Posted: " + (donation.getTimestamp() != null ? donation.getTimestamp() : "Just now"));
            tvTagCategory.setText(donation.getCategory());
            tvDistance.setText(donation.getLocation());
            tvDonor.setText("By: " + (donation.getDonorName() != null ? donation.getDonorName() : "Anonymous"));

            // Load Image with Glide (Supports URL, Local Path, and Base64)
            if (donation.getPhotoPath() != null && !donation.getPhotoPath().isEmpty()) {
                ivImage.setVisibility(View.VISIBLE);
                tvEmoji.setVisibility(View.GONE);
                
                String path = donation.getPhotoPath();
                if (path.startsWith("http") || path.startsWith("/")) {
                    Glide.with(context)
                            .load(path)
                            .placeholder(R.drawable.bg_gradient_card_image)
                            .into(ivImage);
                } else {
                    // Assume Base64
                    try {
                        byte[] imageBytes = Base64.decode(path, Base64.DEFAULT);
                        Glide.with(context)
                                .load(imageBytes)
                                .placeholder(R.drawable.bg_gradient_card_image)
                                .into(ivImage);
                    } catch (Exception e) {
                        ivImage.setVisibility(View.GONE);
                        tvEmoji.setVisibility(View.VISIBLE);
                    }
                }
            } else {
                ivImage.setVisibility(View.GONE);
                tvEmoji.setVisibility(View.VISIBLE);
                // Simple emoji mapping based on category
                if (donation.getCategory() != null) {
                    String cat = donation.getCategory().toLowerCase();
                    if (cat.contains("food")) tvEmoji.setText("🥦");
                    else if (cat.contains("clothes")) tvEmoji.setText("👕");
                    else if (cat.contains("toys")) tvEmoji.setText("🧸");
                    else if (cat.contains("items")) tvEmoji.setText("📦");
                    else if (cat.contains("electronics")) tvEmoji.setText("📱");
                    else if (cat.contains("tools")) tvEmoji.setText("🛠️");
                    else tvEmoji.setText("🎁");
                }
            }

            // Expiry Status Tag
            if (DateUtils.isExpired(donation.getExpiryDate())) {
                tvTagUrgency.setText("EXPIRED");
                tvTagUrgency.setBackgroundResource(R.drawable.bg_tag_orange);
            } else {
                tvTagUrgency.setText("Active");
                tvTagUrgency.setBackgroundResource(R.drawable.bg_tag_green);
            }

            itemView.setOnClickListener(v -> listener.onItemClick(donation));
        }
    }
}
