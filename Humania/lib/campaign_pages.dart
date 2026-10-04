part of 'main.dart';

const _standardDonationConditions = <String>[
  'New',
  'Gently used',
  'Good condition',
];

List<String> _donationConditionOptions(String? preferred) => <String>{
  if (preferred != null && preferred.trim().isNotEmpty) preferred.trim(),
  ..._standardDonationConditions,
}.toList();

int _campaignQuantity(Map<String, dynamic> item, String field) =>
    max(0, (item[field] as num? ?? 0).toInt());

int _campaignRemaining(Map<String, dynamic> item) {
  final needed = _campaignQuantity(item, 'quantityNeeded');
  final received = _campaignQuantity(item, 'quantityReceived');
  final pledged = _campaignQuantity(item, 'quantityPledged');
  final stored = item['quantityRemaining'] as num?;

  // Older records can contain a missing or incorrectly initialized zero.
  // Derive the value when no donation activity has happened yet.
  if (stored == null ||
      (stored.toInt() == 0 && received == 0 && pledged == 0 && needed > 0)) {
    return max(0, needed - received - pledged);
  }
  return stored.toInt().clamp(0, needed);
}

String _organizationDonationGuidance(
  String status,
  String? handoverMethod,
) => switch (status) {
  'Pending' => 'Review the pledged items, then approve or reject the donation.',
  'Approved' when handoverMethod == null =>
    'Approved. Waiting for the donor to choose drop-off or pickup.',
  'Approved' =>
    'Handover: $handoverMethod. Confirm quantities only after they arrive.',
  'Received' => 'Completed. The confirmed quantities now count as received.',
  'Rejected' => 'Declined. The pledged quantities are available again.',
  _ => 'Review this donation request.',
};

class _AdminOrganizationVerificationPage extends StatelessWidget {
  const _AdminOrganizationVerificationPage();

  Future<void> _setStatus(
    BuildContext context,
    String organizationId,
    String status,
  ) async {
    final adminUid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    final adminSnapshot = await database.ref('users/$adminUid/isAdmin').get();
    final signedInEmail =
        firebase_auth.FirebaseAuth.instance.currentUser?.email;
    if (adminSnapshot.value != true && !isDesignatedAdminEmail(signedInEmail)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Admin access required.')));
      }
      return;
    }
    await database.ref('organizations/$organizationId').update({
      'verificationStatus': status,
      'verifiedBy': adminUid,
      'verifiedAt': ServerValue.timestamp,
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Organization verification'),
      actions: [
        KindLinkPressScale(
          child: IconButton(
            tooltip: 'Verify help requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _HelpRequestModerationPage(),
              ),
            ),
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ),
      ],
    ),
    body: StreamBuilder<DatabaseEvent>(
      stream: database.ref('organizations').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final raw = snapshot.data!.snapshot.value;
        final organizations = <Map<String, dynamic>>[];
        if (raw is Map) {
          for (final entry in raw.entries) {
            if (entry.value is! Map) continue;
            organizations.add({
              'id': entry.key.toString(),
              ...Map<String, dynamic>.from(entry.value as Map),
            });
          }
        }
        if (organizations.isEmpty) {
          return const Center(child: Text('No organizations to review.'));
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: organizations.map((organization) {
            final status =
                organization['verificationStatus'] as String? ?? 'pending';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization['name'] as String? ?? 'Organization',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(organization['details'] as String? ?? 'No details'),
                    const SizedBox(height: 8),
                    Chip(label: Text(status.toUpperCase())),
                    if (status == 'pending')
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _setStatus(
                              context,
                              organization['id'] as String,
                              'rejected',
                            ),
                            child: const Text('Reject'),
                          ),
                          FilledButton.icon(
                            onPressed: () => _setStatus(
                              context,
                              organization['id'] as String,
                              'verified',
                            ),
                            icon: const Icon(Icons.verified_outlined),
                            label: const Text('Verify'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

class _OrganizationCampaignsPage extends StatelessWidget {
  const _OrganizationCampaignsPage({required this.user});
  final UserAccount user;

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Campaign management',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        actions: [
          KindLinkPressScale(
            child: IconButton(
              tooltip: 'Donation requests',
              onPressed: uid == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _OrganizationOffersPage(organizationId: uid),
                      ),
                    ),
              icon: const Icon(Icons.inbox_outlined),
            ),
          ),
        ],
      ),
      floatingActionButton: KindLinkPressScale(
        child: FloatingActionButton(
          tooltip: 'Create campaign',
          onPressed: uid == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        _CreateCampaignPage(user: user, organizationId: uid),
                  ),
                ),
          backgroundColor: kindLinkOrange,
          foregroundColor: Colors.white,
          elevation: 5,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to manage campaigns.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('campaigns')
                  .where('organizationId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.campaign_outlined,
                            size: 42,
                            color: kindLinkEmerald,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Create your first item donation campaign.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap the orange plus button to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: kindLinkSecondaryText),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 112),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _CampaignCard(
                    document: docs[index],
                    organization: true,
                    onPostReport: () => _postCampaignDistributionReport(
                      context,
                      docs[index].id,
                      docs[index].data(),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DonorCampaignsPage extends StatelessWidget {
  const _DonorCampaignsPage({required this.user});
  final UserAccount user;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Donation campaigns',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      actions: [
        KindLinkPressScale(
          child: IconButton.filledTonal(
            tooltip: 'My donation pledges',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _DonorPledgesPage()),
            ),
            style: IconButton.styleFrom(
              backgroundColor: kindLinkEmerald.withValues(alpha: 0.14),
              foregroundColor: kindLinkPrimaryDark,
              minimumSize: const Size.square(42),
            ),
            icon: const Icon(Icons.volunteer_activism_rounded),
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('campaigns')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });
        if (docs.isEmpty) {
          return const Center(child: Text('No active campaigns right now.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (_, index) => _CampaignCard(
            document: docs[index],
            organization: false,
            user: user,
          ),
        );
      },
    ),
  );
}

class _DonorPledgesPage extends StatelessWidget {
  const _DonorPledgesPage();

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My donation pledges')),
      body: uid == null
          ? const Center(child: Text('Sign in to view your pledges.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('campaignDonations')
                  .where('donorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pledges = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aTime = a.data()['createdAt'] as Timestamp?;
                    final bTime = b.data()['createdAt'] as Timestamp?;
                    return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                      aTime?.millisecondsSinceEpoch ?? 0,
                    );
                  });
                if (pledges.isEmpty) {
                  return const Center(child: Text('No pledges submitted yet.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: pledges.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) => _DonorPledgeCard(
                    pledge: pledges[index],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _DonorPledgeDetailsPage(
                          pledgeReference: pledges[index].reference,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _DonorPledgeCard extends StatelessWidget {
  const _DonorPledgeCard({required this.pledge, required this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> pledge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = pledge.data();
    final status = data['status'] as String? ?? 'Pending';
    final color = _donorPledgeStatusColor(status);
    final createdAt = data['createdAt'] as Timestamp?;
    final itemCount = (data['itemCount'] as num? ?? 1).toInt();
    final handover = data['handoverMethod'] as String?;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: .18)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    foregroundColor: color,
                    child: Icon(_donorPledgeStatusIcon(status)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['campaignTitle'] as String? ?? 'Campaign',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$itemCount item type${itemCount == 1 ? '' : 's'}'
                          '${createdAt == null ? '' : ' • ${formatPostedDate(createdAt.toDate())}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _DonorPledgeStatusBadge(status: status),
                ],
              ),
              if (handover != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      handover == 'Pickup'
                          ? Icons.local_shipping_outlined
                          : Icons.store_outlined,
                      size: 18,
                      color: kindLinkEmerald,
                    ),
                    const SizedBox(width: 7),
                    Text('Handover: $handover'),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonorPledgeDetailsPage extends StatelessWidget {
  const _DonorPledgeDetailsPage({required this.pledgeReference});

  final DocumentReference<Map<String, dynamic>> pledgeReference;

  Future<void> _selectHandover(
    BuildContext context,
    String method, {
    Map<String, dynamic>? dropOffPoint,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final latest = await transaction.get(pledgeReference);
        final latestData = latest.data();
        if (latestData?['status'] != 'Approved') {
          throw Exception(
            'Only approved pledges can select a handover method.',
          );
        }
        transaction.update(pledgeReference, {
          'handoverMethod': method,
          'handoverSelectedAt': FieldValue.serverTimestamp(),
          if (dropOffPoint != null) ...{
            'dropOffPointId': dropOffPoint['id'],
            'dropOffPointName': dropOffPoint['name'],
            'dropOffPointLocation': dropOffPoint['approximateLocation'],
            'dropOffPointHours': dropOffPoint['operatingHours'],
            'dropOffPointLatitude': dropOffPoint['latitude'],
            'dropOffPointLongitude': dropOffPoint['longitude'],
            'dropOffPointDistanceMeters': dropOffPoint['distanceMeters'],
          },
        });
        final organizationId = latestData?['organizationId'] as String?;
        if (organizationId != null) {
          transaction.set(
            FirebaseFirestore.instance.collection('notifications').doc(),
            {
              'recipientId': organizationId,
              'type': 'campaignHandoverSelected',
              'campaignId': latestData?['campaignId'],
              'donationId': pledgeReference.id,
              'title': '$method selected',
              'message': dropOffPoint == null
                  ? 'The donor selected pickup for ${latestData?['campaignTitle'] ?? 'a campaign pledge'}.'
                  : 'The donor selected ${dropOffPoint['name']} as the drop-off point.',
              'read': false,
              'createdAt': FieldValue.serverTimestamp(),
            },
          );
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$method selected.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<Position> _currentDonorPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception(
        'Turn on location services to find the nearest drop-off point.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw Exception(
        'Location permission is required to suggest the nearest point.',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is disabled. Enable it in device settings to find a drop-off point.',
      );
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _suggestNearestDropOff(
    BuildContext context,
    Map<String, dynamic> pledge,
  ) async {
    final organizationId = pledge['organizationId'] as String?;
    if (organizationId == null || organizationId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This campaign has no organization assigned.'),
        ),
      );
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding the nearest drop-off point...')),
      );
      final position = await _currentDonorPosition();
      final snapshot = await FirebaseFirestore.instance
          .collection('dropOffPoints')
          .where('organizationId', isEqualTo: organizationId)
          .get();
      final now = DateTime.now();
      final points =
          snapshot.docs
              .where((document) {
                final data = document.data();
                final opening = data['openingDate'] as Timestamp?;
                final closing = data['closingDate'] as Timestamp?;
                return data['status'] == 'active' &&
                    data['latitude'] is num &&
                    data['longitude'] is num &&
                    (opening == null || !now.isBefore(opening.toDate())) &&
                    (closing == null || !now.isAfter(closing.toDate()));
              })
              .map((document) {
                final data = <String, dynamic>{
                  ...document.data(),
                  'id': document.id,
                };
                data['distanceMeters'] = Geolocator.distanceBetween(
                  position.latitude,
                  position.longitude,
                  (data['latitude'] as num).toDouble(),
                  (data['longitude'] as num).toDouble(),
                );
                return data;
              })
              .toList()
            ..sort(
              (a, b) => (a['distanceMeters'] as double).compareTo(
                b['distanceMeters'] as double,
              ),
            );
      if (points.isEmpty) {
        throw Exception(
          'This organization has no active drop-off point right now. Choose Pickup instead.',
        );
      }
      if (!context.mounted) return;
      final nearest = points.first;
      final donorPoint = LatLng(position.latitude, position.longitude);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: const Text('Nearest drop-off point'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nearest['name'] as String? ?? 'Collection point',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(nearest['approximateLocation'] as String? ?? ''),
              if ((nearest['operatingHours'] as String? ?? '').isNotEmpty)
                Text('Hours: ${nearest['operatingHours']}'),
              const SizedBox(height: 8),
              Text(
                'Distance: ${_formatDropOffDistance(nearest['distanceMeters'] as double)}',
                style: const TextStyle(
                  color: kindLinkEmerald,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(dialogContext).push(
                MaterialPageRoute(
                  builder: (_) => _DropOffPointMapPage(
                    point: nearest,
                    donorLocation: donorPoint,
                  ),
                ),
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('View map'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Use this point'),
            ),
          ],
        ),
      );
      if (accepted == true && context.mounted) {
        await _selectHandover(context, 'Drop-off', dropOffPoint: nearest);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _cancel(
    BuildContext context,
    Map<String, dynamic> pledge,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this pledge?'),
        content: const Text(
          'The reserved quantities will become available to other donors. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep pledge'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel pledge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.runTransaction((transaction) async {
        final latestPledge = await transaction.get(pledgeReference);
        if (latestPledge.data()?['status'] != 'Pending') {
          throw Exception('Only pending pledges can be cancelled.');
        }
        final campaignItems =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final item in items) {
          final reference = firestore
              .collection('campaignItems')
              .doc(item.data()['campaignItemId'] as String);
          campaignItems[item.id] = await transaction.get(reference);
        }
        for (final item in items) {
          final offered = _campaignQuantity(item.data(), 'quantityOffered');
          final campaignItem = campaignItems[item.id]!;
          final current = campaignItem.data();
          if (current == null) continue;
          final needed = _campaignQuantity(current, 'quantityNeeded');
          final received = _campaignQuantity(current, 'quantityReceived');
          transaction.update(campaignItem.reference, {
            'quantityRemaining': min(
              max(0, needed - received),
              _campaignRemaining(current) + offered,
            ),
            'quantityPledged': max(
              0,
              _campaignQuantity(current, 'quantityPledged') - offered,
            ),
          });
        }
        transaction.update(pledgeReference, {
          'status': 'Cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        final organizationId = pledge['organizationId'] as String?;
        if (organizationId != null) {
          transaction.set(firestore.collection('notifications').doc(), {
            'recipientId': organizationId,
            'type': 'campaignPledgeCancelled',
            'campaignId': pledge['campaignId'],
            'donationId': pledgeReference.id,
            'title': 'Donation pledge cancelled',
            'message':
                '${pledge['donorName'] ?? 'A donor'} cancelled a pledge for ${pledge['campaignTitle'] ?? 'your campaign'}.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pledge cancelled successfully.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: pledgeReference.snapshots(),
      builder: (context, pledgeSnapshot) {
        if (!pledgeSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final pledge = pledgeSnapshot.data!.data();
        if (pledge == null) {
          return const Scaffold(
            body: Center(child: Text('This pledge is no longer available.')),
          );
        }
        final status = pledge['status'] as String? ?? 'Pending';
        final handover = pledge['handoverMethod'] as String?;
        final message = (pledge['message'] as String? ?? '').trim();
        final createdAt = pledge['createdAt'] as Timestamp?;
        return Scaffold(
          appBar: AppBar(title: const Text('Pledge details')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('donationItems')
                .where('donationId', isEqualTo: pledgeReference.id)
                .snapshots(),
            builder: (context, itemSnapshot) {
              if (!itemSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = itemSnapshot.data!.docs;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pledge['campaignTitle'] as String? ?? 'Campaign',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _DonorPledgeStatusBadge(status: status),
                    ],
                  ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 6),
                    Text('Submitted ${formatPostedDate(createdAt.toDate())}'),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    color: _donorPledgeStatusColor(status)
                        .withValues(alpha: .08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _donorPledgeStatusIcon(status),
                            color: _donorPledgeStatusColor(status),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_donorPledgeGuidance(status))),
                        ],
                      ),
                    ),
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Your message',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(message),
                  ],
                  const SizedBox(height: 20),
                  const Text(
                    'Items pledged',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final data = item.data();
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(data['itemName'] ?? 'Item'),
                        subtitle: Text(
                          'Offered: ${_campaignQuantity(data, 'quantityOffered')}'
                          '\nReceived: ${_campaignQuantity(data, 'quantityReceived')}'
                          '\nCondition: ${data['condition'] ?? 'Not specified'}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                  if (status == 'Approved' && handover == null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Choose handover method',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _suggestNearestDropOff(context, pledge),
                          icon: const Icon(Icons.store_outlined),
                          label: const Text('Find nearest drop-off'),
                        ),
                        FilledButton.icon(
                          onPressed: () => _selectHandover(context, 'Pickup'),
                          icon: const Icon(Icons.local_shipping_outlined),
                          label: const Text('Pickup'),
                        ),
                      ],
                    ),
                  ],
                  if (handover != null) ...[
                    const SizedBox(height: 20),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        handover == 'Pickup'
                            ? Icons.local_shipping_outlined
                            : Icons.store_outlined,
                        color: kindLinkEmerald,
                      ),
                      title: const Text('Handover method'),
                      subtitle: Text(handover),
                    ),
                    if (handover == 'Drop-off' &&
                        pledge['dropOffPointLatitude'] is num &&
                        pledge['dropOffPointLongitude'] is num)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pledge['dropOffPointName'] as String? ??
                                    'Selected drop-off point',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if ((pledge['dropOffPointLocation'] as String? ??
                                      '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(pledge['dropOffPointLocation']),
                                ),
                              if ((pledge['dropOffPointHours'] as String? ?? '')
                                  .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Hours: ${pledge['dropOffPointHours']}',
                                  ),
                                ),
                              if (pledge['dropOffPointDistanceMeters'] is num)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Distance when selected: ${_formatDropOffDistance((pledge['dropOffPointDistanceMeters'] as num).toDouble())}',
                                  ),
                                ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => _DropOffPointMapPage(
                                      point: {
                                        'name': pledge['dropOffPointName'],
                                        'approximateLocation':
                                            pledge['dropOffPointLocation'],
                                        'operatingHours':
                                            pledge['dropOffPointHours'],
                                        'latitude':
                                            pledge['dropOffPointLatitude'],
                                        'longitude':
                                            pledge['dropOffPointLongitude'],
                                      },
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('View on map'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if (status == 'Pending') ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => _cancel(context, pledge, items),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel pending pledge'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

String _formatDropOffDistance(double meters) => meters < 1000
    ? '${meters.round()} m away'
    : '${(meters / 1000).toStringAsFixed(1)} km away';

class _DropOffPointMapPage extends StatelessWidget {
  const _DropOffPointMapPage({required this.point, this.donorLocation});

  final Map<String, dynamic> point;
  final LatLng? donorLocation;

  @override
  Widget build(BuildContext context) {
    final dropOff = LatLng(
      (point['latitude'] as num).toDouble(),
      (point['longitude'] as num).toDouble(),
    );
    final center = donorLocation == null
        ? dropOff
        : LatLng(
            (dropOff.latitude + donorLocation!.latitude) / 2,
            (dropOff.longitude + donorLocation!.longitude) / 2,
          );
    final distance = donorLocation == null
        ? 0.0
        : Geolocator.distanceBetween(
            donorLocation!.latitude,
            donorLocation!.longitude,
            dropOff.latitude,
            dropOff.longitude,
          );
    final zoom = donorLocation == null
        ? 15.0
        : distance < 1000
        ? 14.5
        : distance < 5000
        ? 12.5
        : distance < 20000
        ? 10.5
        : 8.5;
    return Scaffold(
      appBar: AppBar(title: const Text('Drop-off point map')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: zoom),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.humania',
              ),
              if (donorLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [donorLocation!, dropOff],
                      strokeWidth: 4,
                      color: kindLinkEmerald.withValues(alpha: .7),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (donorLocation != null)
                    Marker(
                      point: donorLocation!,
                      width: 48,
                      height: 48,
                      child: const Tooltip(
                        message: 'Your current location',
                        child: Icon(
                          Icons.my_location,
                          color: kindLinkBlue,
                          size: 36,
                        ),
                      ),
                    ),
                  Marker(
                    point: dropOff,
                    width: 52,
                    height: 52,
                    child: Tooltip(
                      message: point['name'] as String? ?? 'Drop-off point',
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 48,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        point['name'] as String? ?? 'Drop-off point',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if ((point['approximateLocation'] as String? ?? '')
                          .isNotEmpty)
                        Text(point['approximateLocation']),
                      if ((point['operatingHours'] as String? ?? '').isNotEmpty)
                        Text('Hours: ${point['operatingHours']}'),
                      if (donorLocation != null)
                        Text(
                          _formatDropOffDistance(distance),
                          style: const TextStyle(
                            color: kindLinkEmerald,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorPledgeStatusBadge extends StatelessWidget {
  const _DonorPledgeStatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = _donorPledgeStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Color _donorPledgeStatusColor(String status) => switch (status) {
  'Approved' => kindLinkSuccess,
  'Received' => kindLinkEmerald,
  'Rejected' || 'Cancelled' => Colors.red.shade700,
  _ => kindLinkOrange,
};

IconData _donorPledgeStatusIcon(String status) => switch (status) {
  'Approved' => Icons.check_circle_outline,
  'Received' => Icons.task_alt,
  'Rejected' || 'Cancelled' => Icons.cancel_outlined,
  _ => Icons.schedule_rounded,
};

String _donorPledgeGuidance(String status) => switch (status) {
  'Pending' => 'Waiting for the organization to review your pledged items.',
  'Approved' => 'Your pledge was approved. Choose pickup or drop-off to arrange the handover.',
  'Received' => 'Completed. The organization confirmed the received items.',
  'Rejected' => 'The organization declined this pledge. Its quantities are available again.',
  'Cancelled' =>
    'You cancelled this pledge. Its quantities are available to other donors.',
  _ => 'Track this pledge and its handover progress here.',
};

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.document,
    required this.organization,
    this.user,
    this.onPostReport,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool organization;
  final UserAccount? user;
  final VoidCallback? onPostReport;
  @override
  Widget build(BuildContext context) {
    final data = document.data();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _CampaignItemsPage(
              campaignId: document.id,
              campaign: data,
              organization: organization,
              user: user,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kindLinkEmerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: kindLinkPrimaryDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      data['title'] as String? ?? 'Donation campaign',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 17,
                    color: kindLinkSecondaryText,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                data['organizationName'] as String? ?? 'Organization',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: kindLinkEmerald,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((data['description'] as String? ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  data['description'] as String,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: kindLinkSecondaryText,
                    height: 1.4,
                  ),
                ),
              ],
              if (onPostReport != null) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onPostReport,
                    icon: const Icon(Icons.post_add_outlined, size: 19),
                    label: const Text('Post donation report'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCampaignItemDialog extends StatefulWidget {
  const _AddCampaignItemDialog();

  @override
  State<_AddCampaignItemDialog> createState() => _AddCampaignItemDialogState();
}

class _AddCampaignItemDialogState extends State<_AddCampaignItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController();
  final _condition = TextEditingController(text: 'New or gently used');

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _condition.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, <String, dynamic>{
      'itemName': _name.text.trim(),
      'quantityNeeded': int.parse(_quantity.text.trim()),
      'preferredCondition': _condition.text.trim().isEmpty
          ? 'Any usable condition'
          : _condition.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Add needed item'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Item name'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter an item name'
                  : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Quantity needed'),
              validator: (value) {
                final amount = int.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a quantity greater than zero'
                    : null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _condition,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Preferred condition',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
    ],
  );
}

class _CreateCampaignPage extends StatefulWidget {
  const _CreateCampaignPage({required this.user, required this.organizationId});
  final UserAccount user;
  final String organizationId;
  @override
  State<_CreateCampaignPage> createState() => _CreateCampaignPageState();
}

class _CreateCampaignPageState extends State<_CreateCampaignPage> {
  final _title = TextEditingController();
  final _beneficiaries = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _beneficiaries.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (selected != null && mounted) setState(() => _deadline = selected);
  }

  Future<void> _addItem() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _AddCampaignItemDialog(),
    );
    if (result != null && mounted) {
      setState(() => _items.add(result));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['itemName']} added to campaign.')),
      );
    }
  }

  Future<void> _publish() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a campaign title.')));
      return;
    }
    if (_beneficiaries.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        _deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete the beneficiaries, location, description, and deadline.',
          ),
        ),
      );
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one needed item.')),
      );
      return;
    }
    final verification = await database
        .ref('organizations/${widget.organizationId}/verificationStatus')
        .get();
    if (verification.value != 'verified') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'An admin must verify your organization before you can publish campaigns.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final campaign = firestore.collection('campaigns').doc();
      final batch = firestore.batch();
      batch.set(campaign, {
        'organizationId': widget.organizationId,
        'organizationName': widget.user.organizationName ?? widget.user.name,
        'title': _title.text.trim(),
        'beneficiaries': _beneficiaries.text.trim(),
        'location': _location.text.trim(),
        'description': _description.text.trim(),
        'deadline': Timestamp.fromDate(_deadline!),
        'status': 'published',
        'itemCount': _items.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
      for (final item in _items) {
        final ref = firestore.collection('campaignItems').doc();
        batch.set(ref, {
          ...item,
          'campaignId': campaign.id,
          'quantityReceived': 0,
          'quantityPledged': 0,
          'quantityRemaining': item['quantityNeeded'],
        });
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Campaign published successfully.')),
      );
      Navigator.pop(context);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not publish (${error.code}): ${error.message ?? 'Firestore rejected the campaign.'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish campaign: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create campaign')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            labelText: 'Campaign title',
            prefixIcon: Icon(Icons.campaign_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _beneficiaries,
          decoration: const InputDecoration(
            labelText: 'Beneficiaries',
            prefixIcon: Icon(Icons.groups_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _location,
          decoration: const InputDecoration(
            labelText: 'Location',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDeadline,
          icon: const Icon(Icons.event_outlined),
          label: Text(
            _deadline == null
                ? 'Select deadline'
                : 'Deadline: ${formatPostedDate(_deadline!)}',
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Needed items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ],
        ),
        ..._items.map(
          (item) => ListTile(
            title: Text(item['itemName']),
            subtitle: Text(
              'Need ${item['quantityNeeded']} • ${item['preferredCondition']}',
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving ? null : _publish,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.publish_outlined),
          label: Text(_saving ? 'Publishing...' : 'Publish campaign'),
        ),
      ],
    ),
  );
}

Future<void> _postCampaignDistributionReport(
  BuildContext context,
  String campaignId,
  Map<String, dynamic> campaign,
) async {
  final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || campaign['organizationId'] != uid) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only the campaign organization can post reports.'),
      ),
    );
    return;
  }
  final organizationSnapshot = await database.ref('organizations/$uid').get();
  final organization = organizationSnapshot.value is Map
      ? Map<Object?, Object?>.from(organizationSnapshot.value! as Map)
      : <Object?, Object?>{};
  if (organization['ownerUid'] != uid ||
      organization['verificationStatus'] != 'verified') {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verified organization leader access is required.'),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final summary = TextEditingController();
  final beneficiaries = TextEditingController();
  final distributedItems = TextEditingController();
  final submit = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Post donation report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: beneficiaries,
            decoration: const InputDecoration(
              labelText: 'Beneficiaries reached',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: distributedItems,
            decoration: const InputDecoration(labelText: 'Items distributed'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: summary,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Report summary'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Post report'),
        ),
      ],
    ),
  );
  final beneficiariesValue = beneficiaries.text.trim();
  final distributedItemsValue = distributedItems.text.trim();
  final summaryValue = summary.text.trim();
  beneficiaries.dispose();
  distributedItems.dispose();
  summary.dispose();
  if (submit != true ||
      beneficiariesValue.isEmpty ||
      distributedItemsValue.isEmpty ||
      summaryValue.isEmpty) {
    return;
  }
  final firestore = FirebaseFirestore.instance;
  final batch = firestore.batch();
  batch.set(firestore.collection('campaignReports').doc(), {
    'campaignId': campaignId,
    'organizationId': campaign['organizationId'],
    'campaignTitle': campaign['title'],
    'beneficiariesReached': beneficiariesValue,
    'itemsDistributed': distributedItemsValue,
    'summary': summaryValue,
    'createdAt': FieldValue.serverTimestamp(),
  });
  batch.update(firestore.collection('campaigns').doc(campaignId), {
    'lastDistributionReportAt': FieldValue.serverTimestamp(),
    'distributionReportCount': FieldValue.increment(1),
  });
  await batch.commit();
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Donation report posted.')));
  }
}

class _CampaignItemsPage extends StatelessWidget {
  const _CampaignItemsPage({
    required this.campaignId,
    required this.campaign,
    required this.organization,
    this.user,
  });
  final String campaignId;
  final Map<String, dynamic> campaign;
  final bool organization;
  final UserAccount? user;

  Future<void> _postDistributionReport(BuildContext context) =>
      _postCampaignDistributionReport(context, campaignId, campaign);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(campaign['title'] ?? 'Campaign'),
      actions: [
        if (organization)
          KindLinkPressScale(
            child: IconButton(
              tooltip: 'Post donation report',
              onPressed: () => _postDistributionReport(context),
              icon: const Icon(Icons.post_add_outlined),
            ),
          ),
      ],
    ),
    bottomNavigationBar: organization || user == null
        ? null
        : SafeArea(
            top: false,
            child: Container(
              height: 74,
              color: kindLinkCream,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MultiItemOfferPage(
                        campaignId: campaignId,
                        campaign: campaign,
                        user: user!,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.playlist_add_check, size: 19),
                  label: const Text('Donate multiple'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ),
          ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('campaignItems')
          .where('campaignId', isEqualTo: campaignId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final itemDocs = snapshot.data!.docs;
        final totalNeeded = itemDocs.fold<num>(
          0,
          (total, doc) => total + (doc.data()['quantityNeeded'] as num? ?? 0),
        );
        final totalReceived = itemDocs.fold<num>(
          0,
          (total, doc) =>
              total + _campaignQuantity(doc.data(), 'quantityReceived'),
        );
        final totalPledged = itemDocs.fold<num>(
          0,
          (total, doc) =>
              total + _campaignQuantity(doc.data(), 'quantityPledged'),
        );
        final totalRemaining = itemDocs.fold<num>(
          0,
          (total, doc) => total + _campaignRemaining(doc.data()),
        );
        final deadline = campaign['deadline'] is Timestamp
            ? (campaign['deadline'] as Timestamp).toDate()
            : null;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign['title'] ?? 'Campaign',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Beneficiaries: ${campaign['beneficiaries'] ?? 'Not specified'}',
                    ),
                    Text(
                      'Location: ${campaign['location'] ?? 'Not specified'}',
                    ),
                    if ((campaign['description'] as String? ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(campaign['description']),
                      ),
                    if (deadline != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Deadline: ${formatPostedDate(deadline)}'),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      '${totalReceived.toInt()} of ${totalNeeded.toInt()} items received',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalPledged.toInt()} pledged • ${totalRemaining.toInt()} still needed',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: totalNeeded == 0
                          ? 0
                          : (totalReceived / totalNeeded).clamp(0, 1),
                    ),
                  ],
                ),
              ),
            ),
            ...itemDocs.map((doc) {
              final item = doc.data();
              final needed = item['quantityNeeded'] as num? ?? 0;
              final received = _campaignQuantity(item, 'quantityReceived');
              final pledged = _campaignQuantity(item, 'quantityPledged');
              final remaining = _campaignRemaining(item);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['itemName'] ?? 'Item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${item['preferredCondition'] ?? ''}\n'
                        '$received / ${needed.toInt()} received • '
                        '$pledged pledged • $remaining still needed',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: needed == 0
                            ? 0
                            : (received / needed).clamp(0, 1),
                      ),
                      const SizedBox(height: 10),
                      if (!organization)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: remaining > 0
                                ? () => _offer(context, doc.id, item)
                                : null,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: const StadiumBorder(),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              remaining > 0
                                  ? 'Donate item'
                                  : received >= needed
                                  ? 'Goal reached'
                                  : 'Fully pledged',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            _CampaignReportsSection(campaignId: campaignId),
          ],
        );
      },
    ),
  );

  Future<void> _offer(
    BuildContext context,
    String itemId,
    Map<String, dynamic> item,
  ) async {
    final quantity = TextEditingController();
    final message = TextEditingController();
    String condition = item['preferredCondition'] ?? 'New';
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text('Donate ${item['itemName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity offered',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: condition,
                isExpanded: true,
                items: _donationConditionOptions(condition)
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setDialogState(() => condition = v!),
                decoration: const InputDecoration(labelText: 'Condition'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: message,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Optional message',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    final offered = int.tryParse(quantity.text);
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (submit != true || offered == null || offered <= 0 || uid == null) {
      return;
    }
    final firestore = FirebaseFirestore.instance;
    final donation = firestore.collection('campaignDonations').doc();
    final donationItem = firestore.collection('donationItems').doc();
    final campaignItem = firestore.collection('campaignItems').doc(itemId);
    final notification = firestore.collection('notifications').doc();
    try {
      await firestore.runTransaction((tx) async {
        final snapshot = await tx.get(campaignItem);
        final current = snapshot.data();
        if (current == null) throw Exception('This campaign item was removed.');
        final remaining = _campaignRemaining(current);
        if (offered > remaining) {
          throw Exception('Only $remaining item(s) are still needed.');
        }
        tx.update(campaignItem, {
          'quantityRemaining': remaining - offered,
          'quantityPledged':
              _campaignQuantity(current, 'quantityPledged') + offered,
        });
        tx.set(donation, {
          'donorId': uid,
          'donorName': user?.name,
          'organizationId': campaign['organizationId'],
          'campaignId': campaignId,
          'campaignTitle': campaign['title'],
          'itemCount': 1,
          'status': 'Pending',
          'message': message.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(donationItem, {
          'donationId': donation.id,
          'campaignItemId': itemId,
          'itemName': item['itemName'],
          'quantityOffered': offered,
          'quantityReceived': 0,
          'condition': condition,
        });
        tx.set(notification, {
          'recipientId': campaign['organizationId'],
          'type': 'campaignPledge',
          'campaignId': campaignId,
          'donationId': donation.id,
          'title': 'New donation pledge',
          'message': '${user?.name ?? 'A donor'} pledged ${item['itemName']}.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pledge submitted. The organization will review it before handover.',
          ),
        ),
      );
    }
  }
}

class _CampaignReportsSection extends StatelessWidget {
  const _CampaignReportsSection({required this.campaignId});
  final String campaignId;

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('campaignReports')
            .where('campaignId', isEqualTo: campaignId)
            .snapshots(),
        builder: (context, snapshot) {
          final reports = snapshot.data?.docs ?? [];
          if (reports.isEmpty) return const SizedBox.shrink();
          reports.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
              aTime?.millisecondsSinceEpoch ?? 0,
            );
          });
          return Card(
            margin: const EdgeInsets.only(top: 4, bottom: 90),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Donation reports',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...reports.map((report) {
                    final data = report.data();
                    final createdAt = data['createdAt'] as Timestamp?;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['summary'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Beneficiaries: ${data['beneficiariesReached']}',
                          ),
                          Text('Items: ${data['itemsDistributed']}'),
                          if (createdAt != null)
                            Text(
                              formatPostedDate(createdAt.toDate()),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      );
}

class _MultiItemOfferPage extends StatefulWidget {
  const _MultiItemOfferPage({
    required this.campaignId,
    required this.campaign,
    required this.user,
  });
  final String campaignId;
  final Map<String, dynamic> campaign;
  final UserAccount user;
  @override
  State<_MultiItemOfferPage> createState() => _MultiItemOfferPageState();
}

class _MultiItemOfferPageState extends State<_MultiItemOfferPage> {
  final Map<String, int> _quantities = {};
  final Map<String, String> _conditions = {};
  final _message = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  ) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    final selected = items
        .where((doc) => (_quantities[doc.id] ?? 0) > 0)
        .toList();
    if (uid == null || selected.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final donation = firestore.collection('campaignDonations').doc();
      final notification = firestore.collection('notifications').doc();
      await firestore.runTransaction((tx) async {
        final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final item in selected) {
          snapshots[item.id] = await tx.get(item.reference);
        }
        for (final item in selected) {
          final current = snapshots[item.id]!.data()!;
          final offered = _quantities[item.id]!;
          final remaining = _campaignRemaining(current);
          if (offered > remaining) {
            throw Exception(
              '${current['itemName']} only has $remaining remaining.',
            );
          }
        }
        tx.set(donation, {
          'donorId': uid,
          'donorName': widget.user.name,
          'organizationId': widget.campaign['organizationId'],
          'campaignId': widget.campaignId,
          'campaignTitle': widget.campaign['title'],
          'itemCount': selected.length,
          'status': 'Pending',
          'message': _message.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
        tx.set(notification, {
          'recipientId': widget.campaign['organizationId'],
          'type': 'campaignPledge',
          'campaignId': widget.campaignId,
          'donationId': donation.id,
          'title': 'New donation pledge',
          'message':
              '${widget.user.name} pledged ${selected.length} item types.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
        for (final item in selected) {
          final data = snapshots[item.id]!.data()!;
          final offered = _quantities[item.id]!;
          final remaining = _campaignRemaining(data);
          tx.update(item.reference, {
            'quantityRemaining': remaining - offered,
            'quantityPledged':
                _campaignQuantity(data, 'quantityPledged') + offered,
          });
          tx.set(firestore.collection('donationItems').doc(), {
            'donationId': donation.id,
            'campaignItemId': item.id,
            'itemName': data['itemName'],
            'quantityOffered': offered,
            'quantityReceived': 0,
            'condition':
                _conditions[item.id] ?? data['preferredCondition'] ?? 'New',
          });
        }
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} items submitted in one donation request.',
          ),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Build your donation')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('campaignItems')
          .where('campaignId', isEqualTo: widget.campaignId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.docs
            .where((doc) => _campaignRemaining(doc.data()) > 0)
            .toList();
        final selectedCount = items
            .where((doc) => (_quantities[doc.id] ?? 0) > 0)
            .length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            Text(
              widget.campaign['title'] ?? 'Campaign',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose one or more needed items and enter how many you can give.',
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline, color: kindLinkEmerald),
                      SizedBox(height: 8),
                      Text(
                        'All items are currently received or pledged.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Items become available again if a pledge is declined or fewer items are received.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ...items.map((doc) {
              final item = doc.data();
              final remaining = _campaignRemaining(item);
              final selected = (_quantities[doc.id] ?? 0) > 0;
              final selectedCondition =
                  _conditions[doc.id] ??
                  item['preferredCondition'] as String? ??
                  'New';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: selected,
                        title: Text(
                          item['itemName'] ?? 'Item',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$remaining still needed'),
                        onChanged: (value) => setState(
                          () => value == true
                              ? _quantities[doc.id] = 1
                              : _quantities.remove(doc.id),
                        ),
                      ),
                      if (selected) ...[
                        TextFormField(
                          initialValue: '${_quantities[doc.id]}',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity offered',
                            prefixIcon: Icon(Icons.numbers),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            final quantity = int.tryParse(value) ?? 0;
                            setState(() {
                              _quantities[doc.id] = quantity.clamp(
                                0,
                                remaining,
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCondition,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Condition',
                          ),
                          items: _donationConditionOptions(selectedCondition)
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => _conditions[doc.id] = value!,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
            TextField(
              controller: _message,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Message to organization (optional)',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || selectedCount == 0
                  ? null
                  : () => _submit(items),
              icon: const Icon(Icons.send_outlined),
              label: Text(
                _saving
                    ? 'Submitting...'
                    : selectedCount == 0
                    ? 'Select items to donate'
                    : 'Submit $selectedCount item type${selectedCount == 1 ? '' : 's'}',
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _OrganizationOffersPage extends StatelessWidget {
  const _OrganizationOffersPage({required this.organizationId});
  final String organizationId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Donation requests')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('campaignDonations')
          .where('organizationId', isEqualTo: organizationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snapshot.data!.docs.where((doc) {
              final status = doc.data()['status'] as String? ?? 'Pending';
              return status == 'Pending' || status == 'Approved';
            }).toList()..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                aTime?.millisecondsSinceEpoch ?? 0,
              );
            });
        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No active donation requests. Completed and declined donations are removed from this queue.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: docs.map((doc) {
            return _OrganizationDonationCard(
              donation: doc,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _OrganizationOfferDetailsPage(
                    donation: doc,
                    onStatus: (status) => _changeStatus(context, doc, status),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );

  Future<void> _changeStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> donation,
    String status,
  ) async {
    final currentStatus = donation.data()['status'] as String? ?? 'Pending';
    final validTransition = switch ((currentStatus, status)) {
      ('Pending', 'Approved') ||
      ('Pending', 'Rejected') ||
      ('Approved', 'Rejected') ||
      ('Approved', 'Received') => true,
      _ => false,
    };
    if (!validTransition) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'This donation cannot move from $currentStatus to $status.',
            ),
          ),
        );
      }
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final items = await firestore
        .collection('donationItems')
        .where('donationId', isEqualTo: donation.id)
        .get();

    if (status == 'Rejected') {
      await firestore.runTransaction((tx) async {
        final latestDonation = await tx.get(donation.reference);
        final latestStatus = latestDonation.data()?['status'] as String?;
        if (latestStatus != 'Pending' && latestStatus != 'Approved') {
          throw Exception('This donation was already updated.');
        }
        final campaignSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final item in items.docs) {
          final campaignItem = firestore
              .collection('campaignItems')
              .doc(item.data()['campaignItemId'] as String);
          campaignSnapshots[item.id] = await tx.get(campaignItem);
        }
        for (final item in items.docs) {
          final data = item.data();
          final offered = _campaignQuantity(data, 'quantityOffered');
          final snapshot = campaignSnapshots[item.id]!;
          final current = snapshot.data();
          if (current == null) continue;
          final needed = _campaignQuantity(current, 'quantityNeeded');
          final received = _campaignQuantity(current, 'quantityReceived');
          tx.update(snapshot.reference, {
            'quantityRemaining': min(
              max(0, needed - received),
              _campaignRemaining(current) + offered,
            ),
            'quantityPledged': max(
              0,
              _campaignQuantity(current, 'quantityPledged') - offered,
            ),
          });
        }
        tx.update(donation.reference, {
          'status': 'Rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      });
    } else if (status == 'Approved') {
      await donation.reference.update({
        'status': 'Approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final confirmedQuantities = <String, int>{};
      for (final donationItem in items.docs) {
        final data = donationItem.data();
        final offered = _campaignQuantity(data, 'quantityOffered');
        final controller = TextEditingController(text: '$offered');
        if (!context.mounted) return;
        final confirmed = await showDialog<int>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text('Actually received: ${data['itemName']}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(helperText: 'Offered: $offered'),
            ),
            actions: [
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, int.tryParse(controller.text)),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        controller.dispose();
        if (confirmed == null) return;
        if (confirmed < 0 || confirmed > offered) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Enter a quantity from 0 to $offered.')),
            );
          }
          return;
        }
        confirmedQuantities[donationItem.id] = confirmed;
      }

      await firestore.runTransaction((tx) async {
        final latestDonation = await tx.get(donation.reference);
        if (latestDonation.data()?['status'] != 'Approved') {
          throw Exception('This donation is no longer awaiting receipt.');
        }
        final campaignSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final item in items.docs) {
          final campaignItem = firestore
              .collection('campaignItems')
              .doc(item.data()['campaignItemId'] as String);
          campaignSnapshots[item.id] = await tx.get(campaignItem);
        }
        for (final item in items.docs) {
          final data = item.data();
          final offered = _campaignQuantity(data, 'quantityOffered');
          final confirmed = confirmedQuantities[item.id]!;
          final snapshot = campaignSnapshots[item.id]!;
          final current = snapshot.data();
          if (current == null) continue;
          tx.update(snapshot.reference, {
            'quantityReceived':
                _campaignQuantity(current, 'quantityReceived') + confirmed,
            'quantityRemaining': max(
              0,
              _campaignRemaining(current) + offered - confirmed,
            ),
            'quantityPledged': max(
              0,
              _campaignQuantity(current, 'quantityPledged') - offered,
            ),
          });
          tx.update(item.reference, {'quantityReceived': confirmed});
        }
        tx.update(donation.reference, {
          'status': 'Received',
          'receivedAt': FieldValue.serverTimestamp(),
        });
      });
    }

    final donorId = donation.data()['donorId'] as String?;
    if (donorId != null) {
      try {
        await firestore.collection('notifications').add({
          'recipientId': donorId,
          'type': 'campaignDonationStatus',
          'campaignId': donation.data()['campaignId'],
          'donationId': donation.id,
          'title': 'Donation $status',
          'message': status == 'Approved'
              ? 'Your pledge was approved. Choose drop-off or pickup next.'
              : status == 'Received'
              ? 'The organization confirmed your donated items.'
              : 'The organization declined your pledge. The items are needed again.',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException {
        // The quantity/status update is authoritative even if notification
        // delivery is temporarily unavailable.
      }
    }
  }
}

class _OrganizationDonationCard extends StatelessWidget {
  const _OrganizationDonationCard({
    required this.donation,
    required this.onTap,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> donation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final data = donation.data();
    final donorName = data['donorName'] as String? ?? 'Community donor';
    final status = data['status'] as String? ?? 'Pending';
    final approved = status == 'Approved';
    final statusColor = approved ? kindLinkSuccess : kindLinkOrange;
    final message = (data['message'] as String? ?? '').trim();
    final campaignTitle = (data['campaignTitle'] as String? ?? '').trim();
    final createdAt = data['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: kindLinkEmerald.withValues(alpha: 0.12),
                    child: Text(
                      donorName.isEmpty ? '?' : donorName[0].toUpperCase(),
                      style: const TextStyle(
                        color: kindLinkPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${data['itemCount'] ?? 1} item type${data['itemCount'] == 1 ? '' : 's'}'
                          '${createdAt == null ? '' : ' • ${formatPostedDate(createdAt.toDate())}'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          approved
                              ? Icons.check_circle_outline
                              : Icons.schedule_rounded,
                          size: 15,
                          color: statusColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (campaignTitle.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: kindLinkEmerald,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        campaignTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Text(
                _organizationDonationGuidance(
                  status,
                  data['handoverMethod'] as String?,
                ),
                style: const TextStyle(color: kindLinkSecondaryText),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: kindLinkCream,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '“$message”',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kindLinkSecondaryText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View details',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrganizationOfferDetailsPage extends StatelessWidget {
  const _OrganizationOfferDetailsPage({
    required this.donation,
    required this.onStatus,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> donation;
  final Future<void> Function(String) onStatus;

  @override
  Widget build(BuildContext context) {
    final data = donation.data();
    return Scaffold(
      appBar: AppBar(title: const Text('Donation details')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('donationItems')
            .where('donationId', isEqualTo: donation.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                data['donorName'] ?? 'Donor',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Status: ${data['status']}',
                style: const TextStyle(
                  color: kindLinkEmerald,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (data['handoverMethod'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Handover: ${data['handoverMethod']}'),
                ),
              if (data['handoverMethod'] == 'Drop-off' &&
                  data['dropOffPointName'] != null)
                Card(
                  margin: const EdgeInsets.only(top: 10),
                  child: ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: kindLinkEmerald,
                    ),
                    title: Text(data['dropOffPointName']),
                    subtitle: Text(
                      [
                        data['dropOffPointLocation'],
                        if (data['dropOffPointHours'] != null)
                          'Hours: ${data['dropOffPointHours']}',
                      ].whereType<String>().join('\n'),
                    ),
                    trailing:
                        data['dropOffPointLatitude'] is num &&
                            data['dropOffPointLongitude'] is num
                        ? IconButton(
                            tooltip: 'View on map',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _DropOffPointMapPage(
                                  point: {
                                    'name': data['dropOffPointName'],
                                    'approximateLocation':
                                        data['dropOffPointLocation'],
                                    'operatingHours': data['dropOffPointHours'],
                                    'latitude': data['dropOffPointLatitude'],
                                    'longitude': data['dropOffPointLongitude'],
                                  },
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.map_outlined),
                          )
                        : null,
                  ),
                ),
              if ((data['message'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Message: ${data['message']}'),
                ),
              const SizedBox(height: 12),
              Card(
                color: kindLinkEmerald.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.route_outlined, color: kindLinkEmerald),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _organizationDonationGuidance(
                            data['status'] as String? ?? 'Pending',
                            data['handoverMethod'] as String?,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Items offered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...snapshot.data!.docs.map((item) {
                final value = item.data();
                final offered = _campaignQuantity(value, 'quantityOffered');
                final received = _campaignQuantity(value, 'quantityReceived');
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.inventory_2_outlined),
                    ),
                    title: Text(value['itemName'] ?? 'Item'),
                    subtitle: Text(
                      'Pledged: $offered\n'
                      'Confirmed received: $received\n'
                      'Condition: ${value['condition']}',
                    ),
                    isThreeLine: true,
                  ),
                );
              }),
              const SizedBox(height: 18),
              if (data['status'] == 'Pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await onStatus('Rejected');
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await onStatus('Approved');
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              if (data['status'] == 'Approved' &&
                  data['handoverMethod'] == null)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'The donor has not selected drop-off or pickup yet. If the items were handed over directly, you can still confirm them below.',
                    ),
                  ),
                ),
              if (data['status'] == 'Approved')
                FilledButton.icon(
                  onPressed: () async {
                    await onStatus('Received');
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.inventory),
                  label: Text(
                    data['handoverMethod'] == null
                        ? 'Confirm direct receipt'
                        : 'Confirm received items',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
