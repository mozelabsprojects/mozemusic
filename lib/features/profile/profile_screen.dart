import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

import '../../models/playlist.dart';
import '../library/playlist_details_screen.dart';
import '../../core/localization/app_localizations.dart';
import '../player/widgets/device_connect_modal.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? targetUid;
  final Map<String, dynamic>? targetUserData;

  const ProfileScreen({super.key, this.targetUid, this.targetUserData});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (pickedFile == null) return;

    setState(() => _isUploading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final storageRef = FirebaseStorage.instance.ref().child('avatars/${user.uid}.jpg');
      await storageRef.putFile(File(pickedFile.path));

      final downloadUrl = await storageRef.getDownloadURL();
      await user.updatePhotoURL(downloadUrl);

      // Also update in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoUrl': downloadUrl,
      });

      await user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ref.read(locProvider).get('profile_picture_updated')), backgroundColor: Theme.of(context).cardColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${ref.read(locProvider).get('failed_to_upload_image')} $e'), backgroundColor: AppTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = FirebaseAuth.instance.currentUser ?? authState.value;
    
    final isCurrentUser = widget.targetUid == null || widget.targetUid == currentUser?.uid;
    final uid = isCurrentUser ? currentUser?.uid : widget.targetUid;
    final isGuest = uid == null;
    final loc = ref.watch(locProvider);

    final displayName = isCurrentUser ? (currentUser?.displayName ?? 'User') : (widget.targetUserData?['displayName'] ?? 'User');
    final email = isCurrentUser ? (currentUser?.email ?? '') : (widget.targetUserData?['email'] ?? '');
    final photoUrl = isCurrentUser ? currentUser?.photoURL : widget.targetUserData?['photoUrl'];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.get('profile'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        actions: [
          IconButton(
            icon: const Icon(Icons.devices_rounded, color: Color(0xFF1DB954)),
            tooltip: 'Moze Connect & Cihazlar',
            onPressed: () => DeviceConnectModal.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: isGuest
            ? Center(child: Text(loc.get('not_logged_in'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)))
            : RefreshIndicator(
                color: AppTheme.redAccent,
                backgroundColor: Theme.of(context).cardColor,
                onRefresh: () async {
                  if (isCurrentUser && currentUser != null) await currentUser.reload();
                  setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 16, right: 16, top: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: isCurrentUser ? _pickAndUploadImage : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: AppTheme.redAccent,
                              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                              child: _isUploading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : ((photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
                            ),
                            if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Theme.of(context).cardColor, shape: BoxShape.circle),
                              child: Icon(Icons.camera_alt, size: 16, color: Theme.of(context).iconTheme.color),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (isCurrentUser)
                        Text(
                          email,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
                        ),
                      const SizedBox(height: 12),
                      StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();
                          final data = snapshot.data!.data() as Map<String, dynamic>?;
                          final bio = data?['bio'] ?? '';
                          if (bio.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              bio,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14, fontStyle: FontStyle.italic),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFollowerCount(context, uid, 'followers', loc.get('followers'), loc),
                          _buildFollowerCount(context, uid, 'following', loc.get('following'), loc),
                        ],
                      ),
                      const SizedBox(height: 32),

                      if (isCurrentUser)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.edit, size: 18, color: Theme.of(context).textTheme.bodyLarge?.color),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).cardColor,
                                  foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: () => _showEditProfileDialog(context, ref, currentUser!),
                                label: Text(loc.get('edit_profile'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.devices_rounded, size: 18, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1DB954),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: () => DeviceConnectModal.show(context),
                                label: const Text('Masaüstüne Bağlan & Cihazlar', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                          ],
                        )
                      else
                        StreamBuilder<bool>(
                          stream: ref.read(firestoreServiceProvider).isFollowing(uid),
                          builder: (context, snapshot) {
                            final isFollowing = snapshot.data ?? false;
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Icon(isFollowing ? Icons.person_remove : Icons.person_add, size: 18, color: Colors.white),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey.withValues(alpha: 0.3) : AppTheme.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: () async {
                                  if (isFollowing) {
                                    await ref.read(firestoreServiceProvider).unfollowUser(uid);
                                  } else {
                                    await ref.read(firestoreServiceProvider).followUser(uid);
                                  }
                                },
                                label: Text(isFollowing ? loc.get('unfollow') : loc.get('follow'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        ),

                      if (isCurrentUser) ...[
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => DeviceConnectModal.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF1DB954).withValues(alpha: 0.18),
                                  Theme.of(context).cardColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF1DB954).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.devices_rounded,
                                    color: Color(0xFF1DB954),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Moze Connect & Cihazlar',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Masaüstü eşleştirme, uzaktan kontrol ve canlı müzik aktarımı',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF1DB954),
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      
                      // Playlists Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isCurrentUser ? loc.get('your_playlists') : loc.get('public_playlists'),
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<List<Playlist>>(
                        stream: isCurrentUser
                            ? ref.read(firestoreServiceProvider).getUserPlaylists()
                            : ref.read(firestoreServiceProvider).getPublicPlaylists(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: AppTheme.redAccent));
                          }
                          final playlists = snapshot.data ?? [];
                          if (playlists.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Text(loc.get('no_playlists_to_show'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final p = playlists[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => PlaylistDetailsScreen(
                                      playlist: p,
                                      isReadOnly: !isCurrentUser,
                                    ),
                                  ));
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(8),
                                          image: p.coverUrl.isNotEmpty
                                              ? DecorationImage(image: NetworkImage(p.coverUrl), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: p.coverUrl.isEmpty
                                            ? const Center(child: Icon(Icons.music_note, size: 50, color: AppTheme.textSecondary))
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p.title,
                                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${p.songs.length} songs',
                                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFollowerCount(BuildContext context, String uid, String collection, String label, dynamic loc) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(collection)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return GestureDetector(
          onTap: () => _showFollowList(context, uid, collection, label, loc),
          child: Column(
            children: [
              Text('$count', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14)),
            ],
          ),
        );
      },
    );
  }

  void _showFollowList(BuildContext context, String uid, String collection, String title, dynamic loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SizedBox(
        height: 400,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection(collection)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppTheme.redAccent));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(loc.get('no_items_yet'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                    );
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final followUid = docs[index].id;
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('users').doc(followUid).get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) return const SizedBox.shrink();
                          final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                          if (userData == null) return const SizedBox.shrink();
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.redAccent,
                              backgroundImage: (userData['photoUrl'] != null && (userData['photoUrl'] as String).isNotEmpty) ? NetworkImage(userData['photoUrl']) : null,
                              child: (userData['photoUrl'] == null || (userData['photoUrl'] as String).isEmpty) ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                            ),
                            title: Text(userData['displayName'] ?? 'User', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                            subtitle: Text(userData['email'] ?? '', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ProfileScreen(targetUid: followUid, targetUserData: userData),
                              ));
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context, WidgetRef ref, User user) async {
    String currentBio = '';
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      currentBio = doc.data()?['bio'] ?? '';
    } catch (_) {}

    final loc = ref.read(locProvider);
    final nameController = TextEditingController(text: user.displayName);
    final bioController = TextEditingController(text: currentBio);

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(loc.get('edit_profile'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: loc.get('display_name'),
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.redAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: loc.get('bio'),
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.redAccent),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(loc.get('cancel'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newName = nameController.text.trim();
                final newBio = bioController.text.trim();
                if (newName.isNotEmpty) {
                  await user.updateDisplayName(newName);
                  await ref.read(firestoreServiceProvider).updateProfile(newName, newBio);
                  await user.reload();
                  if (mounted) setState(() {});
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(loc.get('profile_updated')), backgroundColor: Theme.of(context).cardColor),
                  );
                }
              },
              child: Text(loc.get('save'), style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
