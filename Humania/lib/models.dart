part of 'main.dart';

bool isOwnDonation(
  DonationItem item,
  String? currentUid,
  String? currentUserName,
) {
  return (item.ownerUid != null && item.ownerUid == currentUid) ||
      (item.ownerUid == null &&
          currentUserName != null &&
          item.donor.trim().toLowerCase() ==
              currentUserName.trim().toLowerCase());
}

class UserAccount {
  UserAccount({
    required this.name,
    required this.username,
    required this.email,
    required this.password,
    this.profileAvatarIndex = 0,
    this.organizationName,
    this.organizationDetails,
    this.isAdmin = false,
  });

  String name;
  String username;
  String email;
  String password;
  Uint8List? profileImageBytes;
  int profileAvatarIndex;
  String? organizationName;
  String? organizationDetails;
  bool isAdmin;
}

class DonationItem {
  const DonationItem({
    required this.name,
    required this.details,
    required this.location,
    required this.donor,
    required this.icon,
    this.postedAt,
    this.imageBytes,
    this.locationPoint,
    this.id,
    this.ownerUid,
    this.imageUrl,
    this.imageType,
    this.imageName,
    this.organizationName,
    this.organizationDetails,
    this.availability,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.ratingTotal = 0,
  });

  final String name;
  final String details;
  final String location;
  final String donor;
  final IconData icon;
  final DateTime? postedAt;
  final Uint8List? imageBytes;
  final LatLng? locationPoint;
  final String? id;
  final String? ownerUid;
  final String? imageUrl;
  final String? imageType;
  final String? imageName;
  final String? organizationName;
  final String? organizationDetails;
  final String? availability;
  final double ratingAverage;
  final int ratingCount;
  final int ratingTotal;
}

class DonationReview {
  const DonationReview({required this.item, required this.stars, this.review});

  final DonationItem item;
  final int stars;
  final String? review;
}

final database = FirebaseDatabase.instanceFor(
  app: Firebase.app(),
  databaseURL: firebaseDatabaseUrl,
);

Map<String, dynamic> donationData(DonationItem item) {
  return {
    'name': item.name,
    'details': item.details,
    'location': item.location,
    'donor': item.donor,
    'ownerUid':
        item.ownerUid ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid,
    'postedAt': item.postedAt?.toIso8601String(),
    'latitude': item.locationPoint?.latitude,
    'longitude': item.locationPoint?.longitude,
    'picture': item.imageBytes == null ? null : Blob(item.imageBytes!),
    'pictureType': item.imageType,
    'pictureName': item.imageName,
    // Kept for donations created before pictures moved from Storage to Firestore.
    'imageUrl': item.imageUrl,
    'organizationName': item.organizationName,
    'organizationDetails': item.organizationDetails,
    'availability': item.availability,
    'ratingAverage': item.ratingAverage,
    'ratingCount': item.ratingCount,
    'ratingTotal': item.ratingTotal,
  };
}

DonationItem donationFromData(String id, Map<Object?, Object?> data) {
  final latitude = (data['latitude'] as num?)?.toDouble();
  final longitude = (data['longitude'] as num?)?.toDouble();
  final picture = data['picture'];
  return DonationItem(
    id: id,
    name: data['name'] as String? ?? 'Donation',
    details: data['details'] as String? ?? '',
    location: data['location'] as String? ?? 'Pinned location',
    donor: data['donor'] as String? ?? 'Community donor',
    icon: Icons.volunteer_activism_outlined,
    ownerUid: data['ownerUid'] as String?,
    postedAt: DateTime.tryParse(data['postedAt'] as String? ?? ''),
    imageUrl: data['imageUrl'] as String?,
    imageBytes: picture is Blob ? picture.bytes : null,
    imageType: data['pictureType'] as String?,
    imageName: data['pictureName'] as String?,
    organizationName: data['organizationName'] as String?,
    organizationDetails: data['organizationDetails'] as String?,
    availability: data['availability'] as String?,
    ratingAverage: (data['ratingAverage'] as num?)?.toDouble() ?? 0,
    ratingCount: (data['ratingCount'] as num?)?.toInt() ?? 0,
    ratingTotal: (data['ratingTotal'] as num?)?.toInt() ?? 0,
    locationPoint: latitude != null && longitude != null
        ? LatLng(latitude, longitude)
        : null,
  );
}

bool canReviewDonation(
  DonationItem item,
  String? currentUid, [
  String? currentUserName,
]) {
  if (item.id == null || currentUid == null) return false;
  if (item.ownerUid != null) return item.ownerUid != currentUid;
  return currentUserName != null &&
      item.donor.trim().toLowerCase() != currentUserName.trim().toLowerCase();
}
