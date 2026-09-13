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

class _CampaignHubPage extends StatelessWidget {
  const _CampaignHubPage({required this.role, required this.user});
  final String role;
  final UserAccount user;

  @override
  Widget build(BuildContext context) => switch (role) {
    'Organization' => _OrganizationCampaignsPage(user: user),
    'Admin' when user.isAdmin => const _AdminOrganizationVerificationPage(),
    _ => _DonorCampaignsPage(user: user),
  };
}

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
        IconButton(
          tooltip: 'Verify help requests',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _HelpRequestModerationPage(),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
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
        title: const Text('Campaign management'),
        actions: [
          IconButton(
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: uid == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _CreateCampaignPage(user: user, organizationId: uid),
                ),
              ),
        icon: const Icon(Icons.add),
        label: const Text('Create campaign'),
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
                    child: Text('Create your first item donation campaign.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (_, index) =>
                      _CampaignCard(document: docs[index], organization: true),
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
      title: const Text('Needed items'),
      actions: [
        IconButton(
          tooltip: 'My pledges',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const _DonorPledgesPage()),
          ),
          icon: const Icon(Icons.handshake_outlined),
        ),
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
        final docs = snapshot.data!.docs;
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
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No pledges submitted yet.'));
                }
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: snapshot.data!.docs.map((doc) {
                    final pledge = doc.data();
                    final status = pledge['status'] as String? ?? 'Pending';
                    final handover = pledge['handoverMethod'] as String?;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pledge['campaignTitle'] as String? ?? 'Campaign',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Status: $status'),
                            if (handover != null) Text('Handover: $handover'),
                            if (status == 'Approved' && handover == null) ...[
                              const SizedBox(height: 12),
                              const Text('Choose how to hand over the items:'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => doc.reference.update({
                                      'handoverMethod': 'Drop-off',
                                      'handoverSelectedAt':
                                          FieldValue.serverTimestamp(),
                                    }),
                                    icon: const Icon(Icons.store_outlined),
                                    label: const Text('Drop-off'),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => doc.reference.update({
                                      'handoverMethod': 'Pickup',
                                      'handoverSelectedAt':
                                          FieldValue.serverTimestamp(),
                                    }),
                                    icon: const Icon(
                                      Icons.local_shipping_outlined,
                                    ),
                                    label: const Text('Pickup'),
                                  ),
                                ],
                              ),
                            ],
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

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.document,
    required this.organization,
    this.user,
  });
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final bool organization;
  final UserAccount? user;
  @override
  Widget build(BuildContext context) {
    final data = document.data();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
        title: Text(
          data['title'] as String? ?? 'Donation campaign',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${data['organizationName'] ?? 'Organization'}\n${data['description'] ?? ''}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
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

  Future<void> _postDistributionReport(BuildContext context) async {
    final summary = TextEditingController();
    final beneficiaries = TextEditingController();
    final distributedItems = TextEditingController();
    final submit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Post distribution report'),
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
    if (submit != true ||
        beneficiaries.text.trim().isEmpty ||
        distributedItems.text.trim().isEmpty ||
        summary.text.trim().isEmpty) {
      return;
    }
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    batch.set(firestore.collection('campaignReports').doc(), {
      'campaignId': campaignId,
      'organizationId': campaign['organizationId'],
      'campaignTitle': campaign['title'],
      'beneficiariesReached': beneficiaries.text.trim(),
      'itemsDistributed': distributedItems.text.trim(),
      'summary': summary.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(firestore.collection('campaigns').doc(campaignId), {
      'lastDistributionReportAt': FieldValue.serverTimestamp(),
      'distributionReportCount': FieldValue.increment(1),
    });
    await batch.commit();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Distribution report posted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(campaign['title'] ?? 'Campaign'),
      actions: [
        if (organization)
          IconButton(
            tooltip: 'Post distribution report',
            onPressed: () => _postDistributionReport(context),
            icon: const Icon(Icons.post_add_outlined),
          ),
      ],
    ),
    floatingActionButton: organization || user == null
        ? null
        : FloatingActionButton.extended(
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
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('Donate multiple'),
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
          (total, doc) => total + (doc.data()['quantityReceived'] as num? ?? 0),
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
              final received = item['quantityReceived'] as num? ?? 0;
              final remaining = item['quantityRemaining'] as num? ?? 0;
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
                        '${item['preferredCondition'] ?? ''}\n${received.toInt()} / ${needed.toInt()} received • ${remaining.toInt()} remaining',
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: needed == 0
                            ? 0
                            : (received / needed).clamp(0, 1),
                      ),
                      if (!organization && remaining > 0)
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => _offer(context, doc.id, item),
                            child: const Text('Donate this item'),
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
        final remaining = (current?['quantityRemaining'] as num?)?.toInt() ?? 0;
        if (offered > remaining) {
          throw Exception('Only $remaining item(s) are still needed.');
        }
        tx.update(campaignItem, {
          'quantityRemaining': remaining - offered,
          'quantityPledged':
              (current?['quantityPledged'] as num? ?? 0).toInt() + offered,
        });
        tx.set(donation, {
          'donorId': uid,
          'donorName': user?.name,
          'organizationId': campaign['organizationId'],
          'campaignId': campaignId,
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
        const SnackBar(content: Text('Donation request submitted.')),
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
                    'Distribution reports',
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
          final remaining = (current['quantityRemaining'] as num? ?? 0).toInt();
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
          final remaining = (data['quantityRemaining'] as num).toInt();
          tx.update(item.reference, {
            'quantityRemaining': remaining - offered,
            'quantityPledged':
                (data['quantityPledged'] as num? ?? 0).toInt() + offered,
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
            .where((doc) => (doc.data()['quantityRemaining'] as num? ?? 0) > 0)
            .toList();
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
            ...items.map((doc) {
              final item = doc.data();
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
                        subtitle: Text(
                          '${item['quantityRemaining']} remaining',
                        ),
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
                          onChanged: (value) =>
                              _quantities[doc.id] = int.tryParse(value) ?? 0,
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
              onPressed: _saving ? null : () => _submit(items),
              icon: const Icon(Icons.send_outlined),
              label: Text(
                _saving ? 'Submitting...' : 'Submit donation request',
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
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No donation requests.'));
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: docs.map((doc) {
            final d = doc.data();
            return Card(
              child: ListTile(
                title: Text(d['donorName'] ?? 'Donor'),
                subtitle: Text(
                  '${d['itemCount'] ?? 1} item(s) • ${d['status']}\n${d['message'] ?? ''}',
                ),
                isThreeLine: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _OrganizationOfferDetailsPage(
                      donation: doc,
                      onStatus: (status) => _changeStatus(context, doc, status),
                    ),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (status) => _changeStatus(context, doc, status),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'Approved', child: Text('Approve')),
                    PopupMenuItem(value: 'Rejected', child: Text('Reject')),
                    PopupMenuItem(
                      value: 'Received',
                      child: Text('Confirm received'),
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

  Future<void> _changeStatus(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> donation,
    String status,
  ) async {
    if (status == 'Rejected') {
      final rejectedItems = await FirebaseFirestore.instance
          .collection('donationItems')
          .where('donationId', isEqualTo: donation.id)
          .get();
      for (final item in rejectedItems.docs) {
        final data = item.data();
        final offered = (data['quantityOffered'] as num).toInt();
        final campaignItem = FirebaseFirestore.instance
            .collection('campaignItems')
            .doc(data['campaignItemId']);
        await FirebaseFirestore.instance.runTransaction((tx) async {
          final snapshot = await tx.get(campaignItem);
          final current = snapshot.data();
          if (current == null) return;
          tx.update(campaignItem, {
            'quantityRemaining':
                (current['quantityRemaining'] as num? ?? 0).toInt() + offered,
            'quantityPledged': max(
              0,
              (current['quantityPledged'] as num? ?? 0).toInt() - offered,
            ),
          });
        });
      }
    }
    if (status != 'Received') {
      await donation.reference.update({
        'status': status,
        '${status.toLowerCase()}At': FieldValue.serverTimestamp(),
      });
      return;
    }
    final items = await FirebaseFirestore.instance
        .collection('donationItems')
        .where('donationId', isEqualTo: donation.id)
        .get();
    for (final donationItem in items.docs) {
      final data = donationItem.data();
      final offered = (data['quantityOffered'] as num).toInt();
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
      if (confirmed == null || confirmed < 0) return;
      final firestore = FirebaseFirestore.instance;
      final campaignItem = firestore
          .collection('campaignItems')
          .doc(data['campaignItemId']);
      await firestore.runTransaction((tx) async {
        final snap = await tx.get(campaignItem);
        final current = snap.data();
        if (current == null) return;
        final received =
            (current['quantityReceived'] as num? ?? 0).toInt() + confirmed;
        tx.update(campaignItem, {
          'quantityReceived': received,
          'quantityRemaining': max(
            0,
            (current['quantityRemaining'] as num? ?? 0).toInt() +
                offered -
                confirmed,
          ),
          'quantityPledged': max(
            0,
            (current['quantityPledged'] as num? ?? 0).toInt() - offered,
          ),
        });
        tx.update(donationItem.reference, {'quantityReceived': confirmed});
      });
    }
    await donation.reference.update({
      'status': 'Received',
      'receivedAt': FieldValue.serverTimestamp(),
    });
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
                  color: Color(0xff19704f),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (data['handoverMethod'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Handover: ${data['handoverMethod']}'),
                ),
              if ((data['message'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Message: ${data['message']}'),
                ),
              const SizedBox(height: 18),
              const Text(
                'Items offered',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...snapshot.data!.docs.map((item) {
                final value = item.data();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.inventory_2_outlined),
                    ),
                    title: Text(value['itemName'] ?? 'Item'),
                    subtitle: Text(
                      'Offered: ${value['quantityOffered']}\nCondition: ${value['condition']}',
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
                      'Waiting for the donor to choose drop-off or pickup.',
                    ),
                  ),
                ),
              if (data['status'] == 'Approved' &&
                  data['handoverMethod'] != null)
                FilledButton.icon(
                  onPressed: () async {
                    await onStatus('Received');
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.inventory),
                  label: const Text('Confirm received items'),
                ),
            ],
          );
        },
      ),
    );
  }
}
