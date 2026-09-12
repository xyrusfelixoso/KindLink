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
  Widget build(BuildContext context) => role == 'Organization'
      ? _OrganizationCampaignsPage(user: user)
      : _DonorCampaignsPage(user: user);
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
    appBar: AppBar(title: const Text('Needed items')),
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
  final _description = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
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
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one needed item.')),
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
        'description': _description.text.trim(),
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
          decoration: const InputDecoration(labelText: 'Campaign title'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Description'),
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(campaign['title'] ?? 'Campaign')),
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
        return ListView(
          padding: const EdgeInsets.all(20),
          children: snapshot.data!.docs.map((doc) {
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
                      value: needed == 0 ? 0 : (received / needed).clamp(0, 1),
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
          }).toList(),
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
      'status': 'Completed',
      'receivedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
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
              if (data['status'] == 'Approved')
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
