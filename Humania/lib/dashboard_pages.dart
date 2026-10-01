part of 'main.dart';

Uint8List _compressDonationPhoto(Uint8List bytes) {
  final decoded = image_codec.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('The selected file is not a valid picture.');
  }
  var working = max(decoded.width, decoded.height) > 1200
      ? image_codec.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1200 : null,
          height: decoded.height > decoded.width ? 1200 : null,
          interpolation: image_codec.Interpolation.average,
        )
      : decoded;
  const targetBytes = 650 * 1024;
  for (final longestSide in [1200, 1000, 800, 640]) {
    if (max(working.width, working.height) > longestSide) {
      working = image_codec.copyResize(
        working,
        width: working.width >= working.height ? longestSide : null,
        height: working.height > working.width ? longestSide : null,
        interpolation: image_codec.Interpolation.average,
      );
    }
    for (final quality in [76, 68, 60, 52, 44]) {
      final encoded = Uint8List.fromList(
        image_codec.encodeJpg(working, quality: quality),
      );
      if (encoded.length <= targetBytes) return encoded;
    }
  }
  throw const FormatException(
    'This picture could not be reduced below 650 KB.',
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.user,
    required this.onSignOut,
    required this.role,
  });

  final UserAccount user;
  final Future<void> Function() onSignOut;
  final String role;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final List<DonationItem> _pickupRequests = [];
  final List<DonationReview> _reviews = [];
  final List<Map<String, dynamic>> _donorRequests = [];
  int _donatedCount = 0;
  int _receivedStarTotal = 0;
  int _receivedReviews = 0;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _donationsSubscription;
  bool _receivedDonationSnapshot = false;
  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  StreamSubscription<firebase_auth.User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPresence();
    _authSubscription = firebase_auth.FirebaseAuth.instance
        .authStateChanges()
        .listen((user) {
          if (user != null) _startPresence();
        });
    _HomeTabState.items.clear();
    try {
      _loadRemoteActivity();
      _donationsSubscription = FirebaseFirestore.instance
          .collection('donations')
          .snapshots()
          .listen((event) => _replaceRemoteDonations(event), onError: (_) {});
    } on Exception {
      // Widget tests and offline previews can run without Firebase initialized.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _connectionSubscription?.cancel();
    _donationsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    // Publish Offline while the Firebase user identity is still available.
    // FirebaseAuthService repeats this write as a final safeguard before it
    // clears the authenticated session.
    await _setPresence(false);
    await widget.onSignOut();
  }

  Future<void> _startPresence() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _connectionSubscription?.cancel();
    final presence = database.ref('presence/$uid');
    await presence.onDisconnect().update({
      'online': false,
      'lastSeen': ServerValue.timestamp,
    });
    _connectionSubscription = database.ref('.info/connected').onValue.listen((
      event,
    ) {
      if (event.snapshot.value == true) _setPresence(true);
    });
  }

  Future<void> _setPresence(bool online) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await database.ref('presence/$uid').update({
        'online': online,
        'name': widget.user.name,
        'username': widget.user.username,
        'lastSeen': ServerValue.timestamp,
        'client': 'memberApp',
      });
    } on Exception {
      // onDisconnect still marks an unexpectedly disconnected member offline.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setPresence(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _setPresence(false);
    }
  }

  void _replaceRemoteDonations(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _receivedDonationSnapshot = true;
    if (snapshot.docs.isEmpty) {
      if (mounted) {
        setState(() => _HomeTabState.items.clear());
      }
      return;
    }
    final remoteItems = snapshot.docs
        .where((doc) => doc.data()['status'] != 'completed')
        .map((doc) => donationFromData(doc.id, doc.data()))
        .toList();
    if (!mounted) return;
    setState(() {
      _HomeTabState.items
        ..clear()
        ..addAll(remoteItems);
    });
  }

  Future<void> _loadRemoteActivity() async {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final profileSnapshot = await database.ref('users/$uid').get();
      if (profileSnapshot.value is Map) {
        final profile = Map<Object?, Object?>.from(
          profileSnapshot.value! as Map,
        );
        _donatedCount = (profile['donatedCount'] as num?)?.toInt() ?? 0;
      }
      final requestsSnapshot = await database.ref('pickup_requests/$uid').get();
      final allRequestsSnapshot = await database.ref('pickup_requests').get();
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('userId', isEqualTo: uid)
          .get();
      final receivedRatingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .where('ownerUid', isEqualTo: uid)
          .get();
      if (!mounted) return;
      if (requestsSnapshot.value is Map) {
        for (final entry in Map<Object?, Object?>.from(
          requestsSnapshot.value! as Map,
        ).entries) {
          if (entry.value is! Map) continue;
          final data = Map<Object?, Object?>.from(entry.value! as Map);
          final donationId = data['donationId'] as String?;
          final ownerUid = data['ownerUid'] as String?;
          if (donationId == null || ownerUid == null || ownerUid == uid) {
            continue;
          }
          final item = _HomeTabState.items.firstWhere(
            (candidate) =>
                candidate.id == donationId || candidate.name == data['name'],
            orElse: () => DonationItem(
              id: donationId,
              name: data['name'] as String? ?? 'Donation',
              details: data['details'] as String? ?? '',
              location: data['location'] as String? ?? 'Pinned location',
              donor: data['donor'] as String? ?? 'Community donor',
              icon: Icons.volunteer_activism_outlined,
              ownerUid: ownerUid,
            ),
          );
          if (!_pickupRequests.contains(item)) _pickupRequests.add(item);
        }
      }
      if (allRequestsSnapshot.value is Map) {
        for (final requester in Map<Object?, Object?>.from(
          allRequestsSnapshot.value! as Map,
        ).entries) {
          if (requester.value is! Map) continue;
          for (final request in Map<Object?, Object?>.from(
            requester.value! as Map,
          ).entries) {
            if (request.value is! Map) continue;
            final data = Map<String, dynamic>.from(
              Map<Object?, Object?>.from(request.value! as Map)
                  .map((k, v) => MapEntry(k.toString(), v)),
            );
            if (data['ownerUid'] == uid && data['status'] != 'rejected') {
              data['requesterUid'] = requester.key.toString();
              data['requestKey'] = request.key.toString();
              _donorRequests.add(data);
            }
          }
        }
      }
      for (final ratingDocument in ratingsSnapshot.docs) {
        final data = ratingDocument.data();
        final item = _pickupRequests.firstWhere(
          (candidate) =>
              candidate.id == data['donationId'] ||
              candidate.name == data['donationName'],
          orElse: () => DonationItem(
            id: data['donationId'] as String?,
            name: data['donationName'] as String? ?? 'Donation',
            details: '',
            location: 'Pinned location',
            donor: data['donor'] as String? ?? 'Community donor',
            icon: Icons.volunteer_activism_outlined,
          ),
        );
        if (!canReviewDonation(item, uid, widget.user.name)) continue;
        if (_reviews.any((review) => review.item.id == item.id)) continue;
        _reviews.add(
          DonationReview(
            item: item,
            stars: (data['rating'] as num?)?.toInt() ?? 0,
            review: data['review'] as String?,
          ),
        );
      }
      _receivedStarTotal = 0;
      _receivedReviews = 0;
      for (final ratingDocument in receivedRatingsSnapshot.docs) {
        _receivedReviews++;
        _receivedStarTotal +=
            (ratingDocument.data()['rating'] as num?)?.toInt() ?? 0;
      }
      setState(() {});
    } on Exception {
      // Firebase may be unavailable while the local app is still usable.
    }
  }

  Future<void> _savePickupRequest(DonationItem item) async {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await database.ref('pickup_requests/$uid').push().set({
        'donationId': item.id,
        'name': item.name,
        'details': item.details,
        'location': item.location,
        'donor': item.donor,
        'ownerUid': item.ownerUid,
        'requesterName':
            firebase_auth.FirebaseAuth.instance.currentUser?.displayName ??
            'Community member',
        'requestedAt': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
    } on Exception {
      // The local request remains visible if the network is unavailable.
    }
  }

  Future<void> _removeDonation(String donationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(donationId)
          .update({'status': 'pickup_requested'});
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pickup saved, but the donation status could not be updated.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _saveReview(DonationReview review) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final itemId = review.item.id;
    if (uid == null || itemId == null) {
      throw Exception('Sign in and select a valid donation before rating.');
    }
    final firestore = FirebaseFirestore.instance;
    final ratingRef = firestore.collection('ratings').doc('${itemId}_$uid');
    final donationRef = firestore.collection('donations').doc(itemId);
    await firestore.runTransaction((transaction) async {
      final oldRatingSnapshot = await transaction.get(ratingRef);
      final donationSnapshot = await transaction.get(donationRef);
      final oldRating = (oldRatingSnapshot.data()?['rating'] as num?)?.toInt();
      final donationData = donationSnapshot.data();
      final oldTotal = (donationData?['ratingTotal'] as num?)?.toInt() ?? 0;
      final oldCount = (donationData?['ratingCount'] as num?)?.toInt() ?? 0;
      final newTotal = oldTotal - (oldRating ?? 0) + review.stars;
      final newCount = oldRating == null ? oldCount + 1 : oldCount;

      transaction.set(ratingRef, {
        'itemId': itemId,
        'userId': uid,
        'ownerUid': review.item.ownerUid,
        'donationName': review.item.name,
        'donor': review.item.donor,
        'rating': review.stars,
        'review': review.review?.trim() ?? '',
        if (!oldRatingSnapshot.exists)
          'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (donationSnapshot.exists) {
        transaction.update(donationRef, {
          'ratingTotal': newTotal,
          'ratingCount': newCount,
          'ratingAverage': newCount == 0 ? 0 : newTotal / newCount,
        });
      }
    });
  }

  Future<String?> _saveDonation(DonationItem item) async {
    try {
      final ref = FirebaseFirestore.instance.collection('donations').doc();
      await ref.set({...donationData(item), 'status': 'available'});
      return null;
    } on FirebaseException catch (error) {
      return error.message ?? 'Firebase rejected the donation.';
    } on Exception catch (error) {
      return error.toString();
    }
  }

  Future<void> _incrementDonatedCount() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final ref = database.ref('users/$uid/donatedCount');
      final result = await ref.runTransaction((value) {
        final count = (value as num?)?.toInt() ?? 0;
        return Transaction.success(count + 1);
      });
      if (result.committed && mounted) {
        setState(() => _donatedCount++);
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation posted, but count failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_receivedDonationSnapshot && _HomeTabState.items.isNotEmpty) {
      _HomeTabState.items.clear();
    }

    void addPickupRequest(DonationItem item) {
      final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (isOwnDonation(item, currentUid, widget.user.name)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You cannot pick up your own item because you are the donor.',
            ),
          ),
        );
        return;
      }
      if (!_pickupRequests.contains(item)) {
        setState(() => _pickupRequests.add(item));
        _savePickupRequest(item);
        setState(() {
          _HomeTabState.items.removeWhere(
            (candidate) => candidate.id == item.id || candidate == item,
          );
        });
        if (item.id != null) {
          _removeDonation(item.id!);
        }
      }
    }

    final pages = [
      _HomeTab(
        user: widget.user,
        role: widget.role,
        onPickup: addPickupRequest,
      ),
      _MapTab(
        items: _HomeTabState.items,
        onBack: () => setState(() => _selectedIndex = 0),
      ),
      _DonationsTab(
        onPickup: addPickupRequest,
        currentUserName: widget.user.name,
        currentUserUid: firebase_auth.FirebaseAuth.instance.currentUser?.uid,
        donorRequests: _donorRequests,
        role: widget.role,
        user: widget.user,
      ),
      _RequestHelpPage(user: widget.user),
      _CampaignHubPage(role: widget.role, user: widget.user),
      _ReferenceProfileTab(
        user: widget.user,
        onSignOut: _signOut,
        pickupRequests: _pickupRequests,
        reviews: _reviews,
        role: widget.role,
        rating: _receivedReviews == 0
            ? '0.0'
            : (_receivedStarTotal / _receivedReviews).toStringAsFixed(1),
        onReview: (review) async {
          final currentUid =
              firebase_auth.FirebaseAuth.instance.currentUser?.uid;
          if (!canReviewDonation(review.item, currentUid, widget.user.name)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'You cannot review your own donation. Feedback is for donors only.',
                ),
              ),
            );
            throw Exception('You cannot rate your own donation.');
          }
          await _saveReview(review);
          if (!mounted) return;
          setState(() {
            _reviews.removeWhere((item) => item.item.id == review.item.id);
            _reviews.add(review);
          });
        },
        donatedCount: _donatedCount,
        onUserChanged: () => setState(() {}),
      ),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[_selectedIndex]),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              tooltip: 'Post a donation',
              onPressed: () async {
                final item = await Navigator.of(context).push<DonationItem>(
                  MaterialPageRoute(
                    builder: (_) => _CreateDonationPage(user: widget.user),
                  ),
                );
                if (item != null) {
                  final localItem = DonationItem(
                    id: 'local-${DateTime.now().microsecondsSinceEpoch}',
                    name: item.name,
                    details: item.details,
                    location: item.location,
                    donor: item.donor,
                    icon: item.icon,
                    postedAt: item.postedAt,
                    imageBytes: item.imageBytes,
                    imageUrl: item.imageUrl,
                    imageType: item.imageType,
                    imageName: item.imageName,
                    ownerUid: item.ownerUid,
                    locationPoint: item.locationPoint,
                    organizationName: item.organizationName,
                    organizationDetails: item.organizationDetails,
                    availability: item.availability,
                    ratingAverage: item.ratingAverage,
                    ratingCount: item.ratingCount,
                    ratingTotal: item.ratingTotal,
                  );
                  setState(() {
                    _HomeTabState.items.insert(0, localItem);
                  });
                  final error = await _saveDonation(item);
                  if (error == null) {
                    await _incrementDonatedCount();
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        error == null
                            ? 'Donation posted successfully.'
                            : 'Saved on this device. Firebase: $error',
                      ),
                    ),
                  );
                }
              },
              backgroundColor: kindLinkOrange,
              foregroundColor: Colors.white,
              elevation: 5,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 32),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: SafeArea(
        top: false,
        child: BottomAppBar(
          height: 64,
          padding: EdgeInsets.zero,
          color: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 12,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _BottomBarItem(
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: _selectedIndex == 0,
                    onTap: () => setState(() => _selectedIndex = 0),
                  ),
                ),
                Expanded(
                  child: _BottomBarItem(
                    icon: Icons.map_outlined,
                    label: 'Map',
                    selected: _selectedIndex == 1,
                    onTap: () => setState(() => _selectedIndex = 1),
                  ),
                ),
                Expanded(
                  child: _BottomBarItem(
                    icon: Icons.front_hand_outlined,
                    label: 'Request',
                    selected: _selectedIndex == 3,
                    onTap: () => setState(() => _selectedIndex = 3),
                  ),
                ),
                Expanded(
                  child: _BottomBarItem(
                    icon: Icons.apartment_outlined,
                    label: 'Orgs',
                    selected: _selectedIndex == 4,
                    onTap: () => setState(() => _selectedIndex = 4),
                  ),
                ),
                Expanded(
                  child: _BottomBarItem(
                    icon: Icons.person_outline,
                    label: 'Profile',
                    selected: _selectedIndex == 5,
                    onTap: () => setState(() => _selectedIndex = 5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kindLinkEmerald : Colors.grey;
    return Semantics(
      button: true,
      selected: selected,
      label: label == 'Orgs' ? 'Organizations' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.user,
    required this.role,
    required this.onPickup,
  });

  final UserAccount user;
  final String role;
  final ValueChanged<DonationItem> onPickup;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String _sortOption = 'Nearby';

  static final items = <DonationItem>[];

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...items];
    if (_sortOption == 'A-Z') {
      sortedItems.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortOption == 'Donor') {
      sortedItems.sort((a, b) => a.donor.compareTo(b.donor));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 104),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: KindLinkLogo(height: 82, width: 230),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kindLinkEmerald, kindLinkPrimaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white24,
                child: Text(
                  widget.user.name.isEmpty
                      ? '?'
                      : widget.user.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good to see you!',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.user.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'You are helping as a ${widget.role}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.waving_hand_outlined, color: Colors.amber),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _HomeSummary(
                value: '${items.length}',
                label: 'Nearby items',
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HomeSummary(
                value:
                    '${items.where((item) {
                      final postedAt = item.postedAt;
                      final now = DateTime.now();
                      return postedAt != null && postedAt.year == now.year && postedAt.month == now.month && postedAt.day == now.day;
                    }).length}',
                label: 'New today',
                icon: Icons.bolt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Available near you',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: kindLinkPrimaryDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Sort items',
              initialValue: _sortOption,
              onSelected: (option) => setState(() => _sortOption = option),
              icon: const Icon(Icons.tune, color: kindLinkEmerald),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'Nearby', child: Text('Nearest first')),
                PopupMenuItem(value: 'A-Z', child: Text('Item name A-Z')),
                PopupMenuItem(value: 'Donor', child: Text('Donor name A-Z')),
              ],
            ),
          ],
        ),
        Text(
          'Sorted by $_sortOption',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...sortedItems.map(
          (item) => _DonationCard(
            item: item,
            onTap: () async {
              final pickedUp = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => _DonationDetailsPage(
                    item: item,
                    currentUserName: widget.user.name,
                  ),
                ),
              );
              if (pickedUp == true) widget.onPickup(item);
            },
          ),
        ),
      ],
    );
  }
}

class _MapTab extends StatefulWidget {
  const _MapTab({required this.items, required this.onBack});

  final List<DonationItem> items;
  final VoidCallback onBack;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  static const defaultLocation = LatLng(6.7497, 125.3572);
  final MapController _mapController = MapController();
  LatLng _userLocation = defaultLocation;
  bool _locationLoaded = false;
  DonationItem? _nearestItem;
  QueryDocumentSnapshot<Map<String, dynamic>>? _selectedHelpRequest;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _helpRequests = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _dropOffPoints = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _helpRequestsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _dropOffPointsSubscription;
  static const itemLocations = [
    LatLng(14.6042, 120.9822),
    LatLng(14.5956, 120.9912),
    LatLng(14.6074, 120.9970),
  ];

  LatLng _locationForIndex(int index) {
    final item = widget.items[index];
    return item.locationPoint ??
        itemLocations[index.clamp(0, itemLocations.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _helpRequestsSubscription = FirebaseFirestore.instance
        .collection('helpRequests')
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(
              () => _helpRequests = snapshot.docs.where((doc) {
                final status = _requestStatus(doc.data());
                return status == 'Approved' || status == 'Fulfilled';
              }).toList(),
            );
          }
        });
    _dropOffPointsSubscription = FirebaseFirestore.instance
        .collection('dropOffPoints')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snapshot) {
          if (mounted) setState(() => _dropOffPoints = snapshot.docs);
        });
  }

  @override
  void dispose() {
    _helpRequestsSubscription?.cancel();
    _dropOffPointsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _locationLoaded = true;
      });
      _mapController.move(_userLocation, 14);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load your location.')),
        );
      }
    }
  }

  void _suggestNearest() {
    if (widget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No donations are available yet.')),
      );
      return;
    }
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < widget.items.length; index++) {
      final distance = const Distance().as(
        LengthUnit.Meter,
        _userLocation,
        _locationForIndex(index),
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    final nearest = widget.items[nearestIndex];
    setState(() => _nearestItem = nearest);
    _mapController.move(_locationForIndex(nearestIndex), 15);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Nearest item: ${nearest.name}')));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(initialCenter: _userLocation, initialZoom: 13),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.humania',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _userLocation,
                  width: 44,
                  height: 44,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.blue,
                    size: 34,
                  ),
                ),
                ...List.generate(widget.items.length, (index) {
                  return Marker(
                    point: _locationForIndex(index),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _nearestItem = widget.items[index]),
                      child: const Icon(
                        Icons.location_on,
                        color: kindLinkWarning,
                        size: 42,
                      ),
                    ),
                  );
                }),
                ..._helpRequests
                    .where((doc) {
                      final data = doc.data();
                      return data['latitude'] is num &&
                          data['longitude'] is num;
                    })
                    .map((doc) {
                      final data = doc.data();
                      final fulfilled = _requestStatus(data) == 'Fulfilled';
                      return Marker(
                        point: LatLng(
                          (data['latitude'] as num).toDouble(),
                          (data['longitude'] as num).toDouble(),
                        ),
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _selectedHelpRequest = doc;
                            _nearestItem = null;
                          }),
                          child: Icon(
                            fulfilled ? Icons.check_circle : Icons.location_on,
                            color: fulfilled ? Colors.green : Colors.red,
                            size: 44,
                          ),
                        ),
                      );
                    }),
                ..._dropOffPoints.map((doc) {
                  final data = doc.data();
                  return Marker(
                    point: LatLng(
                      (data['latitude'] as num).toDouble(),
                      (data['longitude'] as num).toDouble(),
                    ),
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: '${data['name']}\n${data['operatingHours']}',
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 43,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: IconButton(
                    tooltip: 'Back to home',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                const Spacer(),
                if (_locationLoaded)
                  const Chip(
                    avatar: Icon(Icons.gps_fixed, size: 18),
                    label: Text('Live location'),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 24,
          child: Column(
            children: [
              if (_nearestItem != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.near_me, color: Colors.green),
                    title: Text(_nearestItem!.name),
                    subtitle: Text(_nearestItem!.location),
                  ),
                ),
              if (_selectedHelpRequest != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedHelpRequest!.data()['title'] ?? 'Needs help',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          _selectedHelpRequest!.data()['neededItems'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'By ${_selectedHelpRequest!.data()['requesterName'] ?? 'Community member'}'
                          '${_selectedHelpRequest!.data()['requesterUsername'] == null ? '' : ' (@${_selectedHelpRequest!.data()['requesterUsername']})'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => _HelpRequestDetailsPage(
                                  document: _selectedHelpRequest!,
                                ),
                              ),
                            ),
                            child: const Text('View needs'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: const [
                      Text('🔴 Needs help'),
                      Text('🟢 Donation center'),
                      Text('🟡 Donation available'),
                      Text('✅ Fulfilled'),
                    ],
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: _suggestNearest,
                icon: const Icon(Icons.near_me),
                label: const Text('Suggest nearest item'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: kindLinkEmerald,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeSummary extends StatelessWidget {
  const _HomeSummary({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: kindLinkCream,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: kindLinkEmerald),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: kindLinkPrimaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kindLinkSecondaryText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationsTab extends StatefulWidget {
  const _DonationsTab({
    required this.onPickup,
    required this.currentUserName,
    this.currentUserUid,
    required this.donorRequests,
    required this.role,
    required this.user,
  });

  final ValueChanged<DonationItem> onPickup;
  final String currentUserName;
  final String? currentUserUid;
  final List<Map<String, dynamic>> donorRequests;
  final String role;
  final UserAccount user;

  @override
  State<_DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<_DonationsTab> {
  static const _defaultLocation = LatLng(6.7497, 125.3572);
  static const _itemLocations = [
    LatLng(14.6042, 120.9822),
    LatLng(14.5956, 120.9912),
    LatLng(14.6074, 120.9970),
  ];

  LatLng _userLocation = _defaultLocation;
  static const _nameSort = 'Name based sorting';
  static const _itemNameSort = 'Item name';
  static const _nearestSort = 'Nearest location';
  String _sortOption = _itemNameSort;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update nearby donations.')),
        );
      }
    }
  }

  List<DonationItem> _sortedItems() {
    final sorted = [..._HomeTabState.items];
    if (_sortOption == _nameSort) {
      sorted.sort((a, b) => a.donor.compareTo(b.donor));
    } else if (_sortOption == _itemNameSort) {
      sorted.sort((a, b) => a.name.compareTo(b.name));
    } else {
      sorted.sort((a, b) {
        final aIndex = _HomeTabState.items.indexOf(a);
        final bIndex = _HomeTabState.items.indexOf(b);
        final aPoint =
            a.locationPoint ??
            _itemLocations[aIndex.clamp(0, _itemLocations.length - 1)];
        final bPoint =
            b.locationPoint ??
            _itemLocations[bIndex.clamp(0, _itemLocations.length - 1)];
        final aDistance = const Distance().as(
          LengthUnit.Meter,
          _userLocation,
          aPoint,
        );
        final bDistance = const Distance().as(
          LengthUnit.Meter,
          _userLocation,
          bPoint,
        );
        return aDistance.compareTo(bDistance);
      });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'Organization' || widget.role == 'Donor') {
      return _CampaignHubPage(role: widget.role, user: widget.user);
    }
    final items = _sortedItems();
    final ownItems = items
        .where(
          (item) => isOwnDonation(
            item,
            widget.currentUserUid,
            widget.currentUserName,
          ),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Donations',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort donations',
            initialValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            icon: const Icon(Icons.tune),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _nameSort, child: Text(_nameSort)),
              PopupMenuItem(value: _itemNameSort, child: Text(_itemNameSort)),
              PopupMenuItem(value: _nearestSort, child: Text(_nearestSort)),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'All donations',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: kindLinkPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Discover items shared by generous people in your community.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Chip(
            avatar: const Icon(Icons.sort, size: 18),
            label: Text('Sorted by $_sortOption'),
          ),
          const SizedBox(height: 8),
          if (ownItems.isNotEmpty) ...[
            const Text(
              'My donations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ownItems.map(
              (item) => _DonorDonationCard(
                item: item,
                requests: widget.donorRequests,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Community donations',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
          if (items.isEmpty)
            const _EmptyDonations()
          else
            ...items.map(
              (item) => _DonationCard(
                item: item,
                onTap: () async {
                  final pickedUp = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => _DonationDetailsPage(
                        item: item,
                        currentUserName: widget.currentUserName,
                      ),
                    ),
                  );
                  if (pickedUp == true) widget.onPickup(item);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.item, this.onTap});

  final DonationItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        isThreeLine: true,
        contentPadding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: kindLinkCream,
          backgroundImage: item.imageBytes != null
              ? MemoryImage(item.imageBytes!)
              : item.imageUrl != null
              ? NetworkImage(item.imageUrl!)
              : null,
          child: item.imageBytes == null && item.imageUrl == null
              ? Icon(item.icon, color: kindLinkEmerald, size: 28)
              : null,
        ),
        title: Text(
          item.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: kindLinkPrimaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.details),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 15),
                  const SizedBox(width: 3),
                  Expanded(child: Text(item.location)),
                ],
              ),
              if (item.postedAt != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 15),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Posted ${formatPostedDate(item.postedAt!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 15),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      'Donated by ${item.donor}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.organizationName != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.apartment_outlined, size: 15),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text('Organization: ${item.organizationName}'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _DonorDonationCard extends StatelessWidget {
  const _DonorDonationCard({required this.item, required this.requests});
  final DonationItem item;
  final List<Map<String, dynamic>> requests;

  Future<void> _setRequest(
    BuildContext context,
    Map<String, dynamic> request,
    String status,
  ) async {
    final requester = request['requesterUid'];
    final key = request['requestKey'];
    if (requester == null || key == null) return;
    await database.ref('pickup_requests/$requester/$key/status').set(status);
    if (status == 'approved' && item.id != null) {
      await FirebaseFirestore.instance
          .collection('donations')
          .doc(item.id)
          .update({'status': 'reserved'});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Request $status.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemRequests = requests
        .where((r) => r['donationId'] == item.id)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          _DonationCard(item: item),
          if (item.availability != null && item.availability!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Pickup details'),
              subtitle: Text(item.availability!),
            ),
          ...itemRequests.map(
            (request) => ListTile(
              leading: const Icon(Icons.person_pin_circle_outlined),
              title: Text(
                '${request['requesterName'] ?? 'A neighbor'} requested pickup',
              ),
              subtitle: Text(
                (request['status'] ?? 'pending').toString().toUpperCase(),
              ),
              trailing: (request['status'] ?? 'pending') == 'pending'
                  ? Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () =>
                              _setRequest(context, request, 'approved'),
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () =>
                              _setRequest(context, request, 'rejected'),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          if (item.id != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('donations')
                      .doc(item.id)
                      .update({'status': 'completed'});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Donation marked completed.'),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.task_alt),
                label: const Text('Mark completed'),
              ),
            ),
        ],
      ),
    );
  }
}

class _DonationLocationPicker extends StatefulWidget {
  const _DonationLocationPicker({
    this.title = 'Pick item location',
    this.instruction = 'Tap anywhere on the map to place the donation pin.',
  });

  final String title;
  final String instruction;

  @override
  State<_DonationLocationPicker> createState() =>
      _DonationLocationPickerState();
}

class _DonationLocationPickerState extends State<_DonationLocationPicker> {
  static const _defaultLocation = LatLng(6.7497, 125.3572);
  final _mapController = MapController();
  LatLng _selectedLocation = _defaultLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedLocation),
            child: const Text('Use location'),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 13,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.humania',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 52,
                    height: 52,
                    child: const Icon(
                      Icons.location_on,
                      color: kindLinkUrgent,
                      size: 46,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      color: kindLinkEmerald,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.instruction)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonationImageFallback extends StatelessWidget {
  const _DonationImageFallback({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => Container(
    height: 240,
    color: kindLinkCream,
    alignment: Alignment.center,
    child: const Icon(
      Icons.image_not_supported_outlined,
      size: 72,
      color: kindLinkEmerald,
    ),
  );
}

class _DonationDetailsPage extends StatelessWidget {
  const _DonationDetailsPage({required this.item, this.currentUserName});

  final DonationItem item;
  final String? currentUserName;

  @override
  Widget build(BuildContext context) {
    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final isOwner = isOwnDonation(item, currentUid, currentUserName);
    return Scaffold(
      appBar: AppBar(title: const Text('Donation details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          if (item.imageBytes != null || item.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: item.imageBytes != null
                  ? Image.memory(
                      item.imageBytes!,
                      height: 240,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      item.imageUrl!,
                      height: 240,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _DonationImageFallback(error: error.toString()),
                    ),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: kindLinkCream,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.image_outlined,
                size: 72,
                color: kindLinkEmerald,
              ),
            ),
          const SizedBox(height: 22),
          Text(
            item.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: kindLinkPrimaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(item.details, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                item.ratingCount == 0
                    ? 'No ratings yet'
                    : '${item.ratingAverage.toStringAsFixed(1)} (${item.ratingCount} ratings)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.location_on_outlined, text: item.location),
          _DetailRow(
            icon: Icons.person_outline,
            text: 'Donated by ${item.donor}',
          ),
          if (item.postedAt != null)
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              text: 'Posted ${formatPostedDate(item.postedAt!)}',
            ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () {
              if (isOwner) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'You cannot pick up your own item because you are the donor.',
                    ),
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            icon: Icon(
              isOwner ? Icons.lock_outline : Icons.pan_tool_alt_outlined,
            ),
            label: Text(isOwner ? 'Your donation' : 'Request pickup'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: kindLinkEmerald,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: kindLinkEmerald),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyDonations extends StatelessWidget {
  const _EmptyDonations();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffdce9e1)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.volunteer_activism_outlined,
            size: 52,
            color: kindLinkEmerald,
          ),
          SizedBox(height: 12),
          Text(
            'No donations yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the plus button to share an item with your community.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

String formatPostedDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _CreateDonationPage extends StatefulWidget {
  const _CreateDonationPage({required this.user});

  final UserAccount user;

  @override
  State<_CreateDonationPage> createState() => _CreateDonationPageState();
}

class _CreateDonationPageState extends State<_CreateDonationPage> {
  static const _defaultLocation = LatLng(6.7497, 125.3572);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _detailsController = TextEditingController();
  final _locationController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _imageName;
  LatLng? _locationPoint;
  bool _pinningLocation = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _locationPoint = _defaultLocation;
    _locationController.text = 'Digos City, Davao del Sur';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _locationController.dispose();
    _availabilityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 72,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (image == null) return;
      final originalBytes = await image.readAsBytes();
      final bytes = await compute(_compressDonationPhoto, originalBytes);
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('Please choose a photo smaller than 10 MB.');
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = '${image.name.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not select image: $error')));
    }
  }

  Future<void> _pinLocation() async {
    setState(() => _pinningLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _locationPoint = LatLng(position.latitude, position.longitude);
        _locationController.text =
            '${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _pinningLocation = false);
    }
  }

  Future<void> _chooseLocation() async {
    final point = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const _DonationLocationPicker()),
    );
    if (point == null || !mounted) return;
    setState(() {
      _locationPoint = point;
      _locationController.text =
          '${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)}';
    });
  }

  Future<void> _postDonation() async {
    if (_posting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_locationPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pin the item location before posting.')),
      );
      return;
    }
    setState(() => _posting = true);
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      if (_imageBytes != null && uid == null) {
        throw Exception('Please sign in before posting a donation photo.');
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        DonationItem(
          name: _nameController.text.trim(),
          details: _detailsController.text.trim(),
          location: _locationController.text.trim(),
          donor: widget.user.name,
          icon: Icons.volunteer_activism_outlined,
          postedAt: DateTime.now(),
          imageBytes: _imageBytes,
          imageType: _imageBytes == null ? null : 'image/jpeg',
          imageName: _imageName,
          ownerUid: uid,
          locationPoint: _locationPoint,
          organizationName: widget.user.organizationName,
          organizationDetails: widget.user.organizationDetails,
          availability: _availabilityController.text.trim(),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post a donation'),
        actions: [
          TextButton(
            onPressed: _posting ? null : _postDonation,
            child: _posting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            GestureDetector(
              onTap: _posting ? null : _pickImage,
              child: Container(
                height: 190,
                decoration: BoxDecoration(
                  color: kindLinkCream,
                  borderRadius: BorderRadius.circular(18),
                  image: _imageBytes == null
                      ? null
                      : DecorationImage(
                          image: MemoryImage(_imageBytes!),
                          fit: BoxFit.cover,
                        ),
                ),
                child: _imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 42),
                          SizedBox(height: 8),
                          Text('Add donation photo'),
                          SizedBox(height: 4),
                          Text(
                            'JPG, PNG or WebP • up to 10 MB',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Positioned(
                            left: 10,
                            bottom: 10,
                            child: Chip(
                              avatar: const Icon(Icons.check_circle, size: 18),
                              label: Text(
                                'Ready - ${(_imageBytes!.length / 1024).round()} KB',
                              ),
                            ),
                          ),
                          if (!_posting)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Row(
                                children: [
                                  IconButton.filledTonal(
                                    tooltip: 'Choose another photo',
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton.filledTonal(
                                    tooltip: 'Remove photo',
                                    onPressed: () =>
                                        setState(() => _imageBytes = null),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Item name',
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an item name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Donation details',
                hintText: 'Describe condition, quantity, or size',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter donation details'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationController,
              readOnly: true,
              onTap: _chooseLocation,
              decoration: InputDecoration(
                labelText: 'Pinned item location',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  onPressed: _pinningLocation ? null : _chooseLocation,
                  icon: _pinningLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  tooltip: 'Pin current location',
                ),
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Pin the item location'
                  : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pinningLocation ? null : _pinLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Use my current location instead'),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _availabilityController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Availability or pickup details',
                hintText: 'e.g. Weekdays, 9 AM–5 PM • Message before pickup',
                prefixIcon: Icon(Icons.schedule_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Add pickup details'
                  : null,
            ),
            const SizedBox(height: 10),
            const Text(
              'Posted date is added automatically when you publish.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _posting ? null : _postDonation,
              icon: _posting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(_posting ? 'Posting...' : 'Post donation'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: kindLinkEmerald,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.user});

  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 48)),
        const SizedBox(height: 16),
        Center(
          child: Text(
            user.name,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Center(child: Text('@${user.username}')),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit profile'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.notifications_outlined),
                title: Text('Notifications'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.palette_outlined),
                title: Text('Appearance'),
                trailing: Icon(Icons.chevron_right),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.help_outline),
                title: Text('Help and support'),
                trailing: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
