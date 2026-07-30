import 'package:flutter/material.dart';
import '../../models/friend_models.dart';
import '../../services/friends_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/responsive_layout.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _service = FriendsService();
  final _emailController = TextEditingController();
  Future<FriendsOverview>? _future;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() {
        _future = _service.getOverview();
      });

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _sendRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _service.sendRequest(email);
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If that email is registered, a request was sent.')),
        );
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _respond(FriendRequest request, bool accept) async {
    try {
      accept
          ? await _service.acceptRequest(request.id)
          : await _service.rejectRequest(request.id);
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _remove(Friend friend) async {
    try {
      await _service.removeFriend(friend.uid);
      _refresh();
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Friends',
          style: TextStyle(
            fontFamily: 'Lexend Mega',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(screenWidth * 0.045),
            child: MaxWidthContent(
              maxWidth: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _addFriendCard(),
                  const SizedBox(height: 24),
                  FutureBuilder<FriendsOverview>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('Could not load friends: ${snapshot.error}'),
                        );
                      }
                      final overview = snapshot.data!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (overview.incomingRequests.isNotEmpty) ...[
                            _sectionTitle('Requests'),
                            const SizedBox(height: 12),
                            ...overview.incomingRequests.map(_requestTile),
                            const SizedBox(height: 24),
                          ],
                          _sectionTitle('Your Friends'),
                          const SizedBox(height: 12),
                          if (overview.friends.isEmpty)
                            _emptyCard('No friends yet. Add someone by email above.')
                          else
                            ...overview.friends.map(_friendTile),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.14,
          color: Color(0xFF191C1E),
        ),
      );

  Widget _addFriendCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add a friend',
            style: TextStyle(
              fontFamily: 'Lexend Mega',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onSubmitted: (_) => _sendRequest(),
                  decoration: InputDecoration(
                    hintText: 'friend@college.edu',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.black, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending ? null : _sendRequest,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: AppTheme.cardDecoration(
                    color: AppColors.primaryYellow,
                    shadowOffset: const Offset(2, 2),
                  ),
                  child: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1, size: 22, color: Colors.black),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestTile(FriendRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration:
          AppTheme.cardDecoration(color: AppColors.accentPurple, shadowOffset: const Offset(2, 2)),
      child: Row(
        children: [
          _avatar(request.name, request.profilePic),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.name,
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
                Text(request.email,
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _respond(request, true),
            child: const Icon(Icons.check_circle, color: Colors.black, size: 26),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _respond(request, false),
            child: Icon(Icons.cancel, color: Colors.black.withValues(alpha: 0.6), size: 26),
          ),
        ],
      ),
    );
  }

  Widget _friendTile(Friend friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: AppTheme.cardDecoration(color: Colors.white, shadowOffset: const Offset(2, 2)),
      child: Row(
        children: [
          _avatar(friend.name, friend.profilePic),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.name,
                    style: const TextStyle(
                        fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700)),
                Text(friend.email,
                    style: TextStyle(
                        fontFamily: 'Public Sans',
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.6))),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _remove(friend),
            child: Icon(Icons.person_remove_alt_1,
                color: Colors.black.withValues(alpha: 0.6), size: 22),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name, String? profilePic) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.primaryYellow,
      backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
      child: profilePic == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontFamily: 'Lexend Mega', fontWeight: FontWeight.w700, color: Colors.black),
            )
          : null,
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(color: Colors.white),
      child: Text(
        text,
        style: TextStyle(
            fontFamily: 'Public Sans', fontSize: 14, color: Colors.black.withValues(alpha: 0.5)),
      ),
    );
  }
}
