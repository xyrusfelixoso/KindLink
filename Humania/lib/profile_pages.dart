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
          color: const Color(0xff1c6349),
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
                '@${user.username} · Verified',
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
                  color: Color(0xff234c3d),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _ReferenceTile(
                icon: Icons.apartment_outlined,
                title: 'Organizations',
                subtitle:
                    user.organizationName ?? 'Create or join an organization',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _OrganizationPage(user: user, onSaved: onUserChanged),
                  ),
                ),
              ),
              _ReferenceTile(
                icon: Icons.handshake_outlined,
                title: 'My Requests',
                subtitle: '${pickupRequests.length} pickup requests',
                onTap: () => _openRequests(context),
              ),
              _ReferenceTile(
                icon: Icons.star_outline,
                title: 'Reviews',
                subtitle: '${reviews.length} reviews from pickups',
                onTap: () => _openReviews(context),
              ),
              _ReferenceTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Account and security',
                onTap: () => _openSettings(context),
              ),
              _ReferenceTile(
                icon: Icons.logout,
                title: 'Log Out',
                onTap: onSignOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openRequests(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PickupRequestsPage(requests: pickupRequests),
      ),
    );
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
  const _PickupRequestsPage({required this.requests});

  final List<DonationItem> requests;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      body: requests.isEmpty
          ? const Center(child: Text('No pickup requests yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: requests.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _DonationCard(item: requests[index]),
            ),
    );
  }
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
                            color: Color(0xff194c3b),
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
            (index) => IconButton(
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
  final List<Map<String, String>> _organizations = [];
  bool _loadingOrganizations = true;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.organizationName);
    _detailsController = TextEditingController(
      text: widget.user.organizationDetails,
    );
    _loadCurrentInviteCode();
    _loadOrganizations();
  }

  Future<void> _loadCurrentInviteCode() async {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await database.ref('organizations/$uid/inviteCode').get();
    if (!mounted) return;
    setState(() => _inviteCode = snapshot.value as String?);
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
          final name = data['name'] as String?;
          if (name == null || name.trim().isEmpty) continue;
          loaded.add({
            'id': entry.key.toString(),
            'name': name,
            'details': data['details'] as String? ?? '',
            'inviteCode': data['inviteCode'] as String? ?? '',
          });
        }
      }
      setState(() {
        _organizations
          ..clear()
          ..addAll(loaded);
        _loadingOrganizations = false;
      });
    } on Exception {
      if (mounted) setState(() => _loadingOrganizations = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _detailsController.dispose();
    _joinController.dispose();
    super.dispose();
  }

  Future<void> _saveOrganization() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final inviteCode = _inviteCode ?? _createInviteCode();
    await database.ref('organizations/$uid').set({
      'name': name,
      'details': _detailsController.text.trim(),
      'ownerUid': uid,
      'inviteCode': inviteCode,
    });
    await database.ref('users/$uid').update({
      'organizationName': name,
      'organizationDetails': _detailsController.text.trim(),
    });
    widget.user
      ..organizationName = name
      ..organizationDetails = _detailsController.text.trim();
    _inviteCode = inviteCode;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Organization workspace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff155d43), Color(0xff2f8b67)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.apartment, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text.trim().isEmpty
                            ? 'Build your community'
                            : _nameController.text,
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
                          Text(
                            'Organization workspace',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your organization',
                    style: TextStyle(
                      color: Color(0xff194c3b),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Organization name',
                      prefixIcon: Icon(Icons.apartment_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Organization details',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _saveOrganization,
                    icon: const Icon(Icons.add_business_outlined),
                    label: const Text('Save organization'),
                  ),
                  if (widget.user.organizationName != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _OrganizationCampaignsPage(user: widget.user),
                        ),
                      ),
                      icon: const Icon(Icons.campaign_outlined),
                      label: const Text('Manage donation campaigns'),
                    ),
                  ],
                  if (_inviteCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xffd9f4df),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.key_outlined,
                            color: Color(0xff19704f),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Invite code: $_inviteCode',
                              style: const TextStyle(
                                color: Color(0xff194c3b),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy invite code',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _inviteCode!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Invite code copied.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy_outlined),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  const Text(
                    'Join with invite code',
                    style: TextStyle(
                      color: Color(0xff194c3b),
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
          const SizedBox(height: 22),
          const Text(
            'Available organizations',
            style: TextStyle(
              color: Color(0xff194c3b),
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingOrganizations)
            const Center(child: CircularProgressIndicator())
          else if (_organizations.isEmpty)
            const Text('No organizations have been created yet.')
          else
            ..._organizations.map(
              (organization) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xffd9f4df),
                    child: Icon(
                      Icons.apartment_outlined,
                      color: Color(0xff19704f),
                    ),
                  ),
                  title: Text(organization['name']!),
                  subtitle: Text(
                    organization['details']!.isEmpty
                        ? 'No details provided'
                        : organization['details']!,
                  ),
                  trailing: FilledButton(
                    onPressed: () => _joinListedOrganization(organization),
                    child: const Text('Join'),
                  ),
                ),
              ),
            ),
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
    _emailController = TextEditingController(text: widget.user.email);
    _passwordController = TextEditingController(text: widget.user.password);
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
      if (_passwordController.text != widget.user.password) {
        await authUser.updatePassword(_passwordController.text);
      }
      await database.ref('users/${authUser.uid}').update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'profileAvatarIndex': _profileAvatarIndex,
      });
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Unable to update account.')),
        );
      }
      return;
    }
    widget.user
      ..name = _nameController.text.trim()
      ..email = _emailController.text.trim()
      ..password = _passwordController.text;
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
                  backgroundColor: const Color(0xffd9f4df),
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
                            ? const Color(0xff19704f)
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
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => value == null || value.length < 6
                  ? 'Use at least 6 characters'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xff19704f),
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

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        leading: Icon(icon, color: const Color(0xffe1b936), size: 28),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right, color: Colors.black26),
      ),
    );
  }
}
