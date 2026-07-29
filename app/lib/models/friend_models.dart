class Friend {
  final String uid;
  final String name;
  final String email;
  final String? profilePic;

  Friend({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePic,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
        uid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        profilePic: json['profilePic'] as String?,
      );
}

class FriendRequest {
  final String id;
  final String fromUid;
  final String name;
  final String email;
  final String? profilePic;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.name,
    required this.email,
    this.profilePic,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) => FriendRequest(
        id: json['id'] as String? ?? '',
        fromUid: json['uid'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        profilePic: json['profilePic'] as String?,
      );
}

class FriendsOverview {
  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;

  FriendsOverview({required this.friends, required this.incomingRequests});

  factory FriendsOverview.fromJson(Map<String, dynamic> json) => FriendsOverview(
        friends: (json['friends'] as List<dynamic>? ?? [])
            .map((e) => Friend.fromJson(e as Map<String, dynamic>))
            .toList(),
        incomingRequests: (json['incomingRequests'] as List<dynamic>? ?? [])
            .map((e) => FriendRequest.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
