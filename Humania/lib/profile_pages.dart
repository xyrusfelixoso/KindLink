part of 'main.dart';

class _ReferenceProfileTab extends StatelessWidget {
  const _ReferenceProfileTab({
    required this.user,
    required this.onSignOut,
    required this.pickupRequests,
    required this.reviews,
    required this.role,
    required this.rating,
    required this.onReview,
    required this.donatedCount,
    required this.onUserChanged,
  });

  final UserAccount user;
  final VoidCallback onSignOut;
  final List<DonationItem> pickupRequests;
  final List<DonationReview> reviews;
  final String role;
  final String rating;
  final Future<void> Function(DonationReview) onReview;
  final int donatedCount;
  final VoidCallback onUserChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          color: kindLinkPrimaryDark,
          child: Column(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xff55c28e),
                backgroundImage: user.profileImageBytes == null
                    ? null
                    : MemoryImage(user.profileImageBytes!),
                child: user.profileImageBytes == null
                    ? _PresetAvatar(index: user.profileAvatarIndex, size: 70)
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                user.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '@${user.username}',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              if (user.organizationName != null &&
                  user.organizationName!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.apartment_outlined,
                        color: Colors.white70,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user.organizationName!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ReferenceStat(value: '$donatedCount', label: 'Donated'),
                  _ReferenceStat(
                    value: rating,
                    label: 'Rating',
                    icon: Icons.star,
                  ),
                  _ReferenceStat(
                    value: '${pickupRequests.length}',
                    label: 'Requested',
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Account',
                style: TextStyle(
                  color: kindLinkPrimaryDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ProfileCategoryCard(
                icon: Icons.swap_horiz_rounded,
                title: 'Giving & receiving',
                children: [
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.inventory_2_outlined,
                    title: 'My donations',
                    subtitle: 'View your listings and manage pickup requests',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _MyDonationsPage(),
                      ),
                    ),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.handshake_outlined,
                    title: 'My pickup requests',
                    subtitle: 'Track status, view details, or cancel requests',
                    onTap: () => _openRequests(context),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.campaign_outlined,
                    title: 'My donation pledges',
                    subtitle: 'Track campaign items, approval, and handover',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _DonorPledgesPage(),
                      ),
                    ),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.star_outline,
                    title: 'Pickup reviews',
                    subtitle: '${reviews.length} reviews from pickups',
                    onTap: () => _openReviews(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ProfileCategoryCard(
                icon: Icons.people_alt_outlined,
                title: 'Community support',
                children: [
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.front_hand_outlined,
                    title: 'My help requests',
                    subtitle: 'Track approvals, pledges, and received items',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _MyHelpRequestsPage(),
                      ),
                    ),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.volunteer_activism_outlined,
                    title: 'My help donations',
                    subtitle: 'Track pledges, delivery, and confirmation codes',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _MyHelpDonationsPage(),
                      ),
                    ),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.apartment_outlined,
                    title: 'Organizations',
                    subtitle:
                        user.organizationName ??
                        'Create or join an organization',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _OrganizationPage(
                          user: user,
                          onSaved: onUserChanged,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<DataSnapshot>(
                future: firebase_auth.FirebaseAuth.instance.currentUser == null
                    ? null
                    : database
                          .ref(
                            'organizations/${firebase_auth.FirebaseAuth.instance.currentUser!.uid}',
                          )
                          .get(),
                builder: (context, snapshot) {
                  final uid =
                      firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                  final organization = snapshot.data?.value is Map
                      ? Map<Object?, Object?>.from(snapshot.data!.value! as Map)
                      : <Object?, Object?>{};
                  final isVerifiedLeader =
                      uid != null &&
                      organization['ownerUid'] == uid &&
                      organization['verificationStatus'] == 'verified';
                  if (!isVerifiedLeader) return const SizedBox.shrink();
                  return _ProfileCategoryCard(
                    icon: Icons.business_outlined,
                    title: 'Organization tools',
                    children: [
                      _ReferenceTile(
                        embedded: true,
                        icon: Icons.fact_check_outlined,
                        title: 'Help request approvals',
                        subtitle: 'Approve or decline community requests',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _HelpRequestModerationPage(organizationId: uid),
                          ),
                        ),
                      ),
                      _ReferenceTile(
                        embedded: true,
                        icon: Icons.add_business_outlined,
                        title: 'Temporary drop-off points',
                        subtitle: 'Create a verified collection location',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _DropOffPointsPage(organizationId: uid),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (user.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _ProfileCategoryCard(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Administration',
                    children: [
                      _ReferenceTile(
                        embedded: true,
                        icon: Icons.verified_user_outlined,
                        title: 'Admin verification',
                        subtitle: 'Verify organizations and help requests',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const _AdminOrganizationVerificationPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _ProfileCategoryCard(
                icon: Icons.manage_accounts_outlined,
                title: 'Account & activity',
                children: [
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Donation and request updates',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _NotificationsPage(),
                      ),
                    ),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Account and security',
                    onTap: () => _openSettings(context),
                  ),
                  _ReferenceTile(
                    embedded: true,
                    icon: Icons.logout,
                    title: 'Log out',
                    onTap: onSignOut,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openRequests(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const _PickupRequestsPage()));
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _AccountSettingsPage(user: user, onSaved: onUserChanged),
      ),
    );
  }

  void _openReviews(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ReviewsPage(
          requests: pickupRequests,
          reviews: reviews,
          onReview: onReview,
          currentUserName: user.name,
        ),
      ),
    );
  }
}

class _PickupRequestsPage extends StatelessWidget {
  const _PickupRequestsPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My pickup requests')),
      body: firebase_auth.FirebaseAuth.instance.currentUser == null
          ? const Center(child: Text('Sign in to view pickup requests.'))
          : StreamBuilder<DatabaseEvent>(
              stream: database
                  .ref(
                    'pickup_requests/${firebase_auth.FirebaseAuth.instance.currentUser!.uid}',
                  )
                  .onValue,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final value = snapshot.data!.snapshot.value;
                if (value is! Map || value.isEmpty) {
                  return const Center(child: Text('No pickup requests yet.'));
                }
                final requests =
                    Map<Object?, Object?>.from(value).entries
                        .where((entry) => entry.value is Map)
                        .map(
                          (entry) => _PickupRequestRecord(
                            id: entry.key.toString(),
                            data: Map<String, dynamic>.from(
                              Map<Object?, Object?>.from(entry.value! as Map)
                                  .map(
                                    (key, value) =>
                                        MapEntry(key.toString(), value),
                                  ),
                            ),
                          ),
                        )
                        .toList()
                      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _PickupRequestCard(request: requests[index]),
                );
              },
            ),
    );
  }
}

class _PickupRequestRecord {
  const _PickupRequestRecord({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;

  String get status => (data['status'] as String? ?? 'pending').toLowerCase();
  String get statusLabel => status == 'picked_by_another'
      ? 'ITEM PICKED BY ANOTHER PERSON'
      : status.replaceAll('_', ' ').toUpperCase();
  DateTime get requestedAt =>
      DateTime.tryParse(data['requestedAt'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class _PickupRequestCard extends StatelessWidget {
  const _PickupRequestCard({required this.request});

  final _PickupRequestRecord request;

  Color _statusColor() => switch (request.status) {
    'approved' => Colors.green,
    'rejected' || 'cancelled' || 'canceled' => Colors.red,
    'picked_by_another' => Colors.blueGrey,
    'completed' => kindLinkEmerald,
    _ => Colors.orange.shade800,
  };

  IconData _statusIcon() => switch (request.status) {
    'approved' => Icons.check_circle_outline,
    'rejected' || 'cancelled' || 'canceled' => Icons.cancel_outlined,
    'picked_by_another' => Icons.info_outline,
    'completed' => Icons.task_alt,
    _ => Icons.schedule_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PickupRequestDetailsPage(request: request),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: .12),
                foregroundColor: color,
                child: Icon(_statusIcon()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.data['name'] as String? ?? 'Donation',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('From ${request.data['donor'] ?? 'Community donor'}'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        request.statusLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupRequestDetailsPage extends StatelessWidget {
  const _PickupRequestDetailsPage({required this.request});

  final _PickupRequestRecord request;

  Future<void> _remove(BuildContext context) async {
    final action = request.status == 'pending' ? 'cancel' : 'remove';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '${action[0].toUpperCase()}${action.substring(1)} request?',
        ),
        content: Text(
          action == 'cancel'
              ? 'The donor will no longer see this pickup request.'
              : 'This removes the request from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action == 'cancel' ? 'Cancel request' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await database.ref('pickup_requests/$uid/${request.id}').remove();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final requestedAt = request.requestedAt.millisecondsSinceEpoch == 0
        ? null
        : request.requestedAt;
    final canRemove = request.status != 'approved';
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup request details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: kindLinkEmerald),
          const SizedBox(height: 12),
          Text(
            request.data['name'] as String? ?? 'Donation',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: kindLinkPrimaryDark,
            ),
          ),
          const SizedBox(height: 20),
          _PickupDetailRow(
            icon: Icons.info_outline,
            label: 'Status',
            value: request.statusLabel,
          ),
          _PickupDetailRow(
            icon: Icons.person_outline,
            label: 'Donor',
            value: request.data['donor'] as String? ?? 'Community donor',
          ),
          _PickupDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: request.data['location'] as String? ?? 'Pinned location',
          ),
          if ((request.data['details'] as String? ?? '').isNotEmpty)
            _PickupDetailRow(
              icon: Icons.notes_outlined,
              label: 'Details',
              value: request.data['details'] as String,
            ),
          if (requestedAt != null)
            _PickupDetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Requested',
              value: formatPostedDate(requestedAt),
            ),
          const SizedBox(height: 18),
          if (request.status == 'approved')
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The donor approved this request. Coordinate the pickup using the donation details provided.',
                ),
              ),
            ),
          if (request.status == 'picked_by_another')
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'This item was already picked by another person. You can remove this request and browse other available donations.',
                ),
              ),
            ),
          if (canRemove)
            OutlinedButton.icon(
              onPressed: () => _remove(context),
              icon: Icon(
                request.status == 'pending'
                    ? Icons.cancel_outlined
                    : Icons.delete_outline,
              ),
              label: Text(
                request.status == 'pending'
                    ? 'Cancel pickup request'
                    : 'Remove from history',
              ),
            ),
        ],
      ),
    );
  }
}

class _PickupDetailRow extends StatelessWidget {
  const _PickupDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: kindLinkEmerald),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    subtitle: Text(value),
  );
}

class _MyDonationsPage extends StatelessWidget {
  const _MyDonationsPage();

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My donations')),
      body: uid == null
          ? const Center(child: Text('Sign in to view your donations.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('ownerUid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, donationSnapshot) {
                if (!donationSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final donations = donationSnapshot.data!.docs;
                if (donations.isEmpty) {
                  return const Center(
                    child: Text('You have not posted any donations yet.'),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: donations.map((document) {
                    final data = document.data();
                    final item = donationFromData(document.id, data);
                    final status = (data['status'] as String? ?? 'available')
                        .replaceAll('_', ' ')
                        .toUpperCase();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.circle, size: 10),
                          label: Text(status),
                        ),
                        _DonationCard(
                          item: item,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => _MyDonationDetailsPage(
                                item: item,
                                ownerUid: uid,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

class _MyDonationDetailsPage extends StatelessWidget {
  const _MyDonationDetailsPage({required this.item, required this.ownerUid});

  final DonationItem item;
  final String ownerUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage donation')),
      body: StreamBuilder<DatabaseEvent>(
        stream: database.ref('pickup_requests').onValue,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = _incomingDonationRequests(
            snapshot.data!.snapshot.value,
            ownerUid,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [_DonorDonationCard(item: item, requests: requests)],
          );
        },
      ),
    );
  }
}

List<Map<String, dynamic>> _incomingDonationRequests(
  Object? value,
  String ownerUid,
) {
  if (value is! Map) return const [];
  final result = <Map<String, dynamic>>[];
  for (final requester in Map<Object?, Object?>.from(value).entries) {
    if (requester.value is! Map) continue;
    for (final request in Map<Object?, Object?>.from(
      requester.value! as Map,
    ).entries) {
      if (request.value is! Map) continue;
      final data = Map<String, dynamic>.from(
        Map<Object?, Object?>.from(request.value! as Map)
            .map((key, value) => MapEntry(key.toString(), value)),
      );
      if (data['ownerUid'] != ownerUid) continue;
      data['requesterUid'] = requester.key.toString();
      data['requestKey'] = request.key.toString();
      result.add(data);
    }
  }
  return result;
}

class _ReviewsPage extends StatelessWidget {
  const _ReviewsPage({
    required this.requests,
    required this.reviews,
    required this.onReview,
    required this.currentUserName,
  });

  final List<DonationItem> requests;
  final List<DonationReview> reviews;
  final Future<void> Function(DonationReview) onReview;
  final String currentUserName;

  DonationReview? _reviewFor(DonationItem item) {
    for (final review in reviews) {
      if (review.item == item) return review;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final reviewableRequests = requests
        .where((item) => canReviewDonation(item, currentUid, currentUserName))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Pickup reviews')),
      body: reviewableRequests.isEmpty
          ? const Center(child: Text('No eligible pickup feedback yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: reviewableRequests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = reviewableRequests[index];
                final review = _reviewFor(item);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: kindLinkPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('Donated by ${item.donor}'),
                        const SizedBox(height: 14),
                        _RatingEditor(
                          item: item,
                          existing: review,
                          onSubmit: onReview,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _RatingEditor extends StatefulWidget {
  const _RatingEditor({
    required this.item,
    required this.existing,
    required this.onSubmit,
  });

  final DonationItem item;
  final DonationReview? existing;
  final Future<void> Function(DonationReview) onSubmit;

  @override
  State<_RatingEditor> createState() => _RatingEditorState();
}

class _RatingEditorState extends State<_RatingEditor> {
  late int _stars;
  late final TextEditingController _reviewController;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _stars = widget.existing?.stars ?? 0;
    _reviewController = TextEditingController(text: widget.existing?.review);
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        DonationReview(
          item: widget.item,
          stars: _stars,
          review: _reviewController.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your rating.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Rating failed: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            5,
            (index) => KindLinkPressScale(
              child: IconButton(
                tooltip: '${index + 1} stars',
                onPressed: _saving
                    ? null
                    : () => setState(() => _stars = index + 1),
                icon: Icon(
                  index < _stars ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _reviewController,
          enabled: !_saving,
          maxLength: 250,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Short review (optional)',
            hintText: 'How was your pickup experience?',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _stars == 0 || _saving ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  widget.existing == null && !_saved
                      ? Icons.send_outlined
                      : Icons.edit_outlined,
                ),
          label: Text(
            widget.existing == null && !_saved
                ? 'Submit rating'
                : 'Update rating',
          ),
        ),
      ],
    );
  }
}

class _OrganizationPage extends StatefulWidget {
  const _OrganizationPage({required this.user, required this.onSaved});

  final UserAccount user;
  final VoidCallback onSaved;

  @override
  State<_OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<_OrganizationPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _detailsController;
  final _joinController = TextEditingController();
  final _pageController = ScrollController();
  final List<Map<String, String>> _organizations = [];
  bool _loadingOrganizations = true;
  bool _organizationHeaderExpanded = false;
  late bool _editingOrganization;
  bool _isOrganizationOwner = false;
  bool _deletingOrganization = false;
  String _organizationVerificationStatus = 'pending';
  String? _inviteCode;
  String? _organizationsError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.organizationName);
    _detailsController = TextEditingController(
      text: widget.user.organizationDetails,
    );
    _editingOrganization = widget.user.organizationName == null;
    _loadCurrentInviteCode();
    _loadOrganizations();
  }

  Future<void> _loadCurrentInviteCode() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final userSnapshot = await database.ref('users/$uid/organizationId').get();
    final organizationId = userSnapshot.value as String? ?? uid;
    final snapshot = await database.ref('organizations/$organizationId').get();
    if (!mounted) return;
    final organization = snapshot.value is Map
        ? Map<Object?, Object?>.from(snapshot.value! as Map)
        : <Object?, Object?>{};
    setState(() {
      _isOrganizationOwner = snapshot.exists && organization['ownerUid'] == uid;
      _inviteCode = organization['inviteCode'] as String?;
      _organizationVerificationStatus =
          organization['verificationStatus'] as String? ?? 'pending';
    });
  }

  Future<void> _loadOrganizations() async {
    try {
      final snapshot = await database.ref('organizations').get();
      if (!mounted) return;
      final loaded = <Map<String, String>>[];
      if (snapshot.value is Map) {
        for (final entry in Map<Object?, Object?>.from(
          snapshot.value! as Map,
        ).entries) {
          if (entry.value is! Map) continue;
          final data = Map<Object?, Object?>.from(entry.value! as Map);
          final name = _organizationString(data, const [
            'name',
            'organizationName',
            'orgName',
            'displayName',
            'title',
          ]);
          if (name == null || name.trim().isEmpty) continue;
          final status = _organizationStatus(data);
          loaded.add({
            'id': entry.key.toString(),
            'name': name.trim(),
            'details':
                _organizationString(data, const ['details', 'description']) ??
                '',
            'inviteCode':
                _organizationString(data, const ['inviteCode', 'code']) ?? '',
            'verificationStatus': status,
          });
        }
      }
      loaded.sort((a, b) => a['name']!.compareTo(b['name']!));
      setState(() {
        _organizations
          ..clear()
          ..addAll(loaded);
        _loadingOrganizations = false;
        _organizationsError = null;
      });
    } on Exception catch (error) {
      if (mounted) {
        setState(() {
          _loadingOrganizations = false;
          _organizationsError = error.toString();
        });
      }
    }
  }

  String? _organizationString(
    Map<Object?, Object?> organization,
    Iterable<String> keys,
  ) {
    for (final key in keys) {
      final value = organization[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  String _organizationStatus(Map<Object?, Object?> organization) {
    final status = _organizationString(organization, const [
      'verificationStatus',
      'status',
    ])?.toLowerCase();
    if (status == 'approved' || status == 'active') return 'verified';
    if (status != null) return status;
    if (organization['verified'] == true ||
        organization['isVerified'] == true) {
      return 'verified';
    }
    return 'pending';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _joinController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _startCreatingOrganization() {
    setState(() {
      _editingOrganization = true;
      _organizationHeaderExpanded = true;
    });
    _pageController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Widget _availableOrganizationCard(Map<String, String> organization) {
    final currentUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final isOwnedByCurrentUser = organization['id'] == currentUid;
    final verificationStatus = organization['verificationStatus'] ?? 'pending';
    final isVerified = verificationStatus == 'verified';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: const CircleAvatar(
            backgroundColor: kindLinkCream,
            child: Icon(Icons.apartment_outlined, color: kindLinkEmerald),
          ),
          title: Text(
            organization['name']!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kindLinkPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            organization['details']!.isEmpty
                ? 'No details provided'
                : organization['details']!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isOwnedByCurrentUser)
                const Chip(label: Text('Yours'))
              else if (isVerified)
                FilledButton(
                  onPressed: () => _joinListedOrganization(organization),
                  child: const Text('Join'),
                )
              else
                Chip(label: Text(verificationStatus.toUpperCase())),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveOrganization() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (widget.user.organizationName != null && !_isOrganizationOwner) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the organization owner can change its details.'),
        ),
      );
      return;
    }
    final inviteCode = _inviteCode ?? _createInviteCode();
    final isNewOrganization = !_isOrganizationOwner;
    await database.ref('organizations/$uid').update({
      'name': name,
      'details': _detailsController.text.trim(),
      'ownerUid': uid,
      'inviteCode': inviteCode,
      if (isNewOrganization) 'verificationStatus': 'pending',
    });
    await database.ref('users/$uid').update({
      'organizationId': uid,
      'organizationName': name,
      'organizationDetails': _detailsController.text.trim(),
    });
    widget.user
      ..organizationName = name
      ..organizationDetails = _detailsController.text.trim();
    setState(() {
      _inviteCode = inviteCode;
      _isOrganizationOwner = true;
      if (isNewOrganization) _organizationVerificationStatus = 'pending';
      _editingOrganization = false;
    });
    widget.onSaved();
    await _loadOrganizations();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Organization saved.')));
    }
  }

  Future<void> _joinOrganization() async {
    final code = _joinController.text.trim();
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (code.isEmpty || uid == null) return;
    final snapshot = await database.ref('organizations').get();
    if (snapshot.value is! Map) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization code not found.')),
        );
      }
      return;
    }

    String? ownerId;
    Map<Object?, Object?>? data;
    for (final entry in Map<Object?, Object?>.from(
      snapshot.value! as Map,
    ).entries) {
      if (entry.value is! Map) continue;
      final candidate = Map<Object?, Object?>.from(entry.value! as Map);
      if ((candidate['inviteCode'] as String?)?.toUpperCase() ==
          code.toUpperCase()) {
        ownerId = entry.key.toString();
        data = candidate;
        break;
      }
    }
    if (ownerId == null || data == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invite code not found.')));
      }
      return;
    }
    await database.ref('organizations/$ownerId/members/$uid').set(true);
    widget.user
      ..organizationName = data['name'] as String?
      ..organizationDetails = data['details'] as String?;
    await database.ref('users/$uid').update({
      'organizationId': ownerId,
      'organizationName': widget.user.organizationName,
      'organizationDetails': widget.user.organizationDetails,
    });
    setState(() {
      _nameController.text = widget.user.organizationName ?? '';
      _detailsController.text = widget.user.organizationDetails ?? '';
      _organizationVerificationStatus =
          data?['verificationStatus'] as String? ?? 'pending';
      _inviteCode = data?['inviteCode'] as String?;
      _isOrganizationOwner = data?['ownerUid'] == uid;
      _editingOrganization = false;
      _organizationHeaderExpanded = true;
      _joinController.clear();
    });
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Joined ${widget.user.organizationName ?? 'organization'}.',
          ),
        ),
      );
    }
  }

  Future<void> _joinListedOrganization(Map<String, String> organization) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final id = organization['id']!;
    await database.ref('organizations/$id/members/$uid').set(true);
    widget.user
      ..organizationName = organization['name']
      ..organizationDetails = organization['details'];
    await database.ref('users/$uid').update({
      'organizationId': id,
      'organizationName': widget.user.organizationName,
      'organizationDetails': widget.user.organizationDetails,
    });
    final joinedSnapshot = await database.ref('organizations/$id').get();
    final joinedData = joinedSnapshot.value is Map
        ? Map<Object?, Object?>.from(joinedSnapshot.value! as Map)
        : <Object?, Object?>{};
    setState(() {
      _nameController.text = widget.user.organizationName ?? '';
      _detailsController.text = widget.user.organizationDetails ?? '';
      _organizationVerificationStatus =
          joinedData['verificationStatus'] as String? ?? 'pending';
      _inviteCode = joinedData['inviteCode'] as String?;
      _isOrganizationOwner = joinedData['ownerUid'] == uid;
      _editingOrganization = false;
      _organizationHeaderExpanded = true;
    });
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${organization['name']}.')),
      );
    }
  }

  String _createInviteCode() {
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      8,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  Future<void> _deleteOrganization() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _deletingOrganization) return;

    final snapshot = await database.ref('organizations/$uid').get();
    final organization = snapshot.value is Map
        ? Map<Object?, Object?>.from(snapshot.value! as Map)
        : <Object?, Object?>{};
    if (!snapshot.exists || organization['ownerUid'] != uid) {
      if (!mounted) return;
      setState(() => _isOrganizationOwner = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the organization owner can delete it.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete organization?'),
        content: const Text(
          'This permanently deletes the organization and removes it from all members. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingOrganization = true);
    try {
      final updates = <String, Object?>{
        'organizations/$uid': null,
        'users/$uid/organizationId': null,
        'users/$uid/organizationName': null,
        'users/$uid/organizationDetails': null,
      };
      final members = organization['members'];
      if (members is Map) {
        for (final memberId in members.keys.map((key) => key.toString())) {
          final memberOrganization = await database
              .ref('users/$memberId/organizationId')
              .get();
          if (memberOrganization.value == uid) {
            updates['users/$memberId/organizationId'] = null;
            updates['users/$memberId/organizationName'] = null;
            updates['users/$memberId/organizationDetails'] = null;
          }
        }
      }
      await database.ref().update(updates);
      widget.user
        ..organizationName = null
        ..organizationDetails = null;
      _nameController.clear();
      _detailsController.clear();
      setState(() {
        _inviteCode = null;
        _isOrganizationOwner = false;
        _editingOrganization = true;
        _organizationHeaderExpanded = false;
      });
      widget.onSaved();
      await _loadOrganizations();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Organization deleted.')));
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete the organization.')),
      );
    } finally {
      if (mounted) setState(() => _deletingOrganization = false);
    }
  }

  Future<void> _leaveOrganization() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isOrganizationOwner) return;
    final organizationIdSnapshot = await database
        .ref('users/$uid/organizationId')
        .get();
    final organizationId = organizationIdSnapshot.value as String?;
    if (organizationId == null || organizationId.isEmpty) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave organization?'),
        content: Text(
          'You will leave ${widget.user.organizationName ?? 'this organization'} and lose member access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await database.ref().update({
      'organizations/$organizationId/members/$uid': null,
      'users/$uid/organizationId': null,
      'users/$uid/organizationName': null,
      'users/$uid/organizationDetails': null,
    });
    widget.user
      ..organizationName = null
      ..organizationDetails = null;
    setState(() {
      _nameController.clear();
      _detailsController.clear();
      _inviteCode = null;
      _organizationVerificationStatus = 'pending';
      _organizationHeaderExpanded = false;
      _editingOrganization = true;
    });
    widget.onSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the organization.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Organization',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        controller: _pageController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your organization',
                    style: TextStyle(
                      color: kindLinkPrimaryDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(
                        () => _organizationHeaderExpanded =
                            !_organizationHeaderExpanded,
                      ),
                      child: Ink(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xff155d43), Color(0xff2f8b67)],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white24,
                                  child: Icon(
                                    Icons.apartment,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _nameController.text.trim().isEmpty
                                            ? 'Build your community'
                                            : _nameController.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Row(
                                        children: [
                                          Icon(
                                            Icons.verified_outlined,
                                            color: Color(0xffffd54f),
                                            size: 18,
                                          ),
                                          SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              'Organization',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  _organizationHeaderExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: !_organizationHeaderExpanded
                                  ? const SizedBox.shrink()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          child: Divider(color: Colors.white24),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white12,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            'Verification: ${_organizationVerificationStatus.toUpperCase()}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        if (!_editingOrganization) ...[
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.apartment_outlined,
                                                color: Color(0xffffd54f),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _nameController.text
                                                          .trim()
                                                          .isEmpty
                                                      ? 'Organization name: Not set'
                                                      : 'Organization name: ${_nameController.text.trim()}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.description_outlined,
                                                color: Color(0xffffd54f),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _detailsController.text
                                                          .trim()
                                                          .isEmpty
                                                      ? 'Organization details: Not set'
                                                      : 'Organization details: ${_detailsController.text.trim()}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.key_outlined,
                                              color: Color(0xffffd54f),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _inviteCode == null
                                                    ? 'Save to create an invite code'
                                                    : 'Invite code: $_inviteCode',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            if (_inviteCode != null)
                                              KindLinkPressScale(
                                                child: IconButton(
                                                  tooltip: 'Copy invite code',
                                                  color: Colors.white,
                                                  onPressed: () {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: _inviteCode!,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Invite code copied.',
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.copy_outlined,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        if (_editingOrganization &&
                                            (_isOrganizationOwner ||
                                                widget.user.organizationName ==
                                                    null)) ...[
                                          const Text(
                                            'Organization name',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _nameController,
                                            onChanged: (_) => setState(() {}),
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Enter organization name',
                                              prefixIcon: Icon(
                                                Icons.apartment_outlined,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'Organization details',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          TextField(
                                            controller: _detailsController,
                                            onChanged: (_) => setState(() {}),
                                            minLines: 2,
                                            maxLines: 4,
                                            decoration: const InputDecoration(
                                              hintText:
                                                  'Describe your organization',
                                              prefixIcon: Icon(
                                                Icons.description_outlined,
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 14),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            if (_editingOrganization &&
                                                (_isOrganizationOwner ||
                                                    widget
                                                            .user
                                                            .organizationName ==
                                                        null))
                                              FilledButton.icon(
                                                onPressed: _saveOrganization,
                                                style: FilledButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      kindLinkEmerald,
                                                ),
                                                icon: const Icon(
                                                  Icons.save_outlined,
                                                ),
                                                label: const Text(
                                                  'Save details',
                                                ),
                                              )
                                            else if (_isOrganizationOwner)
                                              OutlinedButton.icon(
                                                onPressed: () => setState(
                                                  () => _editingOrganization =
                                                      true,
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                label: const Text(
                                                  'Change details',
                                                ),
                                              ),
                                            if (_isOrganizationOwner)
                                              OutlinedButton.icon(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        _OrganizationCampaignsPage(
                                                          user: widget.user,
                                                        ),
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.campaign_outlined,
                                                ),
                                                label: const Text('Campaigns'),
                                              ),
                                            if (_isOrganizationOwner &&
                                                _organizationVerificationStatus ==
                                                    'verified')
                                              OutlinedButton.icon(
                                                onPressed: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        _HelpRequestModerationPage(
                                                          organizationId:
                                                              firebase_auth
                                                                  .FirebaseAuth
                                                                  .instance
                                                                  .currentUser
                                                                  ?.uid,
                                                        ),
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  side: const BorderSide(
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.fact_check_outlined,
                                                ),
                                                label: const Text(
                                                  'Help requests',
                                                ),
                                              ),
                                            if (_isOrganizationOwner)
                                              OutlinedButton.icon(
                                                onPressed: _deletingOrganization
                                                    ? null
                                                    : _deleteOrganization,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xffffd7d7,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xffffa8a8),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                label: Text(
                                                  _deletingOrganization
                                                      ? 'Deleting...'
                                                      : 'Delete',
                                                ),
                                              ),
                                            if (!_isOrganizationOwner &&
                                                widget.user.organizationName !=
                                                    null)
                                              OutlinedButton.icon(
                                                onPressed: _leaveOrganization,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(
                                                    0xffffd7d7,
                                                  ),
                                                  side: const BorderSide(
                                                    color: Color(0xffffa8a8),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.logout_outlined,
                                                ),
                                                label: const Text(
                                                  'Leave organization',
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ProfileCategoryCard(
            icon: Icons.volunteer_activism_outlined,
            title: 'Organization donations',
            children: [
              _ReferenceTile(
                embedded: true,
                icon: Icons.campaign_outlined,
                title: _isOrganizationOwner
                    ? 'Campaign management'
                    : 'Donation campaigns',
                subtitle: _isOrganizationOwner
                    ? 'Create campaigns, review progress, and post reports'
                    : 'Browse campaigns from verified organizations',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _isOrganizationOwner
                        ? _OrganizationCampaignsPage(user: widget.user)
                        : _DonorCampaignsPage(user: widget.user),
                  ),
                ),
              ),
              _ReferenceTile(
                embedded: true,
                icon: Icons.volunteer_activism_rounded,
                title: 'My donation pledges',
                subtitle: 'Track campaign donations and handover status',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const _DonorPledgesPage()),
                ),
              ),
              if (_isOrganizationOwner &&
                  _organizationVerificationStatus == 'verified') ...[
                _ReferenceTile(
                  embedded: true,
                  icon: Icons.inbox_outlined,
                  title: 'Donation requests',
                  subtitle: 'Approve pledges and confirm received items',
                  onTap: () {
                    final uid =
                        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _OrganizationOffersPage(organizationId: uid),
                      ),
                    );
                  },
                ),
                _ReferenceTile(
                  embedded: true,
                  icon: Icons.fact_check_outlined,
                  title: 'Help request approvals',
                  subtitle: 'Review community requests for your organization',
                  onTap: () {
                    final uid =
                        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _HelpRequestModerationPage(organizationId: uid),
                      ),
                    );
                  },
                ),
                _ReferenceTile(
                  embedded: true,
                  icon: Icons.add_business_outlined,
                  title: 'Drop-off points',
                  subtitle: 'Create verified collection locations',
                  onTap: () {
                    final uid =
                        firebase_auth.FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _DropOffPointsPage(organizationId: uid),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Join with invite code',
                    style: TextStyle(
                      color: kindLinkPrimaryDark,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _joinController,
                    decoration: const InputDecoration(
                      labelText: 'Organization invite code',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _joinOrganization,
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Available organizations',
                          style: TextStyle(
                            color: kindLinkPrimaryDark,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.user.organizationName == null) ...[
                    const SizedBox(height: 6),
                    FilledButton.icon(
                      onPressed: _startCreatingOrganization,
                      icon: const Icon(Icons.add),
                      label: const Text('Create organization'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (_loadingOrganizations)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_organizationsError != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xfffff4f2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Unable to load organizations from Firebase.',
                            style: TextStyle(color: kindLinkUrgent),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() => _loadingOrganizations = true);
                              _loadOrganizations();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else if (_organizations.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xfff3f8f5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'No organizations have been created yet.',
                        style: TextStyle(color: kindLinkSecondaryText),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          ),
          if (!_loadingOrganizations && _organizations.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._organizations.map(_availableOrganizationCard),
          ],
        ],
      ),
    );
  }
}

class _AccountSettingsPage extends StatefulWidget {
  const _AccountSettingsPage({required this.user, required this.onSaved});

  final UserAccount user;
  final VoidCallback onSaved;

  @override
  State<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<_AccountSettingsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  Uint8List? _profileImageBytes;
  late int _profileAvatarIndex;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _usernameController = TextEditingController(text: widget.user.username);
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController();
    _profileImageBytes = widget.user.profileImageBytes;
    _profileAvatarIndex = widget.user.profileAvatarIndex;
  }

  Future<void> _pickProfileImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 600,
      maxHeight: 600,
    );
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() => _profileImageBytes = bytes);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;
    try {
      final email = _emailController.text.trim();
      if (authUser.email != email) {
        await authUser.verifyBeforeUpdateEmail(email);
      }
      if (_passwordController.text.isNotEmpty) {
        await authUser.updatePassword(_passwordController.text);
      }
      await database.ref('users/${authUser.uid}').update({
        'name': _nameController.text.trim(),
        'username': _usernameController.text.trim().replaceFirst(
          RegExp(r'^@+'),
          '',
        ),
        'email': _emailController.text.trim(),
        'profileAvatarIndex': _profileAvatarIndex,
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          'requires-recent-login' => 'For your security, sign out and sign in again before changing account credentials.',
          'weak-password' => 'Choose a stronger password and try again.',
          'invalid-email' => 'Enter a valid email address.',
          _ => 'Unable to update the account. Please try again.',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
      return;
    }
    widget.user
      ..name = _nameController.text.trim()
      ..username = _usernameController.text.trim().replaceFirst(
        RegExp(r'^@+'),
        '',
      )
      ..email = _emailController.text.trim();
    widget.user.profileImageBytes = _profileImageBytes;
    widget.user.profileAvatarIndex = _profileAvatarIndex;
    widget.onSaved();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account settings'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickProfileImage,
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: kindLinkCream,
                  backgroundImage: _profileImageBytes == null
                      ? null
                      : MemoryImage(_profileImageBytes!),
                  child: _profileImageBytes == null
                      ? _PresetAvatar(index: _profileAvatarIndex, size: 90)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Tap to choose a profile picture')),
            const SizedBox(height: 18),
            const Text(
              'Choose a preset profile',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                _PresetAvatar.styles.length,
                (index) => InkWell(
                  onTap: () => setState(() {
                    _profileAvatarIndex = index;
                    _profileImageBytes = null;
                  }),
                  borderRadius: BorderRadius.circular(42),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _profileAvatarIndex == index
                            ? kindLinkEmerald
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: _PresetAvatar(index: index, size: 64),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter your name'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _usernameController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Nickname / username',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (value) =>
                  value == null ||
                      value.trim().replaceFirst(RegExp(r'^@+'), '').isEmpty
                  ? 'Enter your nickname'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Gmail / email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'New password (optional)',
                helperText: 'Leave blank to keep your current password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? null
                  : AuthValidators.newPassword(value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: kindLinkEmerald,
              ),
              child: const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetAvatar extends StatelessWidget {
  const _PresetAvatar({required this.index, required this.size});

  final int index;
  final double size;

  static const styles = [
    [Color(0xffffd6e7), Icons.face_3],
    [Color(0xffd7e8ff), Icons.face],
    [Color(0xffffe3ba), Icons.face_6],
    [Color(0xffd8f3df), Icons.face_4],
    [Color(0xffeadcff), Icons.face_2],
    [Color(0xffffd9c7), Icons.face_5],
    [Color(0xffd8f0f0), Icons.face_retouching_natural],
    [Color(0xffffe1ef), Icons.face_3],
    [Color(0xffe5e5e5), Icons.face],
    [Color(0xffffedbd), Icons.face_6],
  ];

  @override
  Widget build(BuildContext context) {
    final style = styles[index.clamp(0, styles.length - 1)];
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: style[0] as Color,
      child: Icon(
        style[1] as IconData,
        size: size * .62,
        color: const Color(0xff263238),
      ),
    );
  }
}

class _ReferenceStat extends StatelessWidget {
  const _ReferenceStat({required this.value, required this.label, this.icon});

  final String value;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (icon != null)
              const Icon(Icons.star, color: Colors.amber, size: 28),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _ProfileCategoryCard extends StatelessWidget {
  const _ProfileCategoryCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                Icon(icon, color: kindLinkEmerald, size: 22),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    color: kindLinkPrimaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const Divider(height: 1, indent: 66, endIndent: 16),
            children[index],
          ],
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.embedded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      leading: Icon(icon, color: const Color(0xffe1b936), size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, color: Colors.black26),
    );
    if (embedded) return tile;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: tile,
    );
  }
}
