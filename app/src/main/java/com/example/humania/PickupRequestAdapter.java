package com.example.humania;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.recyclerview.widget.RecyclerView;
import com.bumptech.glide.Glide;
import java.util.List;

public class PickupRequestAdapter extends RecyclerView.Adapter<PickupRequestAdapter.ViewHolder> {

    private List<PickupRequest> requestList;
    private boolean isDonorView;
    private OnRequestActionListener listener;

    public interface OnRequestActionListener {
        void onApprove(PickupRequest request);
        void onReject(PickupRequest request);
        void onConfirmPickup(PickupRequest request);
        void onDeleteRequest(PickupRequest request);
    }

    public PickupRequestAdapter(List<PickupRequest> requestList, boolean isDonorView, OnRequestActionListener listener) {
        this.requestList = requestList;
        this.isDonorView = isDonorView;
        this.listener = listener;
    }

    @NonNull
    @Override
    public ViewHolder onCreateViewHolder(@NonNull ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext()).inflate(R.layout.item_pickup_request, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(@NonNull ViewHolder holder, int position) {
        PickupRequest request = requestList.get(position);
        holder.tvItemName.setText(request.getItemName());
        holder.tvRequesterName.setText("Requested by: " + request.getRequesterName());
        holder.tvRequestDate.setText("Date: " + request.getRequestDate());
        holder.tvStatus.setText("Status: " + request.getStatus());
        holder.tvValidationStatus.setText(request.getValidationStatus());

        if (request.getItemPhotoPath() != null && !request.getItemPhotoPath().isEmpty()) {
            Glide.with(holder.itemView.getContext())
                    .load(request.getItemPhotoPath())
                    .placeholder(R.drawable.bg_gradient_card_image)
                    .into(holder.ivItemImage);
        }

        if (isDonorView) {
            if ("PENDING".equals(request.getStatus())) {
                holder.layoutActions.setVisibility(View.VISIBLE);
                holder.btnApprove.setVisibility(View.VISIBLE);
                holder.btnReject.setVisibility(View.VISIBLE);
                holder.btnApprove.setText("Approve");
                holder.btnApprove.setOnClickListener(v -> listener.onApprove(request));
                holder.btnReject.setOnClickListener(v -> listener.onReject(request));
            } else if ("APPROVED".equals(request.getStatus()) || "COMPLETED".equals(request.getStatus()) || 
                    "REJECTED".equals(request.getStatus()) || "CANCELED".equals(request.getStatus()) || "CANCELLED".equals(request.getStatus())) {
                holder.layoutActions.setVisibility(View.VISIBLE);
                holder.btnApprove.setVisibility(View.VISIBLE);
                holder.btnApprove.setText("Remove Listing");
                holder.btnReject.setVisibility(View.GONE);
                holder.btnApprove.setOnClickListener(v -> {
                    if (listener != null) listener.onDeleteRequest(request);
                });
            } else {
                holder.layoutActions.setVisibility(View.GONE);
            }
        } else {
            // Requester View
            if ("APPROVED".equals(request.getStatus())) {
                holder.layoutActions.setVisibility(View.VISIBLE);
                holder.btnApprove.setVisibility(View.VISIBLE);
                holder.btnApprove.setText("I picked this up");
                holder.btnReject.setVisibility(View.GONE);
                holder.btnApprove.setOnClickListener(v -> {
                    if (listener != null) listener.onConfirmPickup(request);
                });
            } else if ("PENDING".equals(request.getStatus())) {
                holder.layoutActions.setVisibility(View.VISIBLE);
                holder.btnApprove.setVisibility(View.VISIBLE);
                holder.btnApprove.setText("Cancel Request");
                holder.btnReject.setVisibility(View.GONE);
                holder.btnApprove.setOnClickListener(v -> {
                    if (listener != null) listener.onDeleteRequest(request);
                });
            } else if ("COMPLETED".equals(request.getStatus()) || "REJECTED".equals(request.getStatus()) || 
                    "CANCELED".equals(request.getStatus()) || "CANCELLED".equals(request.getStatus())) {
                holder.layoutActions.setVisibility(View.VISIBLE);
                holder.btnApprove.setVisibility(View.VISIBLE);
                holder.btnApprove.setText("Remove Request");
                holder.btnReject.setVisibility(View.GONE);
                holder.btnApprove.setOnClickListener(v -> {
                    if (listener != null) listener.onDeleteRequest(request);
                });
            } else {
                holder.layoutActions.setVisibility(View.GONE);
            }
        }
    }

    @Override
    public int getItemCount() {
        return requestList.size();
    }

    public static class ViewHolder extends RecyclerView.ViewHolder {
        ImageView ivItemImage;
        TextView tvItemName, tvRequesterName, tvRequestDate, tvStatus, tvValidationStatus;
        LinearLayout layoutActions;
        Button btnApprove, btnReject;

        public ViewHolder(@NonNull View itemView) {
            super(itemView);
            ivItemImage = itemView.findViewById(R.id.ivItemImage);
            tvItemName = itemView.findViewById(R.id.tvItemName);
            tvRequesterName = itemView.findViewById(R.id.tvRequesterName);
            tvRequestDate = itemView.findViewById(R.id.tvRequestDate);
            tvStatus = itemView.findViewById(R.id.tvStatus);
            tvValidationStatus = itemView.findViewById(R.id.tvValidationStatus);
            layoutActions = itemView.findViewById(R.id.layoutActions);
            btnApprove = itemView.findViewById(R.id.btnApprove);
            btnReject = itemView.findViewById(R.id.btnReject);
        }
    }
}
