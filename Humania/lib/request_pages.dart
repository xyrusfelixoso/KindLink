part of 'main.dart';

class _RequestHelpPage extends StatefulWidget {
  const _RequestHelpPage({required this.user});
  final UserAccount user;

  @override
  State<_RequestHelpPage> createState() => _RequestHelpPageState();
}

class _RequestHelpPageState extends State<_RequestHelpPage> {
  final _title = TextEditingController();
  final _beneficiaries = TextEditingController();
  final _description = TextEditingController();
  final _itemName = TextEditingController();
  final _itemQuantity = TextEditingController();
  final List<Map<String, dynamic>> _neededItems = [];
  String _itemUnit = 'pcs';
  LatLng? _point;
  final List<Map<String, String>> _organizations = [];
  String? _selectedOrganizationId;
  String? _organizationMessage;
  bool _loadingOrganization = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadJoinedOrganization();
  }

  Future<void> _loadJoinedOrganization() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loadingOrganization = false;
          _organizationMessage = 'Sign in to submit a help request.';
        });
      }
      return;
    }

    try {
      final profileSnapshot = await database.ref('users/$uid').get();
      final profile = profileSnapshot.value is Map
          ? Map<Object?, Object?>.from(profileSnapshot.value! as Map)
          : <Object?, Object?>{};
      var organizationId = profile['organizationId'] as String?;

      // Existing organization owners may predate organizationId being saved
      // on their user profile, so recognize an organization owned by the uid.
      if (organizationId == null || organizationId.isEmpty) {
        final ownedSnapshot = await database.ref('organizations/$uid').get();
        final owned = ownedSnapshot.value is Map
            ? Map<Object?, Object?>.from(ownedSnapshot.value! as Map)
            : <Object?, Object?>{};
        if (owned['ownerUid'] == uid) organizationId = uid;
      }

      if (organizationId == null || organizationId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loadingOrganization = false;
          _organizationMessage =
              'Join a verified organization before submitting a request.';
        });
        return;
      }

      final organizationSnapshot = await database
          .ref('organizations/$organizationId')
          .get();
      final organization = organizationSnapshot.value is Map
          ? Map<Object?, Object?>.from(organizationSnapshot.value! as Map)
          : <Object?, Object?>{};
      if (organization['verificationStatus'] != 'verified') {
        if (!mounted) return;
        setState(() {
          _loadingOrganization = false;
          _organizationMessage = 'Your organization must be verified before it can review requests.';
        });
        return;
      }

      final joinedOrganization = {
        'id': organizationId,
        'name': organization['name'] as String? ?? 'Organization',
      };
      if (!mounted) return;
      setState(() {
        _organizations
          ..clear()
          ..add(joinedOrganization);
        _selectedOrganizationId = organizationId;
        _organizationMessage = null;
        _loadingOrganization = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _loadingOrganization = false;
        _organizationMessage = 'Unable to load your joined organization.';
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _beneficiaries,
      _description,
      _itemName,
      _itemQuantity,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addNeededItem() {
    final quantity = int.tryParse(_itemQuantity.text.trim());
    if (_itemName.text.trim().isEmpty || quantity == null || quantity <= 0) {
      return;
    }
    setState(() {
      _neededItems.add({
        'name': _itemName.text.trim(),
        'quantityNeeded': quantity,
        'quantityPledged': 0,
        'quantityReceived': 0,
        'unit': _itemUnit,
      });
      _itemName.clear();
      _itemQuantity.clear();
    });
  }

  Future<void> _pickLocation() async {
    final point = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => const _DonationLocationPicker(
          title: 'Select request location',
          instruction: 'Tap the map to place the help-request pin.',
        ),
      ),
    );
    if (point != null && mounted) setState(() => _point = point);
  }

  Future<void> _submit() async {
    if (_selectedOrganizationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _organizationMessage ??
                'Join a verified organization before submitting a request.',
          ),
        ),
      );
      return;
    }
    if (_saving ||
        _title.text.trim().isEmpty ||
        _beneficiaries.text.trim().isEmpty ||
        _description.text.trim().isEmpty ||
        _neededItems.isEmpty ||
        _point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete all fields and select a map location.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
      final selectedOrganization = _organizations.firstWhere(
        (organization) => organization['id'] == _selectedOrganizationId,
      );
      final totalNeeded = _neededItems.fold<int>(
        0,
        (total, item) => total + (item['quantityNeeded'] as int),
      );
      await FirebaseFirestore.instance.collection('helpRequests').add({
        'requesterId': uid,
        'requesterName': widget.user.name,
        'requesterUsername': widget.user.username,
        'title': _title.text.trim(),
        'beneficiaries': _beneficiaries.text.trim(),
        'location': 'Pinned map location',
        'description': _description.text.trim(),
        'items': _neededItems,
        'neededItems': _neededItems
            .map(
              (item) =>
                  '${item['name']} - ${item['quantityNeeded']} ${item['unit']}',
            )
            .join('\n'),
        'reviewOrganizationId': _selectedOrganizationId,
        'reviewOrganizationName': selectedOrganization['name'],
        if (_point != null) 'latitude': _point!.latitude,
        if (_point != null) 'longitude': _point!.longitude,
        'quantityNeeded': totalNeeded,
        'quantityReceived': 0,
        // verificationStatus is retained for older app builds and queries.
        'verificationStatus': 'pending',
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      for (final controller in [_title, _beneficiaries, _description]) {
        controller.clear();
      }
      setState(() {
        _point = null;
        _neededItems.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted for organization/admin review.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
    children: [
      Text(
        'Request help',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(color: kindLinkPrimaryDark, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text(
        'Requests are reviewed before they appear publicly on the map.',
      ),
      const SizedBox(height: 6),
      Text(
        'Requesting as ${widget.user.name} (@${widget.user.username})',
        style: const TextStyle(
          color: kindLinkEmerald,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Request title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _beneficiaries,
                decoration: const InputDecoration(labelText: 'Beneficiaries'),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Organization to review this request',
                  prefixIcon: Icon(Icons.apartment_outlined),
                ),
                child: _loadingOrganization
                    ? const LinearProgressIndicator()
                    : Text(
                        _organizations.isNotEmpty
                            ? _organizations.single['name']!
                            : _organizationMessage ?? 'No organization joined',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _organizations.isEmpty
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _itemName,
                decoration: const InputDecoration(
                  labelText: 'Needed item',
                  hintText: 'Rice, water, clothes, hygiene kits...',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _itemQuantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _itemUnit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: const ['pcs', 'kg', 'sets', 'packs', 'bottles']
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _itemUnit = value ?? 'pcs'),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _addNeededItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ),
              ..._neededItems.asMap().entries.map(
                (entry) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(entry.value['name']),
                  subtitle: Text(
                    '${entry.value['quantityNeeded']} ${entry.value['unit']}',
                  ),
                  trailing: IconButton(
                    onPressed: () =>
                        setState(() => _neededItems.removeAt(entry.key)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: Icon(
                  _point == null ? Icons.add_location_alt : Icons.check,
                ),
                label: Text(
                  _point == null
                      ? 'Select location on map'
                      : 'Change selected location',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.verified_user_outlined),
                label: Text(_saving ? 'Submitting...' : 'Submit for review'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _HelpRequestDetailsPage extends StatelessWidget {
  const _HelpRequestDetailsPage({required this.document});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;

  Future<void> _help(BuildContext context) async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final requestData = document.data();
    final items = (requestData['items'] as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    if (items.isEmpty) return;
    var selectedIndex = 0;
    var handover = 'Drop-off';
    final quantity = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const Text('Offer items'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedIndex,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Item'),
                items: items.asMap().entries.map((entry) {
                  final remaining =
                      (entry.value['quantityNeeded'] as num? ?? 0).toInt() -
                      (entry.value['quantityReceived'] as num? ?? 0).toInt() -
                      (entry.value['quantityPledged'] as num? ?? 0).toInt();
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Text(
                      '${entry.value['name']} ($remaining ${entry.value['unit']} left)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setDialogState(() => selectedIndex = value ?? 0),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: handover,
                decoration: const InputDecoration(labelText: 'Delivery method'),
                items: const ['Drop-off', 'Direct handover']
                    .map(
                      (method) =>
                          DropdownMenuItem(value: method, child: Text(method)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setDialogState(() => handover = value ?? 'Drop-off'),
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
              child: const Text('Send pledge'),
            ),
          ],
        ),
      ),
    );
    final offered = int.tryParse(quantity.text.trim());
    if (submitted != true || offered == null || offered <= 0) return;
    final firestore = FirebaseFirestore.instance;
    final offer = firestore.collection('helpOffers').doc();
    final notification = firestore.collection('notifications').doc();
    final confirmationCode = List.generate(
      6,
      (_) => 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[Random.secure().nextInt(32)],
    ).join();
    await firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(document.reference);
      final current = requestSnapshot.data()!;
      final currentItems = (current['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final item = currentItems[selectedIndex];
      final remaining =
          (item['quantityNeeded'] as num).toInt() -
          (item['quantityReceived'] as num? ?? 0).toInt() -
          (item['quantityPledged'] as num? ?? 0).toInt();
      if (offered > remaining) {
        throw Exception('Only $remaining remain needed.');
      }
      item['quantityPledged'] =
          (item['quantityPledged'] as num? ?? 0).toInt() + offered;
      transaction.update(document.reference, {'items': currentItems});
      transaction.set(offer, {
        'helpRequestId': document.id,
        'requestTitle': current['title'],
        'requesterId': current['requesterId'],
        'donorId': uid,
        'donorName':
            firebase_auth.FirebaseAuth.instance.currentUser?.displayName,
        'itemIndex': selectedIndex,
        'itemName': item['name'],
        'unit': item['unit'],
        'quantity': offered,
        'handoverMethod': handover,
        'confirmationCode': confirmationCode,
        'status': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notification, {
        'recipientId': current['requesterId'],
        'type': 'helpPledge',
        'title': 'New help pledge',
        'message': '${item['name']}: $offered ${item['unit']}',
        'helpRequestId': document.id,
        'offerId': offer.id,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pledge sent. Delivery confirmation code: $confirmationCode',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final needed = (data['quantityNeeded'] as num? ?? 0).toDouble();
    final received = (data['quantityReceived'] as num? ?? 0).toDouble();
    final progress = needed <= 0 ? 0.0 : (received / needed).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Verified need')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['title'] ?? 'Needs help',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Requested by ${data['requesterName'] ?? 'Community member'}'
                    '${data['requesterUsername'] == null ? '' : ' (@${data['requesterUsername']})'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(data['location'] ?? ''),
                  const SizedBox(height: 12),
                  Text(data['description'] ?? ''),
                  const SizedBox(height: 16),
                  const Text(
                    'Items needed',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (data['items'] is List)
                    ...(data['items'] as List).whereType<Map>().map((raw) {
                      final item = Map<String, dynamic>.from(raw);
                      final needed = (item['quantityNeeded'] as num? ?? 0)
                          .toInt();
                      final received = (item['quantityReceived'] as num? ?? 0)
                          .toInt();
                      final pledged = (item['quantityPledged'] as num? ?? 0)
                          .toInt();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item['name'] ?? 'Item'),
                        subtitle: Text(
                          '$received received, $pledged pledged, ${max(0, needed - received - pledged)} ${item['unit']} still needed',
                        ),
                      );
                    })
                  else
                    Text(data['neededItems'] ?? ''),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text('${(progress * 100).round()}% fulfilled'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _help(context),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Text('I want to help'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpRequestModerationPage extends StatelessWidget {
  const _HelpRequestModerationPage({this.organizationId});
  final String? organizationId;

  Future<Map<String, String?>> _authorizedReviewer() async {
    final currentUser = firebase_auth.FirebaseAuth.instance.currentUser;
    final uid = currentUser?.uid;
    if (uid == null) throw Exception('Sign in is required.');
    final hasAdminFlag =
        (await database.ref('users/$uid/isAdmin').get()).value == true;
    if (hasAdminFlag || isDesignatedAdminEmail(currentUser?.email)) {
      return {'uid': uid, 'organizationId': null, 'role': 'admin'};
    }
    final organizationSnapshot = await database.ref('organizations/$uid').get();
    final organization = organizationSnapshot.value is Map
        ? Map<Object?, Object?>.from(organizationSnapshot.value! as Map)
        : <Object?, Object?>{};
    final isVerifiedLeader =
        organization['ownerUid'] == uid &&
        organization['verificationStatus'] == 'verified';
    if (!isVerifiedLeader) {
      throw Exception(
        'Only a verified organization leader can review requests.',
      );
    }
    return {'uid': uid, 'organizationId': uid, 'role': 'organizationLeader'};
  }

  Future<void> _review(String id, String status) async {
    final reviewer = await _authorizedReviewer();
    final request = await FirebaseFirestore.instance
        .collection('helpRequests')
        .doc(id)
        .get();
    if (reviewer['role'] == 'organizationLeader' &&
        request.data()?['reviewOrganizationId'] != reviewer['organizationId']) {
      throw Exception('This request belongs to another organization.');
    }
    final lifecycleStatus = status == 'verified' ? 'Approved' : 'Rejected';
    await FirebaseFirestore.instance.collection('helpRequests').doc(id).update({
      'verificationStatus': status,
      'status': lifecycleStatus,
      'verifiedBy': reviewer['uid'],
      'reviewedByRole': reviewer['role'],
      if (reviewer['organizationId'] != null)
        'reviewOrganizationId': reviewer['organizationId'],
      'verifiedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _markFulfilled(String id) async {
    final reviewer = await _authorizedReviewer();
    final request = await FirebaseFirestore.instance
        .collection('helpRequests')
        .doc(id)
        .get();
    if (reviewer['role'] == 'organizationLeader' &&
        request.data()?['reviewOrganizationId'] != reviewer['organizationId']) {
      throw Exception('This request belongs to another organization.');
    }
    await FirebaseFirestore.instance.collection('helpRequests').doc(id).update({
      'status': 'Fulfilled',
      'fulfilledBy': reviewer['uid'],
      'fulfilledAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help request verification')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: organizationId == null
          ? FirebaseFirestore.instance.collection('helpRequests').snapshots()
          : FirebaseFirestore.instance
                .collection('helpRequests')
                .where('reviewOrganizationId', isEqualTo: organizationId)
                .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No requests to review.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final status = data['verificationStatus'] ?? 'pending';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Help request',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'By ${data['requesterName'] ?? 'Community member'}'
                      '${data['requesterUsername'] == null ? '' : ' (@${data['requesterUsername']})'}',
                    ),
                    Text(data['location'] ?? ''),
                    if (data['reviewOrganizationName'] != null)
                      Text('Organization: ${data['reviewOrganizationName']}'),
                    Text(data['neededItems'] ?? ''),
                    Chip(label: Text(status.toString().toUpperCase())),
                    if (status == 'pending')
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _review(doc.id, 'rejected'),
                            child: const Text('Reject'),
                          ),
                          FilledButton(
                            onPressed: () => _review(doc.id, 'verified'),
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    if (status == 'verified' &&
                        _requestStatus(data) != 'Fulfilled')
                      OutlinedButton.icon(
                        onPressed: () => _markFulfilled(doc.id),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Mark fulfilled'),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _MyHelpDonationsPage extends StatelessWidget {
  const _MyHelpDonationsPage();

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My help donations')),
      body: uid == null
          ? const Center(child: Text('Sign in to view donations.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('helpOffers')
                  .where('donorId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No help pledges yet.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.volunteer_activism_outlined),
                        ),
                        title: Text(data['requestTitle'] ?? 'Help request'),
                        subtitle: Text(
                          '${data['itemName']}: ${data['quantity']} ${data['unit']}\n'
                          '${data['handoverMethod']} - ${data['status']}\n'
                          'Confirmation code: ${data['confirmationCode']}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

class _MyHelpRequestsPage extends StatelessWidget {
  const _MyHelpRequestsPage();

  Future<void> _setOfferStatus(
    DocumentReference<Map<String, dynamic>> reference,
    String status,
  ) => reference.update({
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<void> _confirmDelivery(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> offer,
  ) async {
    final code = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm received goods'),
        content: TextField(
          controller: code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Confirmation code'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (submit != true) return;
    final firestore = FirebaseFirestore.instance;
    await firestore.runTransaction((transaction) async {
      final offerSnapshot = await transaction.get(offer.reference);
      final offerData = offerSnapshot.data()!;
      if (code.text.trim().toUpperCase() != offerData['confirmationCode']) {
        throw Exception('Incorrect confirmation code.');
      }
      final requestReference = firestore
          .collection('helpRequests')
          .doc(offerData['helpRequestId']);
      final requestSnapshot = await transaction.get(requestReference);
      final request = requestSnapshot.data()!;
      final items = (request['items'] as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      final index = (offerData['itemIndex'] as num).toInt();
      final quantity = (offerData['quantity'] as num).toInt();
      final item = items[index];
      item['quantityPledged'] = max(
        0,
        (item['quantityPledged'] as num? ?? 0).toInt() - quantity,
      );
      item['quantityReceived'] =
          (item['quantityReceived'] as num? ?? 0).toInt() + quantity;
      final received = items.fold<int>(
        0,
        (total, value) =>
            total + (value['quantityReceived'] as num? ?? 0).toInt(),
      );
      final needed = items.fold<int>(
        0,
        (total, value) =>
            total + (value['quantityNeeded'] as num? ?? 0).toInt(),
      );
      transaction.update(requestReference, {
        'items': items,
        'quantityReceived': received,
        if (received >= needed) 'status': 'Fulfilled',
      });
      transaction.update(offer.reference, {
        'status': 'Received',
        'receivedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(firestore.collection('notifications').doc(), {
        'recipientId': offerData['donorId'],
        'type': 'deliveryConfirmed',
        'title': 'Donation received',
        'message': '${offerData['itemName']} was confirmed as received.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation confirmed as received.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My help requests')),
      body: uid == null
          ? const Center(child: Text('Sign in to view requests.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('helpRequests')
                  .where('requesterId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No help requests yet.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: snapshot.data!.docs.map((request) {
                    final data = request.data();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['title'] ?? 'Help request',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Review: ${data['verificationStatus']} - Status: ${data['status']}',
                            ),
                            const SizedBox(height: 8),
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('helpOffers')
                                  .where('helpRequestId', isEqualTo: request.id)
                                  .snapshots(),
                              builder: (context, offersSnapshot) {
                                final offers = offersSnapshot.data?.docs ?? [];
                                if (offers.isEmpty) {
                                  return const Text('No pledges yet.');
                                }
                                return Column(
                                  children: offers.map((offer) {
                                    final value = offer.data();
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${value['itemName']}: ${value['quantity']} ${value['unit']}',
                                      ),
                                      subtitle: Text(
                                        '${value['handoverMethod']} - ${value['status']}',
                                      ),
                                      trailing: value['status'] == 'Pending'
                                          ? PopupMenuButton<String>(
                                              onSelected: (status) =>
                                                  _setOfferStatus(
                                                    offer.reference,
                                                    status,
                                                  ),
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'Accepted',
                                                  child: Text('Accept'),
                                                ),
                                                PopupMenuItem(
                                                  value: 'Cancelled',
                                                  child: Text('Decline'),
                                                ),
                                              ],
                                            )
                                          : value['status'] == 'Accepted'
                                          ? TextButton(
                                              onPressed: () => _confirmDelivery(
                                                context,
                                                offer,
                                              ),
                                              child: const Text('Confirm'),
                                            )
                                          : null,
                                    );
                                  }).toList(),
                                );
                              },
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
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: uid == null
          ? const Center(child: Text('Sign in to view notifications.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('recipientId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                docs.sort((a, b) {
                  final aTime = a.data()['createdAt'] as Timestamp?;
                  final bTime = b.data()['createdAt'] as Timestamp?;
                  return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                    aTime?.millisecondsSinceEpoch ?? 0,
                  );
                });
                if (docs.isEmpty) {
                  return const Center(child: Text('No notifications yet.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: docs.map((doc) {
                    final data = doc.data();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          data['read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: kindLinkEmerald,
                        ),
                        title: Text(data['title'] ?? 'Update'),
                        subtitle: Text(data['message'] ?? ''),
                        onTap: () => doc.reference.update({'read': true}),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}

class _DropOffPointsPage extends StatefulWidget {
  const _DropOffPointsPage({required this.organizationId});
  final String organizationId;

  @override
  State<_DropOffPointsPage> createState() => _DropOffPointsPageState();
}

class _DropOffPointsPageState extends State<_DropOffPointsPage> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _hours = TextEditingController();
  final _items = TextEditingController();
  DateTime? _opens;
  DateTime? _closes;
  LatLng? _point;

  @override
  void dispose() {
    for (final value in [_name, _location, _hours, _items]) {
      value.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(bool opening) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDate: opening
          ? (_opens ?? DateTime.now())
          : (_closes ?? DateTime.now()),
    );
    if (value != null) {
      setState(() => opening ? _opens = value : _closes = value);
    }
  }

  Future<void> _pickPoint() async {
    final value = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => const _DonationLocationPicker(
          title: 'Select drop-off point',
          instruction: 'Tap the verified collection-point location.',
        ),
      ),
    );
    if (value != null) setState(() => _point = value);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty ||
        _location.text.trim().isEmpty ||
        _hours.text.trim().isEmpty ||
        _items.text.trim().isEmpty ||
        _opens == null ||
        _closes == null ||
        _point == null) {
      return;
    }
    final organization = await database
        .ref('organizations/${widget.organizationId}')
        .get();
    final data = Map<Object?, Object?>.from(organization.value as Map);
    if (data['ownerUid'] != widget.organizationId ||
        data['verificationStatus'] != 'verified') {
      throw Exception('Verified organization leader access required.');
    }
    await FirebaseFirestore.instance.collection('dropOffPoints').add({
      'organizationId': widget.organizationId,
      'organizationName': data['name'],
      'name': _name.text.trim(),
      'approximateLocation': _location.text.trim(),
      'operatingHours': _hours.text.trim(),
      'acceptedItems': _items.text.trim(),
      'openingDate': Timestamp.fromDate(_opens!),
      'closingDate': Timestamp.fromDate(_closes!),
      'latitude': _point!.latitude,
      'longitude': _point!.longitude,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create drop-off point')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Point name'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _location,
          decoration: const InputDecoration(labelText: 'Approximate location'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _hours,
          decoration: const InputDecoration(labelText: 'Operating hours'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _items,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Accepted items'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(true),
                child: Text(
                  _opens == null ? 'Opening date' : formatPostedDate(_opens!),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(false),
                child: Text(
                  _closes == null ? 'Closing date' : formatPostedDate(_closes!),
                ),
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: _pickPoint,
          icon: const Icon(Icons.add_location_alt),
          label: Text(
            _point == null ? 'Select map location' : 'Location selected',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.add_business),
          label: const Text('Create drop-off point'),
        ),
      ],
    ),
  );
}
