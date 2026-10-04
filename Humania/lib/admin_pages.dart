part of 'main.dart';

const _requestStatuses = ['Pending', 'Approved', 'Fulfilled', 'Rejected'];

String _requestStatus(Map<String, dynamic> data) {
  final status = data['status']?.toString();
  if (_requestStatuses.contains(status)) return status!;
  if (status?.toLowerCase() == 'fulfilled') return 'Fulfilled';
  return switch (data['verificationStatus']?.toString().toLowerCase()) {
    'verified' => 'Approved',
    'rejected' => 'Rejected',
    _ => 'Pending',
  };
}

class _AdminWebGate extends StatefulWidget {
  const _AdminWebGate();

  @override
  State<_AdminWebGate> createState() => _AdminWebGateState();
}

class _AdminWebGateState extends State<_AdminWebGate> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  firebase_auth.User? _admin;
  bool _checking = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<bool> _isAdmin(firebase_auth.User user) async {
    if (isDesignatedAdminEmail(user.email)) return true;
    final value = await database.ref('users/${user.uid}/isAdmin').get();
    return value.value == true;
  }

  Future<void> _restoreSession() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        if (await _isAdmin(user)) _admin = user;
      } on Exception {
        _error = 'Could not verify administrator access.';
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final credential = await firebase_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!await _isAdmin(credential.user!)) {
        await firebase_auth.FirebaseAuth.instance.signOut();
        throw Exception('This account does not have administrator access.');
      }
      if (mounted) setState(() => _admin = credential.user);
    } on firebase_auth.FirebaseAuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = AuthErrorMapper.message(
            operation: AuthOperation.signIn,
            code: error.code,
          ),
        );
      }
    } on Exception {
      if (mounted) {
        setState(() => _error = 'Unable to sign in. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_admin != null) {
      return _AdminShell(
        admin: _admin!,
        onSignOut: () async {
          await firebase_auth.FirebaseAuth.instance.signOut();
          if (mounted) setState(() => _admin = null);
        },
      );
    }
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KindLinkLogo(height: 130),
                    const SizedBox(height: 18),
                    Text(
                      'Administrator portal',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in with an administrator account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Admin email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _login,
                      icon: const Icon(Icons.login),
                      label: Text(_submitting ? 'Signing in...' : 'Sign in'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminShell extends StatefulWidget {
  const _AdminShell({required this.admin, required this.onSignOut});
  final firebase_auth.User admin;
  final Future<void> Function() onSignOut;

  @override
  State<_AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<_AdminShell> {
  int _index = 0;
  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.fact_check_outlined),
      selectedIcon: Icon(Icons.fact_check),
      label: 'Requests',
    ),
    NavigationDestination(
      icon: Icon(Icons.apartment_outlined),
      selectedIcon: Icon(Icons.apartment),
      label: 'Orgs',
    ),
    NavigationDestination(
      icon: Icon(Icons.volunteer_activism_outlined),
      selectedIcon: Icon(Icons.volunteer_activism),
      label: 'Donations',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Members',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminOverview(onNavigate: (value) => setState(() => _index = value)),
      const _AdminRequestsPage(),
      const _AdminOrganizationsPage(),
      const _AdminDonationsPage(),
      const _AdminPeoplePage(),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final body = Column(
          children: [
            _AdminHeader(
              email: widget.admin.email ?? 'Administrator',
              onSignOut: widget.onSignOut,
            ),
            Expanded(child: pages[_index]),
          ],
        );
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _index,
                        onDestinationSelected: (value) =>
                            setState(() => _index = value),
                        labelType: NavigationRailLabelType.all,
                        destinations: _destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: item.icon,
                                selectedIcon: item.selectedIcon,
                                label: Text(item.label),
                              ),
                            )
                            .toList(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  )
                : body,
          ),
          bottomNavigationBar: wide
              ? null
              : SafeArea(
                  top: false,
                  child: NavigationBar(
                    height: 72,
                    labelBehavior:
                        NavigationDestinationLabelBehavior.onlyShowSelected,
                    selectedIndex: _index,
                    onDestinationSelected: (value) =>
                        setState(() => _index = value),
                    destinations: _destinations,
                  ),
                ),
        );
      },
    );
  }
}

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.email, required this.onSignOut});

  final String email;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      return Container(
        height: 64,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 24),
        color: Colors.white,
        child: Row(
          children: [
            SizedBox(
              width: compact ? 44 : 64,
              height: 48,
              child: ClipRect(
                child: Transform.scale(
                  scale: compact ? 2.2 : 2.7,
                  alignment: const Alignment(0, -0.2),
                  child: Image.asset(
                    'assets/images/kindlink-admin-mark.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'KindLink Admin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(width: 4),
            KindLinkPressScale(
              child: IconButton(
                tooltip: compact ? 'Sign out ($email)' : 'Sign out',
                onPressed: onSignOut,
                icon: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    children: [
      Text(
        'Dashboard',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      const Text('Live overview of the KindLink community support network.'),
      const SizedBox(height: 18),
      const _KindLinkStatusFlow(),
      const SizedBox(height: 24),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _AdminMetric(
            title: 'Pending requests',
            icon: Icons.pending_actions,
            color: Colors.orange,
            stream: FirebaseFirestore.instance
                .collection('helpRequests')
                .snapshots(),
            count: (snapshot) => snapshot.docs
                .where((doc) => _requestStatus(doc.data()) == 'Pending')
                .length,
            onTap: () => onNavigate(1),
          ),
          _AdminRealtimeMetric(
            title: 'Organization applications',
            icon: Icons.apartment,
            color: Colors.blue,
            stream: database.ref('organizations').onValue,
            count: (value) => value is Map
                ? value.values
                      .where(
                        (entry) =>
                            entry is Map &&
                            entry['verificationStatus'] == 'pending',
                      )
                      .length
                : 0,
            onTap: () => onNavigate(2),
          ),
          _AdminMetric(
            title: 'Recorded donations',
            icon: Icons.volunteer_activism,
            color: Colors.green,
            stream: FirebaseFirestore.instance
                .collection('helpOffers')
                .snapshots(),
            count: (snapshot) => snapshot.docs.length,
            onTap: () => onNavigate(3),
          ),
          if (firebasePresenceEnabled)
            _AdminRealtimeMetric(
              title: 'Online members',
              icon: Icons.online_prediction,
              color: Colors.teal,
              stream: database.ref('users').onValue,
              count: (value) => value is Map
                  ? value.values
                        .where(
                          (entry) =>
                              entry is Map &&
                              entry['presence'] is Map &&
                              (entry['presence'] as Map)['online'] == true,
                        )
                        .length
                  : 0,
              onTap: () => onNavigate(4),
            ),
          _AdminRealtimeMetric(
            title: 'Registered members',
            icon: Icons.group_outlined,
            color: Colors.purple,
            stream: database.ref('users').onValue,
            count: (value) => value is Map ? value.length : 0,
            onTap: () => onNavigate(4),
          ),
        ],
      ),
    ],
  );
}

class _KindLinkStatusFlow extends StatelessWidget {
  const _KindLinkStatusFlow();

  static const _steps = [
    ('Requested', Icons.pan_tool_alt_outlined),
    ('Matched', Icons.handshake_outlined),
    ('Preparing', Icons.inventory_2_outlined),
    ('Delivered', Icons.local_shipping_outlined),
    ('Confirmed', Icons.verified_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Request journey',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            if (compact)
              for (var index = 0; index < _steps.length; index++) ...[
                Row(
                  children: [
                    Icon(
                      _steps[index].$2,
                      size: 21,
                      color: index == _steps.length - 1
                          ? kindLinkSuccess
                          : kindLinkEmerald,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _steps[index].$1,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (index < _steps.length - 1)
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
                if (index < _steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1),
                  ),
              ]
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var index = 0; index < _steps.length; index++) ...[
                    Chip(
                      avatar: Icon(
                        _steps[index].$2,
                        size: 18,
                        color: index == _steps.length - 1
                            ? kindLinkSuccess
                            : kindLinkEmerald,
                      ),
                      label: Text(_steps[index].$1),
                    ),
                    if (index < _steps.length - 1)
                      const Icon(Icons.arrow_forward, size: 16),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    required this.count,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final int Function(QuerySnapshot<Map<String, dynamic>>) count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) => _metricCard(
          context,
          title,
          snapshot.hasData ? count(snapshot.data!).toString() : '—',
          icon,
          color,
          onTap,
        ),
      );
}

class _AdminRealtimeMetric extends StatelessWidget {
  const _AdminRealtimeMetric({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
    required this.count,
    required this.onTap,
  });
  final String title;
  final IconData icon;
  final Color color;
  final Stream<DatabaseEvent> stream;
  final int Function(Object? value) count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: stream,
    builder: (context, snapshot) {
      final value = snapshot.data?.snapshot.value;
      final valueText = snapshot.hasData ? count(value).toString() : '—';
      return _metricCard(context, title, valueText, icon, color, onTap);
    },
  );
}

Widget _metricCard(
  BuildContext context,
  String title,
  String value,
  IconData icon,
  Color color,
  VoidCallback onTap,
) => SizedBox(
  width: min(280, MediaQuery.sizeOf(context).width - 32),
  child: Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: .14),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(title),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class _AdminResponsiveTile extends StatelessWidget {
  const _AdminResponsiveTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.actions = const [],
    this.onTap,
  });

  final Widget leading;
  final Widget title;
  final Widget subtitle;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 620;
      if (!compact) {
        return ListTile(
          onTap: onTap,
          leading: leading,
          title: title,
          subtitle: subtitle,
          trailing: actions.isEmpty
              ? null
              : Row(mainAxisSize: MainAxisSize.min, children: actions),
        );
      }
      return InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: title),
                ],
              ),
              const SizedBox(height: 10),
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.bodyMedium,
                child: subtitle,
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _AdminRequestsPage extends StatelessWidget {
  const _AdminRequestsPage();

  Future<void> _setStatus(
    DocumentReference<Map<String, dynamic>> ref,
    String status,
  ) => ref.update({
    'status': status,
    'verificationStatus': switch (status) {
      'Approved' || 'Fulfilled' => 'verified',
      'Rejected' => 'rejected',
      _ => 'pending',
    },
    'reviewedBy': firebase_auth.FirebaseAuth.instance.currentUser?.uid,
    'updatedAt': FieldValue.serverTimestamp(),
    if (status == 'Fulfilled') 'fulfilledAt': FieldValue.serverTimestamp(),
  });

  void _details(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['title'] ?? 'Help request'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Requester: ${data['requesterName'] ?? 'Unknown'}'),
                Text('Beneficiaries: ${data['beneficiaries'] ?? '—'}'),
                Text('Organization: ${data['reviewOrganizationName'] ?? '—'}'),
                Text('Location: ${data['location'] ?? '—'}'),
                const SizedBox(height: 14),
                Text(data['description'] ?? 'No description.'),
                const SizedBox(height: 14),
                const Text(
                  'Items needed',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...(data['items'] as List? ?? []).whereType<Map>().map(
                  (item) => Text(
                    '• ${item['name']}: ${item['quantityReceived'] ?? 0}/${item['quantityNeeded'] ?? 0} ${item['unit'] ?? ''} received',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('helpRequests').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to load requests: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs.toList()
        ..sort(
          (a, b) =>
              _requestStatus(a.data()).compareTo(_requestStatus(b.data())),
        );
      return _AdminList(
        title: 'Help requests',
        subtitle:
            '${docs.where((doc) => _requestStatus(doc.data()) == 'Pending').length} pending',
        empty: 'No help requests found.',
        children: docs.map((doc) {
          final data = doc.data();
          final status = _requestStatus(data);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: _AdminResponsiveTile(
              onTap: () => _details(context, doc),
              leading: const CircleAvatar(
                child: Icon(Icons.front_hand_outlined),
              ),
              title: Text(data['title'] ?? 'Help request'),
              subtitle: Text(
                '${data['requesterName'] ?? 'Unknown requester'} • ${data['neededItems'] ?? 'No items listed'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                Chip(label: Text(status)),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Update status',
                      isDense: true,
                    ),
                    items: _requestStatuses
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) _setStatus(doc.reference, value);
                    },
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

class _AdminOrganizationsPage extends StatelessWidget {
  const _AdminOrganizationsPage();
  Future<void> _setStatus(String id, String status) =>
      database.ref('organizations/$id').update({
        'verificationStatus': status,
        'verifiedBy': firebase_auth.FirebaseAuth.instance.currentUser?.uid,
        'verifiedAt': ServerValue.timestamp,
      });
  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: database.ref('organizations').onValue,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to load organizations: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final raw = snapshot.data!.snapshot.value;
      final organizations = <Map<String, dynamic>>[];
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.value is Map) {
            organizations.add({
              'id': entry.key.toString(),
              ...Map<String, dynamic>.from(entry.value as Map),
            });
          }
        }
      }
      return _AdminList(
        title: 'Organization verification',
        subtitle:
            '${organizations.where((value) => value['verificationStatus'] == 'pending').length} pending',
        empty: 'No organization applications found.',
        children: organizations.map((item) {
          final status = item['verificationStatus']?.toString() ?? 'pending';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: _AdminResponsiveTile(
              leading: Icon(
                status == 'verified' ? Icons.verified : Icons.apartment,
                color: status == 'verified' ? Colors.green : null,
              ),
              title: Text(item['name'] ?? 'Organization'),
              subtitle: Text(item['details'] ?? 'No application details.'),
              actions: [
                Chip(label: Text(status.toUpperCase())),
                OutlinedButton(
                  onPressed: () => _setStatus(item['id'], 'rejected'),
                  child: const Text('Reject'),
                ),
                FilledButton(
                  onPressed: () => _setStatus(item['id'], 'verified'),
                  child: const Text('Approve'),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

class _AdminDonationsPage extends StatelessWidget {
  const _AdminDonationsPage();
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance.collection('helpOffers').snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Text('Unable to load donations: ${snapshot.error}'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final docs = snapshot.data!.docs;
      return _AdminList(
        title: 'Donation monitoring',
        subtitle: '${docs.length} recorded donations',
        empty: 'No donations have been recorded.',
        children: docs.map((doc) {
          final data = doc.data();
          final status = data['status']?.toString() ?? 'Pending';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: _AdminResponsiveTile(
              leading: const CircleAvatar(
                child: Icon(Icons.inventory_2_outlined),
              ),
              title: Text(
                '${data['itemName'] ?? 'Item'} • ${data['quantity'] ?? 0} ${data['unit'] ?? ''}',
              ),
              subtitle: Text(
                'Donor: ${data['donorName'] ?? data['donorId'] ?? 'Unknown'}\nRequest: ${data['requestTitle'] ?? data['helpRequestId'] ?? '—'}',
              ),
              actions: [Chip(label: Text(status))],
            ),
          );
        }).toList(),
      );
    },
  );
}

class _AdminPeoplePage extends StatelessWidget {
  const _AdminPeoplePage();

  String _lastSeen(Object? value) {
    if (value is! num) return 'Last seen unavailable';
    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt()).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'Last seen just now';
    if (difference.inMinutes < 60) {
      return 'Last seen ${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return 'Last seen ${difference.inHours} hr ago';
    }
    return 'Last seen ${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
    stream: database.ref('users').onValue,
    builder: (context, usersSnapshot) {
      if (usersSnapshot.hasError) {
        return Center(
          child: Text('Unable to load members: ${usersSnapshot.error}'),
        );
      }
      if (!usersSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final usersRaw = usersSnapshot.data!.snapshot.value;
      final users = usersRaw is Map ? usersRaw : <Object?, Object?>{};
      final people = <Map<String, dynamic>>[];
      for (final entry in users.entries) {
        if (entry.value is! Map) continue;
        final uid = entry.key.toString();
        final profile = Map<String, dynamic>.from(entry.value as Map);
        final live = profile['presence'] is Map
            ? Map<String, dynamic>.from(profile['presence'] as Map)
            : <String, dynamic>{};
        people.add({'uid': uid, ...profile, ...live});
      }
      people.sort((a, b) {
        final onlineOrder = (b['online'] == true ? 1 : 0).compareTo(
          a['online'] == true ? 1 : 0,
        );
        if (onlineOrder != 0) return onlineOrder;
        return ((b['lastSeen'] as num?) ?? 0).compareTo(
          (a['lastSeen'] as num?) ?? 0,
        );
      });
      final online = people.where((person) => person['online'] == true).length;
      return _AdminList(
        title: 'Members',
        subtitle: '$online online now • ${people.length} registered',
        empty: 'No registered members found.',
        children: people.map((person) {
          final isOnline = person['online'] == true;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: _AdminResponsiveTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  const CircleAvatar(child: Icon(Icons.person_outline)),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(person['name'] ?? 'Member'),
              subtitle: Text(
                '${person['username'] == null ? '' : '@${person['username']} • '}'
                '${isOnline ? 'Using the member app now' : _lastSeen(person['lastSeen'])}',
              ),
              actions: [
                Chip(
                  avatar: Icon(
                    Icons.circle,
                    size: 10,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                  label: Text(isOnline ? 'ONLINE' : 'OFFLINE'),
                ),
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

class _AdminList extends StatelessWidget {
  const _AdminList({
    required this.title,
    required this.subtitle,
    required this.empty,
    required this.children,
  });
  final String title;
  final String subtitle;
  final String empty;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      Text(subtitle),
      const SizedBox(height: 22),
      if (children.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Center(child: Text(empty)),
        )
      else
        ...children,
    ],
  );
}
